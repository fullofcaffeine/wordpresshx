#!/usr/bin/env python3
"""Compare two exact validated profile catalogs without widening support claims."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROFILE_SCHEMA_PATH = ROOT / "schemas" / "profile.schema.json"
DIFF_SCHEMA_PATH = ROOT / "schemas" / "profile-diff.schema.json"
VALIDATOR_PATH = ROOT / "scripts" / "profiles" / "validate-profile-schema.py"
ABSENT = object()

POLICY = {
    "scope": "exact-validated-catalogs-only",
    "rangeSupport": "not-inferred",
    "sourceRewrite": "not-performed",
    "decision": "advisory-review-required",
}

EVIDENCE_ORDER = {
    "inventoried": 0,
    "typed": 1,
    "generated": 2,
    "runtime-tested": 3,
    "production-supported": 4,
}


class ProfileDiffError(ValueError):
    pass


def canonical_json(value: object) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def decode_strict_json(value: str) -> object:
    def reject_non_finite(constant: str) -> object:
        raise ValueError(f"non-finite JSON value {constant}")

    return json.loads(value, parse_constant=reject_non_finite)


def canonical_digest(value: object) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def load_validator_module() -> object:
    sys.dont_write_bytecode = True
    specification = importlib.util.spec_from_file_location(
        "wordpresshx_profile_diff_validator", VALIDATOR_PATH
    )
    if specification is None or specification.loader is None:
        raise ProfileDiffError("profile validator could not be loaded")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def load_catalog(
    path: Path, validator_module: object, validator: object
) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ProfileDiffError(f"cannot read catalog {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise ProfileDiffError(
            f"catalog {path} is not valid JSON: {error}"
        ) from error
    if not isinstance(value, dict):
        raise ProfileDiffError(f"catalog {path} must be a JSON object")
    try:
        validator_module.validate_document(value, validator)
    except validator_module.ProfileValidationError as error:
        raise ProfileDiffError(f"catalog {path} is invalid: {error}") from error
    return value


def endpoint(document: dict[str, object]) -> dict[str, object]:
    catalog = document["catalog"]
    generator = document["generator"]
    return {
        "profileId": catalog["profileId"],
        "catalogRevision": catalog["catalogRevision"],
        "catalogDigest": document["catalogDigest"],
        "upstreamInputsDigest": canonical_digest(catalog["upstreamInputs"]),
        "generatorIdentity": generator["identity"],
        "generatorVersion": generator["version"],
        "generatorSourceDigest": generator["sourceDigest"],
        "toolchainIdentity": generator["toolchainIdentity"],
    }


def comparison_authority(
    before: dict[str, object], after: dict[str, object]
) -> tuple[str, dict[str, object] | None]:
    if before["catalogDigest"] == after["catalogDigest"]:
        return "identical", None

    old_catalog = before["catalog"]
    new_catalog = after["catalog"]
    same_exact_baseline = (
        old_catalog["profileId"] == new_catalog["profileId"]
        and old_catalog["upstreamInputs"] == new_catalog["upstreamInputs"]
    )
    correction = new_catalog.get("correction")
    if same_exact_baseline:
        if correction is None:
            raise ProfileDiffError(
                "same-profile, same-upstream catalog drift lacks an additive "
                "correction record"
            )
        if correction["correctionOfCatalogDigest"] != before["catalogDigest"]:
            raise ProfileDiffError(
                "same-upstream comparison is not a direct correction of the "
                "from catalog digest"
            )
        return "sdk-catalog-correction", correction

    if (
        correction is not None
        and correction["correctionOfCatalogDigest"] == before["catalogDigest"]
    ):
        raise ProfileDiffError(
            "target claims a direct SDK correction while changing the exact "
            "profile or upstream inputs"
        )
    return "upstream-profile-change", None


def change_value(value: object) -> dict[str, str]:
    if value is ABSENT:
        return {"state": "absent"}
    return {"state": "present", "canonicalJson": canonical_json(value)}


def make_change(
    subject: str,
    facet: str,
    impact: str,
    before: object,
    after: object,
    action: str,
) -> dict[str, object]:
    return {
        "subject": subject,
        "facet": facet,
        "impact": impact,
        "before": change_value(before),
        "after": change_value(after),
        "action": action,
    }


def correction_impact(correction: dict[str, object]) -> str:
    if (
        correction["consumerContractImpact"] == "breaking"
        or correction["schemaInterpretationImpact"] == "breaking"
    ):
        return "breaking"
    if correction["consumerContractImpact"] == "additive":
        return "additive"
    return "informational"


def catalog_changes(
    before: dict[str, object], after: dict[str, object]
) -> list[dict[str, object]]:
    old_catalog = before["catalog"]
    new_catalog = after["catalog"]
    old_generator = before["generator"]
    new_generator = after["generator"]
    changes: list[dict[str, object]] = []

    fields = [
        (
            "profile-id",
            old_catalog["profileId"],
            new_catalog["profileId"],
            "review-required",
            "Build and test a separate artifact for the target exact profile.",
        ),
        (
            "catalog-revision",
            old_catalog["catalogRevision"],
            new_catalog["catalogRevision"],
            "review-required",
            "Review the catalog-schema migration before selecting the new revision.",
        ),
        (
            "upstream-inputs",
            old_catalog["upstreamInputs"],
            new_catalog["upstreamInputs"],
            "review-required",
            "Run the complete target-profile test matrix against the new exact inputs.",
        ),
        (
            "generator-identity",
            old_generator["identity"],
            new_generator["identity"],
            "review-required",
            "Review generator provenance and regenerate into a clean staging tree.",
        ),
        (
            "generator-version",
            old_generator["version"],
            new_generator["version"],
            "informational",
            "Reproduce the target catalog with the recorded generator version.",
        ),
        (
            "generator-source",
            old_generator["sourceDigest"],
            new_generator["sourceDigest"],
            "informational",
            "Reproduce the target catalog with the recorded generator source digest.",
        ),
        (
            "toolchain",
            old_generator["toolchainIdentity"],
            new_generator["toolchainIdentity"],
            "review-required",
            "Run catalog and downstream artifact gates with the target toolchain.",
        ),
    ]
    for facet, old_value, new_value, impact, action in fields:
        if old_value != new_value:
            changes.append(
                make_change(
                    "catalog",
                    facet,
                    impact,
                    old_value,
                    new_value,
                    action,
                )
            )

    old_correction = old_catalog.get("correction", ABSENT)
    new_correction = new_catalog.get("correction", ABSENT)
    if old_correction != new_correction:
        impact = (
            correction_impact(new_correction)
            if new_correction is not ABSENT
            else "review-required"
        )
        action = (
            new_correction["migration"]
            if new_correction is not ABSENT
            else "Confirm why the target catalog removed prior correction metadata."
        )
        changes.append(
            make_change(
                "catalog",
                "correction",
                impact,
                old_correction,
                new_correction,
                action,
            )
        )
    return sorted(changes, key=lambda change: change["facet"])


def classification_impact(before: str, after: str) -> str:
    stable = {"public", "deprecated"}
    if before in stable and after not in stable:
        return "breaking"
    if before not in stable and after == "public":
        return "additive"
    return "review-required"


def availability_impact(before: list[str], after: list[str]) -> str:
    removed = set(before) - set(after)
    added = set(after) - set(before)
    if removed:
        return "breaking"
    if added:
        return "additive"
    return "review-required"


def evidence_impact(before: str, after: str) -> str:
    if EVIDENCE_ORDER[after] < EVIDENCE_ORDER[before]:
        return "breaking"
    return "informational"


def contract_field(
    capability: dict[str, object], field: str
) -> object:
    contract = capability.get("contract")
    if contract is None or field not in contract:
        return ABSENT
    value = contract[field]
    if field == "signature":
        return {
            "shape": value["shape"],
            "authority": value["authority"],
        }
    return value


def changed_capability_facets(
    capability_id: str,
    before: dict[str, object],
    after: dict[str, object],
) -> list[dict[str, object]]:
    changes: list[dict[str, object]] = []
    direct_fields = [
        (
            "providerIdentity",
            "provider-identity",
            "breaking",
            "Review the provider transition and replace assumptions tied to the prior provider.",
        ),
        (
            "kind",
            "kind",
            "breaking",
            "Migrate to the target capability kind and rerun generated API checks.",
        ),
        (
            "classificationMetadata",
            "classification-metadata",
            "review-required",
            "Review waiver, deprecation, and removal metadata before upgrading.",
        ),
        (
            "provenance",
            "provenance",
            "informational",
            "Audit the target exact-source provenance before relying on this capability.",
        ),
        (
            "evidence",
            "evidence",
            "informational",
            "Confirm that required evidence receipts remain valid for the target catalog.",
        ),
        (
            "receiptIds",
            "receipt-ids",
            "informational",
            "Inspect the changed evidence receipts and their exact scope.",
        ),
        (
            "administrativeResults",
            "administrative-results",
            "review-required",
            "Resolve new failures, unsupported results, or withdrawals before upgrading.",
        ),
    ]
    for field, facet, impact, action in direct_fields:
        if before[field] != after[field]:
            changes.append(
                make_change(
                    capability_id,
                    facet,
                    impact,
                    before[field],
                    after[field],
                    action,
                )
            )

    if before["classification"] != after["classification"]:
        changes.append(
            make_change(
                capability_id,
                "classification",
                classification_impact(
                    before["classification"], after["classification"]
                ),
                before["classification"],
                after["classification"],
                "Review import exposure, release notes, and migration policy for the new classification.",
            )
        )
    if before["evidenceStatus"] != after["evidenceStatus"]:
        changes.append(
            make_change(
                capability_id,
                "evidence-status",
                evidence_impact(
                    before["evidenceStatus"], after["evidenceStatus"]
                ),
                before["evidenceStatus"],
                after["evidenceStatus"],
                "Use only the target evidence status; inventory does not imply runtime support.",
            )
        )
    if before["availableIn"] != after["availableIn"]:
        changes.append(
            make_change(
                capability_id,
                "availability",
                availability_impact(before["availableIn"], after["availableIn"]),
                before["availableIn"],
                after["availableIn"],
                "Compile and test this capability only in an exact profile listed by the target catalog.",
            )
        )

    contract_fields = [
        (
            "signature",
            "signature",
            "breaking",
            "Update typed calls or callbacks to the reviewed target signature and rerun native integration tests.",
        ),
        (
            "metadata",
            "metadata",
            "breaking",
            "Review generated metadata and compatibility or serialization impact before upgrading.",
        ),
        (
            "dependencies",
            "dependencies",
            "review-required",
            "Regenerate dependency metadata and verify package or handle resolution.",
        ),
    ]
    for field, facet, impact, action in contract_fields:
        old_value = contract_field(before, field)
        new_value = contract_field(after, field)
        if old_value != new_value:
            changes.append(
                make_change(
                    capability_id,
                    facet,
                    impact,
                    old_value,
                    new_value,
                    action,
                )
            )

    old_native = contract_field(before, "nativeIdentity")
    new_native = contract_field(after, "nativeIdentity")
    if old_native != new_native:
        facet = (
            "handle"
            if "script-handle" in {before["kind"], after["kind"]}
            else "native-identity"
        )
        action = (
            "Regenerate asset dependencies and replace the changed WordPress script handle."
            if facet == "handle"
            else "Replace references to the prior native identity and rerun boundary tests."
        )
        changes.append(
            make_change(
                capability_id,
                facet,
                "breaking",
                old_native,
                new_native,
                action,
            )
        )
    return changes


def capability_changes(
    before: dict[str, object], after: dict[str, object]
) -> list[dict[str, object]]:
    old_capabilities = {
        capability["capabilityId"]: capability
        for capability in before["catalog"]["capabilities"]
    }
    new_capabilities = {
        capability["capabilityId"]: capability
        for capability in after["catalog"]["capabilities"]
    }
    changes: list[dict[str, object]] = []
    for capability_id in sorted(set(old_capabilities) | set(new_capabilities)):
        old_capability = old_capabilities.get(capability_id)
        new_capability = new_capabilities.get(capability_id)
        if old_capability is None:
            changes.append(
                make_change(
                    capability_id,
                    "addition",
                    "additive",
                    ABSENT,
                    new_capability,
                    "Review classification and evidence before adopting this exact-profile capability.",
                )
            )
            continue
        if new_capability is None:
            changes.append(
                make_change(
                    capability_id,
                    "removal",
                    "breaking",
                    old_capability,
                    ABSENT,
                    "Remove or replace uses of this capability and rerun the target-profile test matrix.",
                )
            )
            continue
        changes.extend(
            changed_capability_facets(
                capability_id, old_capability, new_capability
            )
        )
    return sorted(
        changes,
        key=lambda change: (change["subject"], change["facet"]),
    )


def migration_actions(
    catalog: list[dict[str, object]], capabilities: list[dict[str, object]]
) -> list[dict[str, str]]:
    actions: dict[tuple[str, str, str], dict[str, str]] = {}
    for change in catalog + capabilities:
        if change["impact"] not in {"breaking", "review-required"} and (
            change["facet"] != "correction"
        ):
            continue
        action = {
            "subject": change["subject"],
            "facet": change["facet"],
            "action": change["action"],
        }
        key = (action["subject"], action["facet"], action["action"])
        actions[key] = action
    return [actions[key] for key in sorted(actions)]


def build_summary(
    catalog: list[dict[str, object]],
    capabilities: list[dict[str, object]],
    migrations: list[dict[str, str]],
) -> dict[str, int]:
    all_changes = catalog + capabilities

    def capability_count(facet: str) -> int:
        return sum(change["facet"] == facet for change in capabilities)

    categorized = {
        "addition",
        "removal",
        "signature",
        "classification",
        "handle",
        "metadata",
        "dependencies",
    }
    return {
        "catalogChangeCount": len(catalog),
        "capabilityAdditionCount": capability_count("addition"),
        "capabilityRemovalCount": capability_count("removal"),
        "signatureChangeCount": capability_count("signature"),
        "classificationChangeCount": capability_count("classification"),
        "handleChangeCount": capability_count("handle"),
        "metadataChangeCount": capability_count("metadata"),
        "dependencyChangeCount": capability_count("dependencies"),
        "otherCapabilityChangeCount": sum(
            change["facet"] not in categorized for change in capabilities
        ),
        "breakingChangeCount": sum(
            change["impact"] == "breaking" for change in all_changes
        ),
        "reviewRequiredChangeCount": sum(
            change["impact"] == "review-required" for change in all_changes
        ),
        "additiveChangeCount": sum(
            change["impact"] == "additive" for change in all_changes
        ),
        "informationalChangeCount": sum(
            change["impact"] == "informational" for change in all_changes
        ),
        "migrationActionCount": len(migrations),
    }


def report_digest(report: dict[str, object]) -> str:
    material = {
        key: value
        for key, value in report.items()
        if key not in {"reportDigestAlgorithm", "reportDigest"}
    }
    return canonical_digest(material)


def build_report(
    before: dict[str, object], after: dict[str, object]
) -> dict[str, object]:
    authority, correction = comparison_authority(before, after)
    comparison = {
        "authority": authority,
        "from": endpoint(before),
        "to": endpoint(after),
    }
    if correction is not None:
        comparison["correction"] = correction
    catalog = catalog_changes(before, after)
    capabilities = capability_changes(before, after)
    migrations = migration_actions(catalog, capabilities)
    report = {
        "schemaVersion": 1,
        "reportKind": "wordpresshx-exact-profile-diff",
        "reportDigestAlgorithm": "sha256-canonical-json-v1",
        "reportDigest": "",
        "comparison": comparison,
        "policy": POLICY,
        "summary": build_summary(catalog, capabilities, migrations),
        "catalogChanges": catalog,
        "capabilityChanges": capabilities,
        "migrationActions": migrations,
    }
    report["reportDigest"] = report_digest(report)
    return report


def validate_report_semantics(report: dict[str, object]) -> None:
    if report_digest(report) != report["reportDigest"]:
        raise ProfileDiffError("profile diff report digest mismatch")
    if report["catalogChanges"] != sorted(
        report["catalogChanges"], key=lambda change: change["facet"]
    ):
        raise ProfileDiffError("catalog changes are not deterministically sorted")
    if report["capabilityChanges"] != sorted(
        report["capabilityChanges"],
        key=lambda change: (change["subject"], change["facet"]),
    ):
        raise ProfileDiffError("capability changes are not deterministically sorted")
    if report["migrationActions"] != sorted(
        report["migrationActions"],
        key=lambda action: (
            action["subject"],
            action["facet"],
            action["action"],
        ),
    ):
        raise ProfileDiffError("migration actions are not deterministically sorted")
    expected_summary = build_summary(
        report["catalogChanges"],
        report["capabilityChanges"],
        report["migrationActions"],
    )
    if report["summary"] != expected_summary:
        raise ProfileDiffError("profile diff summary does not match its changes")
    authority = report["comparison"]["authority"]
    has_correction = "correction" in report["comparison"]
    if (authority == "sdk-catalog-correction") != has_correction:
        raise ProfileDiffError(
            "correction payload must match sdk-catalog-correction authority"
        )
    for change in report["catalogChanges"] + report["capabilityChanges"]:
        for side in ("before", "after"):
            value = change[side]
            if value["state"] == "absent":
                continue
            try:
                decoded = decode_strict_json(value["canonicalJson"])
            except (json.JSONDecodeError, ValueError) as error:
                raise ProfileDiffError(
                    f"{change['subject']} / {change['facet']} has invalid {side} JSON"
                ) from error
            if canonical_json(decoded) != value["canonicalJson"]:
                raise ProfileDiffError(
                    f"{change['subject']} / {change['facet']} has non-canonical {side} JSON"
                )


def validate_report(
    report: dict[str, object], validator_module: object
) -> None:
    schema = json.loads(DIFF_SCHEMA_PATH.read_text(encoding="utf-8"))
    validator_module.assert_closed_objects(schema)
    validator = validator_module.ClosedSchemaValidator(schema)
    try:
        validator.validate(report)
    except validator_module.ProfileValidationError as error:
        raise ProfileDiffError(f"generated diff report is invalid: {error}") from error
    validate_report_semantics(report)


def display_value(change: dict[str, object], side: str) -> str:
    value = change[side]
    if value["state"] == "absent":
        return "<absent>"
    decoded = decode_strict_json(value["canonicalJson"])
    if change["facet"] in {"addition", "removal"}:
        return "/".join(
            [decoded["kind"], decoded["classification"], decoded["evidenceStatus"]]
        )
    if change["facet"] == "upstream-inputs":
        identities = []
        for item in decoded:
            exact = item.get("commit") or item.get("sha256")
            identities.append(f"{item['inputId']}@{exact}")
        return ", ".join(identities)
    return canonical_json(decoded)


def render_human(report: dict[str, object]) -> str:
    comparison = report["comparison"]
    summary = report["summary"]
    lines = [
        "WordPress Hx exact profile diff",
        f"From: {comparison['from']['catalogRevision']} ({comparison['from']['catalogDigest']})",
        f"To:   {comparison['to']['catalogRevision']} ({comparison['to']['catalogDigest']})",
        f"Authority: {comparison['authority']}",
        "Policy: exact validated catalogs only; this report does not infer range support and rewrites no source.",
        f"Report digest: {report['reportDigest']}",
        "",
        "Summary:",
        (
            "  "
            f"{summary['capabilityAdditionCount']} additions, "
            f"{summary['capabilityRemovalCount']} removals, "
            f"{summary['signatureChangeCount']} signature, "
            f"{summary['classificationChangeCount']} classification, "
            f"{summary['handleChangeCount']} handle, "
            f"{summary['metadataChangeCount']} metadata, and "
            f"{summary['dependencyChangeCount']} dependency changes"
        ),
        (
            "  "
            f"{summary['breakingChangeCount']} breaking, "
            f"{summary['reviewRequiredChangeCount']} review-required, "
            f"{summary['additiveChangeCount']} additive, and "
            f"{summary['informationalChangeCount']} informational changes"
        ),
    ]

    for heading, key in (
        ("Catalog changes", "catalogChanges"),
        ("Capability changes", "capabilityChanges"),
    ):
        lines.extend(["", f"{heading}:"])
        changes = report[key]
        if not changes:
            lines.append("  none")
            continue
        for change in changes:
            lines.extend(
                [
                    f"  [{change['impact'].upper()}] {change['subject']} / {change['facet']}",
                    f"    before: {display_value(change, 'before')}",
                    f"    after:  {display_value(change, 'after')}",
                    f"    action: {change['action']}",
                ]
            )

    lines.extend(["", "Migration actions:"])
    if report["migrationActions"]:
        for action in report["migrationActions"]:
            lines.append(
                f"  - {action['subject']} / {action['facet']}: {action['action']}"
            )
    else:
        lines.append("  none")
    lines.extend(
        [
            "",
            "Decision: advisory review required; no breaking change was accepted automatically.",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Diff two exact validated WordPress Hx profile catalogs."
    )
    parser.add_argument("--from", dest="from_path", type=Path, required=True)
    parser.add_argument("--to", dest="to_path", type=Path, required=True)
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit the deterministic schema-validated JSON report",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validator_module = load_validator_module()
        profile_schema = json.loads(PROFILE_SCHEMA_PATH.read_text(encoding="utf-8"))
        profile_validator = validator_module.ClosedSchemaValidator(profile_schema)
        before = load_catalog(args.from_path, validator_module, profile_validator)
        after = load_catalog(args.to_path, validator_module, profile_validator)
        report = build_report(before, after)
        validate_report(report, validator_module)
    except (OSError, json.JSONDecodeError, ProfileDiffError) as error:
        print(f"profile diff failed: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=False))
    else:
        print(render_human(report), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
