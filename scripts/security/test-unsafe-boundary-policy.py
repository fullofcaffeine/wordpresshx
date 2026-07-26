#!/usr/bin/env python3
"""Validate the ADR-019 unsafe-boundary policy and fail-closed scenarios."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "manifests" / "unsafe-boundary-policy.json"
SCHEMA_PATH = ROOT / "schemas" / "unsafe-boundary-waiver.schema.json"
SCENARIOS_PATH = ROOT / "fixtures" / "unsafe-boundary" / "scenarios.json"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
UTC_INSTANT = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
)


class ValidationError(ValueError):
    pass


def strict_json(path: Path) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ValidationError(f"{path}: duplicate key {key}")
            result[key] = value
        return result

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=pairs,
            parse_constant=lambda value: (_ for _ in ()).throw(
                ValidationError(f"{path}: invalid constant {value}")
            ),
        )
    except json.JSONDecodeError as error:
        raise ValidationError(f"{path}: malformed JSON: {error}") from error


def object_value(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{label} must be an object")
    return value


def array_value(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{label} must be an array")
    return value


def string_value(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ValidationError(f"{label} must be a non-empty string")
    return value


def bool_value(value: object, label: str) -> bool:
    if not isinstance(value, bool):
        raise ValidationError(f"{label} must be boolean")
    return value


def integer_value(value: object, label: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValidationError(f"{label} must be an integer")
    return value


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    actual = set(value)
    if actual != expected:
        raise ValidationError(
            f"{label} keys changed: missing={sorted(expected - actual)}, "
            f"extra={sorted(actual - expected)}"
        )


def unique_strings(value: object, label: str) -> list[str]:
    raw = array_value(value, label)
    strings = [string_value(entry, f"{label} entry") for entry in raw]
    if len(strings) != len(set(strings)):
        raise ValidationError(f"{label} contains duplicates")
    return strings


def parse_utc(value: object, label: str) -> datetime:
    text = string_value(value, label)
    if UTC_INSTANT.fullmatch(text) is None:
        raise ValidationError(f"{label} must be an exact UTC instant")
    parsed = datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ")
    return parsed.replace(tzinfo=timezone.utc)


def digest(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_schema(schema: dict[str, object], category_ids: list[str]) -> None:
    exact_keys(
        schema,
        {
            "$schema",
            "$id",
            "title",
            "type",
            "additionalProperties",
            "required",
            "properties",
            "$defs",
        },
        "waiver schema",
    )
    if schema["type"] != "object" or schema["additionalProperties"] is not False:
        raise ValidationError("waiver schema root must be closed")
    required = unique_strings(schema["required"], "waiver schema required")
    properties = object_value(schema["properties"], "waiver schema properties")
    if set(required) != set(properties):
        raise ValidationError("waiver schema required/properties differ")
    expected = {
        "schemaVersion",
        "id",
        "boundaryId",
        "category",
        "reason",
        "owner",
        "review",
        "createdAt",
        "expiresAt",
        "risk",
        "source",
        "scope",
        "evidence",
        "removal",
    }
    if set(required) != expected:
        raise ValidationError("waiver schema required fields changed")
    definitions = object_value(schema["$defs"], "waiver schema definitions")
    category = object_value(definitions.get("category"), "category definition")
    if unique_strings(category.get("enum"), "category enum") != category_ids:
        raise ValidationError("waiver schema category enum differs from policy")
    sha = object_value(definitions.get("sha256"), "sha256 definition")
    if sha.get("pattern") != "^[0-9a-f]{64}$":
        raise ValidationError("waiver schema SHA-256 pattern changed")
    repository_path = object_value(
        definitions.get("repositoryPath"), "repository path definition"
    )
    pattern = string_value(repository_path.get("pattern"), "repository path pattern")
    if "(?!/)" not in pattern or "\\.\\." not in pattern or "\\\\" not in pattern:
        raise ValidationError("repository path confinement weakened")
    for closed_object in ("review", "risk", "source", "scope", "removal"):
        field = object_value(properties.get(closed_object), closed_object)
        if field.get("additionalProperties") is not False:
            raise ValidationError(f"{closed_object} schema must be closed")


def validate_policy(policy: dict[str, object]) -> dict[str, dict[str, object]]:
    exact_keys(
        policy,
        {
            "schemaVersion",
            "decisionId",
            "status",
            "policyId",
            "authority",
            "categories",
            "prohibitedScopes",
            "waiverContract",
            "lifecycle",
            "inventoryContract",
            "reviewTriggers",
            "gatePolicy",
            "diagnostics",
            "claims",
        },
        "unsafe-boundary policy",
    )
    if policy["schemaVersion"] != 1 or policy["decisionId"] != "ADR-019":
        raise ValidationError("unsafe-boundary policy identity changed")
    if policy["status"] not in {
        "proposed-pending-independent-review",
        "accepted-after-independent-review",
    }:
        raise ValidationError("unsafe-boundary policy status is invalid")
    if policy["policyId"] != "wordpress-hx-unsafe-boundary-v1":
        raise ValidationError("unsafe-boundary policy ID changed")

    authority = object_value(policy["authority"], "authority")
    exact_keys(
        authority,
        {
            "defaultDisposition",
            "inventoryModel",
            "waiverEffect",
            "waiverMayOverridePublicApiProhibition",
            "waiverMayOverrideApplicationOrExampleHaxeStrictness",
            "waiverMayOverrideCriticalOrHighVulnerabilityStop",
            "waiverMayAuthorizeUnknownBoundary",
            "omittedDetectionAllowed",
            "clockAuthority",
            "sourceAndArtifactInventoriesSeparate",
            "generatedAndFinalArtifactScanRequired",
        },
        "authority",
    )
    expected_authority = {
        "defaultDisposition": "blocked",
        "inventoryModel": (
            "detector-declarations-reconciled-to-one-closed-inventory"
        ),
        "waiverEffect": (
            "temporary-visible-exception-not-safety-support-or-type-authority"
        ),
        "waiverMayOverridePublicApiProhibition": False,
        "waiverMayOverrideApplicationOrExampleHaxeStrictness": False,
        "waiverMayOverrideCriticalOrHighVulnerabilityStop": False,
        "waiverMayAuthorizeUnknownBoundary": False,
        "omittedDetectionAllowed": False,
        "clockAuthority": "explicit-utc-instant-recorded-by-gate",
        "sourceAndArtifactInventoriesSeparate": True,
        "generatedAndFinalArtifactScanRequired": True,
    }
    if authority != expected_authority:
        raise ValidationError("unsafe-boundary authority changed")

    categories = array_value(policy["categories"], "categories")
    category_ids: list[str] = []
    by_category: dict[str, dict[str, object]] = {}
    category_keys = {
        "id",
        "detectors",
        "allowedScopes",
        "waiverRequired",
        "decoderEvidenceRequired",
        "stableWithCurrentWaiverAllowed",
        "independentSecurityReviewRequired",
    }
    for index, raw_category in enumerate(categories):
        category = object_value(raw_category, f"category[{index}]")
        exact_keys(category, category_keys, f"category[{index}]")
        category_id = string_value(category["id"], f"category[{index}] id")
        detectors = unique_strings(
            category["detectors"], f"category {category_id} detectors"
        )
        scopes = unique_strings(
            category["allowedScopes"], f"category {category_id} scopes"
        )
        if detectors != sorted(detectors) or scopes != sorted(scopes):
            raise ValidationError(f"category {category_id} lists must be sorted")
        for field in (
            "waiverRequired",
            "decoderEvidenceRequired",
            "stableWithCurrentWaiverAllowed",
            "independentSecurityReviewRequired",
        ):
            bool_value(category[field], f"category {category_id} {field}")
        category_ids.append(category_id)
        by_category[category_id] = category
    expected_categories = [
        "generated-raw-target",
        "haxe-weak-type",
        "javascript-raw-segment",
        "php-raw-segment",
        "private-upstream-api",
        "profile-unsafe-entry",
        "typescript-any",
        "typescript-unknown",
        "unchecked-external-contract",
    ]
    if category_ids != expected_categories or len(by_category) != len(category_ids):
        raise ValidationError("category inventory changed or is not sorted/unique")
    if by_category["typescript-unknown"]["waiverRequired"] is not False:
        raise ValidationError("decoded TypeScript unknown boundary requires a waiver")
    if by_category["typescript-unknown"]["decoderEvidenceRequired"] is not True:
        raise ValidationError("TypeScript unknown lost decoder evidence")
    for category_id in (
        "private-upstream-api",
        "profile-unsafe-entry",
        "unchecked-external-contract",
    ):
        if by_category[category_id]["stableWithCurrentWaiverAllowed"] is not False:
            raise ValidationError(f"{category_id} became stable-release eligible")

    prohibited = unique_strings(policy["prohibitedScopes"], "prohibited scopes")
    if prohibited != [
        "application-source",
        "example-recommended-authoring",
        "public-api",
        "public-type-signature",
        "routine-hxx-expression",
    ]:
        raise ValidationError("prohibited scopes changed")

    waiver = object_value(policy["waiverContract"], "waiver contract")
    exact_keys(
        waiver,
        {
            "schema",
            "idPattern",
            "boundaryIdPattern",
            "sourceBinding",
            "requiredEvidenceCountMinimum",
            "ownerKind",
            "reviewerMustDifferFromOwner",
            "independentOracleReviewerAllowed",
            "selfApprovalAllowed",
            "maximumInitialLifetimeDays",
            "renewal",
            "vagueOrReleaseRelativeExpiryAllowed",
            "removalBeadRequired",
            "removalDeadlineMayExceedExpiry",
        },
        "waiver contract",
    )
    if waiver != {
        "schema": "schemas/unsafe-boundary-waiver.schema.json",
        "idPattern": "^WPHX-UNSAFE-[0-9]{4}$",
        "boundaryIdPattern": "^UB-[A-Z0-9][A-Z0-9-]*$",
        "sourceBinding": (
            "repository-relative-path-full-file-sha256-and-line-range"
        ),
        "requiredEvidenceCountMinimum": 1,
        "ownerKind": "named-accountable-human-or-maintainer-role",
        "reviewerMustDifferFromOwner": True,
        "independentOracleReviewerAllowed": True,
        "selfApprovalAllowed": False,
        "maximumInitialLifetimeDays": 90,
        "renewal": "new-waiver-id-review-and-source-binding-required",
        "vagueOrReleaseRelativeExpiryAllowed": False,
        "removalBeadRequired": True,
        "removalDeadlineMayExceedExpiry": False,
    }:
        raise ValidationError("waiver contract changed")

    lifecycle = object_value(policy["lifecycle"], "lifecycle")
    exact_keys(
        lifecycle,
        {
            "states",
            "activeConditions",
            "expiredWaiverEffect",
            "revokedWaiverEffect",
            "sourceDriftEffect",
            "scopeDriftEffect",
            "renewalCarriesPriorApproval",
            "historyMutable",
        },
        "lifecycle",
    )
    if unique_strings(lifecycle["states"], "lifecycle states") != [
        "active",
        "expired",
        "revoked",
        "superseded",
    ]:
        raise ValidationError("waiver lifecycle states changed")
    active_conditions = set(
        unique_strings(lifecycle["activeConditions"], "active conditions")
    )
    if active_conditions != {
        "approved-review",
        "evaluation-before-expiry",
        "source-binding-matches",
        "scope-matches",
        "category-matches",
        "removal-bead-open-or-in-progress",
        "risk-below-high",
        "all-required-evidence-matches",
    }:
        raise ValidationError("active waiver conditions changed")
    for effect in (
        "expiredWaiverEffect",
        "revokedWaiverEffect",
        "sourceDriftEffect",
        "scopeDriftEffect",
    ):
        if lifecycle[effect] != "all-builds-fail":
            raise ValidationError(f"{effect} must fail all builds")
    if (
        lifecycle["renewalCarriesPriorApproval"] is not False
        or lifecycle["historyMutable"] is not False
    ):
        raise ValidationError("waiver renewal/history became mutable")

    inventory = object_value(policy["inventoryContract"], "inventory contract")
    exact_keys(
        inventory,
        {
            "schemaVersion",
            "closedFields",
            "requiredGrouping",
            "requiredRecordFields",
            "detectedWithoutRecord",
            "recordWithoutDetection",
            "duplicateBoundaryId",
            "duplicateSourceLocation",
            "unknownCategoryOrDetector",
            "typedUnknownDisposition",
            "falsePositiveDisposition",
            "sourceInventoryRequired",
            "generatedInventoryRequired",
            "finalArtifactInventoryRequired",
            "sourceToGeneratedBoundaryIdsRequired",
            "finalArtifactManifestCarriesWaiverIdsAndDigests",
        },
        "inventory contract",
    )
    if inventory["schemaVersion"] != 1 or inventory["closedFields"] is not True:
        raise ValidationError("inventory must remain closed")
    blocking_inventory = {
        "detectedWithoutRecord": "blocked",
        "recordWithoutDetection": "blocked-stale-record",
        "duplicateBoundaryId": "blocked",
        "duplicateSourceLocation": "blocked",
        "unknownCategoryOrDetector": "blocked",
    }
    for field, expected in blocking_inventory.items():
        if inventory[field] != expected:
            raise ValidationError(f"inventory {field} fail-closed rule changed")
    for field in (
        "sourceInventoryRequired",
        "generatedInventoryRequired",
        "finalArtifactInventoryRequired",
        "sourceToGeneratedBoundaryIdsRequired",
        "finalArtifactManifestCarriesWaiverIdsAndDigests",
    ):
        if inventory[field] is not True:
            raise ValidationError(f"inventory {field} must remain required")

    triggers = unique_strings(policy["reviewTriggers"], "review triggers")
    if len(triggers) != 10:
        raise ValidationError("review trigger inventory changed")
    required_trigger_fragments = (
        "boundary-added",
        "compiler-adds",
        "generated-inventory",
        "profile-or-provider",
        "public-api",
        "security-sensitive",
        "digest-drift",
        "fourteen-days",
        "renewal",
    )
    if not all(any(fragment in trigger for trigger in triggers) for fragment in required_trigger_fragments):
        raise ValidationError("required review trigger disappeared")

    gates = object_value(policy["gatePolicy"], "gate policy")
    exact_keys(gates, {"development", "package", "stableRelease"}, "gate policy")
    expected_gate_sizes = {"development": 4, "package": 4, "stableRelease": 7}
    for gate, expected_size in expected_gate_sizes.items():
        rules = unique_strings(gates[gate], f"{gate} gate")
        if len(rules) != expected_size:
            raise ValidationError(f"{gate} gate rule inventory changed")

    diagnostics = object_value(policy["diagnostics"], "diagnostics")
    exact_keys(
        diagnostics,
        {
            "missingInventory",
            "staleInventory",
            "missingWaiver",
            "expiredWaiver",
            "sourceDrift",
            "scopeMismatch",
            "prohibitedScope",
            "selfApproval",
            "invalidExpiry",
            "missingArtifactMapping",
            "riskReleaseStop",
            "reviewRequired",
        },
        "diagnostics",
    )
    diagnostic_values = [
        string_value(value, f"diagnostic {key}")
        for key, value in diagnostics.items()
    ]
    if (
        len(set(diagnostic_values)) != len(diagnostic_values)
        or diagnostic_values != [f"WPX19{index:02d}" for index in range(1, 13)]
    ):
        raise ValidationError("diagnostic codes changed or collide")

    claims = object_value(policy["claims"], "claims")
    if claims != {
        "architectureDecision": "proposed-pending-independent-review",
        "prototypePolicyValidator": "implemented",
        "productionSourceScanner": "not-tested",
        "productionGeneratedScanner": "not-tested",
        "productionArtifactInventory": "not-tested",
        "productionWaiverApi": "withheld",
        "stableReleaseAuthorized": False,
        "productionSupport": "not-tested",
    }:
        raise ValidationError("unsafe-boundary claims changed")
    return by_category


def scenario_decision(
    scenario: dict[str, object],
    categories: dict[str, dict[str, object]],
    prohibited_scopes: set[str],
    evaluation_at: datetime,
    maximum_lifetime_days: int,
) -> tuple[str, str | None]:
    category_id = string_value(scenario["category"], "scenario category")
    category = categories.get(category_id)
    if category is None:
        return ("blocked", "WPX1901")
    detected = bool_value(scenario["detected"], "scenario detected")
    inventoried = bool_value(scenario["inventoried"], "scenario inventoried")
    if detected and not inventoried:
        return ("blocked", "WPX1901")
    if inventoried and not detected:
        return ("blocked", "WPX1902")
    if not detected:
        return ("no-boundary", None)

    scope = string_value(scenario["scope"], "scenario scope")
    if scope in prohibited_scopes:
        return ("blocked", "WPX1907")
    allowed_scopes = set(
        unique_strings(category["allowedScopes"], f"{category_id} allowed scopes")
    )
    if scope not in allowed_scopes:
        return ("blocked", "WPX1906")
    if bool_value(scenario["scopeMatches"], "scenario scopeMatches") is not True:
        return ("blocked", "WPX1906")

    waiver_required = bool_value(
        scenario["waiverRequired"], "scenario waiverRequired"
    )
    if waiver_required is not category["waiverRequired"]:
        raise ValidationError("scenario waiver requirement differs from policy")
    waiver_present = bool_value(scenario["waiverPresent"], "scenario waiverPresent")
    if waiver_required and not waiver_present:
        return ("blocked", "WPX1903")
    if waiver_present:
        owner = string_value(scenario["owner"], "scenario owner")
        reviewer = string_value(scenario["reviewer"], "scenario reviewer")
        if owner == reviewer:
            return ("blocked", "WPX1908")
        created = parse_utc(scenario["createdAt"], "scenario createdAt")
        expires = parse_utc(scenario["expiresAt"], "scenario expiresAt")
        removal = parse_utc(
            scenario["removalDeadline"], "scenario removalDeadline"
        )
        if (
            expires <= created
            or expires - created > timedelta(days=maximum_lifetime_days)
            or removal > expires
        ):
            return ("blocked", "WPX1909")
        status = string_value(scenario["waiverStatus"], "scenario waiverStatus")
        if status != "active" or evaluation_at >= expires:
            return ("blocked", "WPX1904")
        if not bool_value(scenario["sourceMatches"], "scenario sourceMatches"):
            return ("blocked", "WPX1905")

    if (
        category["decoderEvidenceRequired"] is True
        and not bool_value(scenario["decoderEvidence"], "scenario decoderEvidence")
    ):
        return ("blocked", "WPX1912")
    if string_value(scenario["risk"], "scenario risk") in {"high", "critical"}:
        return ("blocked", "WPX1911")

    stable = bool_value(scenario["stableRelease"], "scenario stableRelease")
    if stable and not bool_value(
        scenario["generatedMapping"], "scenario generatedMapping"
    ):
        return ("blocked", "WPX1910")
    if stable and category["stableWithCurrentWaiverAllowed"] is not True:
        return ("blocked", "WPX1911")
    if (
        stable
        and category["independentSecurityReviewRequired"] is True
        and not bool_value(
            scenario["independentReview"], "scenario independentReview"
        )
    ):
        return ("blocked", "WPX1912")
    if waiver_required:
        return (
            "permit-stable-bounded-waiver"
            if stable
            else "permit-development-bounded-waiver",
            None,
        )
    return (
        "permit-stable-inventoried-decoded-boundary"
        if stable
        else "permit-development-inventoried-decoded-boundary",
        None,
    )


def validate_scenarios(
    document: dict[str, object],
    policy: dict[str, object],
    categories: dict[str, dict[str, object]],
) -> list[dict[str, object]]:
    exact_keys(
        document,
        {
            "schemaVersion",
            "scenarioSet",
            "simulationOnly",
            "evaluationAt",
            "scenarios",
        },
        "scenario document",
    )
    if document["schemaVersion"] != 1:
        raise ValidationError("scenario schema version changed")
    if document["scenarioSet"] != "adr019-unsafe-boundary-governance-v1":
        raise ValidationError("scenario set identity changed")
    if document["simulationOnly"] is not True:
        raise ValidationError("scenario document must remain simulation-only")
    evaluation_at = parse_utc(document["evaluationAt"], "scenario evaluationAt")
    scenarios = array_value(document["scenarios"], "scenarios")
    expected_keys = {
        "id",
        "category",
        "scope",
        "detected",
        "inventoried",
        "waiverRequired",
        "waiverPresent",
        "waiverStatus",
        "owner",
        "reviewer",
        "createdAt",
        "expiresAt",
        "removalDeadline",
        "sourceMatches",
        "scopeMatches",
        "decoderEvidence",
        "generatedMapping",
        "risk",
        "stableRelease",
        "independentReview",
        "expectedDecision",
        "diagnostic",
    }
    ids: list[str] = []
    results: list[dict[str, object]] = []
    prohibited = set(unique_strings(policy["prohibitedScopes"], "prohibited scopes"))
    waiver = object_value(policy["waiverContract"], "waiver contract")
    maximum_lifetime = integer_value(
        waiver["maximumInitialLifetimeDays"], "maximum waiver lifetime"
    )
    for index, raw_scenario in enumerate(scenarios):
        scenario = object_value(raw_scenario, f"scenario[{index}]")
        exact_keys(scenario, expected_keys, f"scenario[{index}]")
        scenario_id = string_value(scenario["id"], f"scenario[{index}] id")
        ids.append(scenario_id)
        decision, diagnostic = scenario_decision(
            scenario,
            categories,
            prohibited,
            evaluation_at,
            maximum_lifetime,
        )
        if decision != scenario["expectedDecision"] or diagnostic != scenario["diagnostic"]:
            raise ValidationError(
                f"scenario {scenario_id} expected "
                f"{scenario['expectedDecision']}/{scenario['diagnostic']}, "
                f"got {decision}/{diagnostic}"
            )
        results.append(
            {
                "id": scenario_id,
                "decision": decision,
                "diagnostic": diagnostic,
            }
        )
    if ids != sorted(ids) or len(ids) != len(set(ids)):
        raise ValidationError("scenario IDs must be sorted and unique")
    if len(ids) != 14:
        raise ValidationError("scenario inventory changed")
    return results


def expect_policy_failure(
    base: dict[str, object], label: str, mutate: object
) -> None:
    candidate = copy.deepcopy(base)
    if not callable(mutate):
        raise RuntimeError(f"{label}: mutation is not callable")
    mutate(candidate)
    try:
        validate_policy(candidate)
    except (ValidationError, KeyError):
        return
    raise AssertionError(f"policy mutation passed unexpectedly: {label}")


def run_policy_mutations(policy: dict[str, object]) -> int:
    def category(candidate: dict[str, object], category_id: str) -> dict[str, object]:
        for raw in array_value(candidate["categories"], "mutation categories"):
            value = object_value(raw, "mutation category")
            if value.get("id") == category_id:
                return value
        raise RuntimeError(f"missing mutation category {category_id}")

    mutations = [
        ("status", lambda value: value.__setitem__("status", "accepted")),
        (
            "default disposition",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "defaultDisposition", "warn"
            ),
        ),
        (
            "omitted detection",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "omittedDetectionAllowed", True
            ),
        ),
        (
            "public API override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverridePublicApiProhibition", True
            ),
        ),
        (
            "application strictness override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverrideApplicationOrExampleHaxeStrictness", True
            ),
        ),
        (
            "high vulnerability override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverrideCriticalOrHighVulnerabilityStop", True
            ),
        ),
        (
            "unknown boundary override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayAuthorizeUnknownBoundary", True
            ),
        ),
        (
            "remove category",
            lambda value: array_value(value["categories"], "categories").pop(),
        ),
        (
            "unknown loses decoder",
            lambda value: category(value, "typescript-unknown").__setitem__(
                "decoderEvidenceRequired", False
            ),
        ),
        (
            "private API stable",
            lambda value: category(value, "private-upstream-api").__setitem__(
                "stableWithCurrentWaiverAllowed", True
            ),
        ),
        (
            "public scope removed",
            lambda value: array_value(
                value["prohibitedScopes"], "prohibited scopes"
            ).remove("public-api"),
        ),
        (
            "self approval",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("selfApprovalAllowed", True),
        ),
        (
            "long waiver",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("maximumInitialLifetimeDays", 365),
        ),
        (
            "relative expiry",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("vagueOrReleaseRelativeExpiryAllowed", True),
        ),
        (
            "removal after expiry",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("removalDeadlineMayExceedExpiry", True),
        ),
        (
            "renewal inherits",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "renewalCarriesPriorApproval", True
            ),
        ),
        (
            "mutable history",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "historyMutable", True
            ),
        ),
        (
            "source drift warns",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "sourceDriftEffect", "warning"
            ),
        ),
        (
            "unrecorded boundary warns",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("detectedWithoutRecord", "warning"),
        ),
        (
            "stale record allowed",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("recordWithoutDetection", "allowed"),
        ),
        (
            "generated inventory optional",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("generatedInventoryRequired", False),
        ),
        (
            "artifact mapping optional",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("sourceToGeneratedBoundaryIdsRequired", False),
        ),
        (
            "review trigger removed",
            lambda value: array_value(
                value["reviewTriggers"], "review triggers"
            ).pop(),
        ),
        (
            "stable gate shortened",
            lambda value: array_value(
                object_value(value["gatePolicy"], "gate policy")["stableRelease"],
                "stable gate",
            ).pop(),
        ),
        (
            "diagnostic collision",
            lambda value: object_value(
                value["diagnostics"], "diagnostics"
            ).__setitem__("staleInventory", "WPX1901"),
        ),
        (
            "stable release authorized",
            lambda value: object_value(value["claims"], "claims").__setitem__(
                "stableReleaseAuthorized", True
            ),
        ),
        (
            "production support claimed",
            lambda value: object_value(value["claims"], "claims").__setitem__(
                "productionSupport", "supported"
            ),
        ),
    ]
    for label, mutate in mutations:
        expect_policy_failure(policy, label, mutate)
    return len(mutations)


def run_schema_mutations(
    schema: dict[str, object], category_ids: list[str]
) -> int:
    def expect_failure(label: str, mutate: object) -> None:
        candidate = copy.deepcopy(schema)
        if not callable(mutate):
            raise RuntimeError(f"{label}: mutation is not callable")
        mutate(candidate)
        try:
            validate_schema(candidate, category_ids)
        except (ValidationError, KeyError):
            return
        raise AssertionError(f"schema mutation passed unexpectedly: {label}")

    def definitions(candidate: dict[str, object]) -> dict[str, object]:
        return object_value(candidate["$defs"], "schema definitions")

    def properties(candidate: dict[str, object]) -> dict[str, object]:
        return object_value(candidate["properties"], "schema properties")

    mutations = [
        (
            "open root",
            lambda value: value.__setitem__("additionalProperties", True),
        ),
        (
            "missing required owner",
            lambda value: array_value(value["required"], "required").remove("owner"),
        ),
        (
            "extra optional field",
            lambda value: properties(value).__setitem__(
                "comment", {"type": "string"}
            ),
        ),
        (
            "category removed",
            lambda value: array_value(
                object_value(
                    definitions(value)["category"], "category definition"
                )["enum"],
                "category enum",
            ).pop(),
        ),
        (
            "weak hash",
            lambda value: object_value(
                definitions(value)["sha256"], "sha definition"
            ).__setitem__("pattern", ".*"),
        ),
        (
            "absolute paths allowed",
            lambda value: object_value(
                definitions(value)["repositoryPath"], "path definition"
            ).__setitem__("pattern", ".+"),
        ),
        (
            "open review",
            lambda value: object_value(
                properties(value)["review"], "review property"
            ).__setitem__("additionalProperties", True),
        ),
        (
            "open source",
            lambda value: object_value(
                properties(value)["source"], "source property"
            ).__setitem__("additionalProperties", True),
        ),
    ]
    for label, mutate in mutations:
        expect_failure(label, mutate)
    return len(mutations)


def main() -> None:
    policy = object_value(strict_json(POLICY_PATH), "policy")
    schema = object_value(strict_json(SCHEMA_PATH), "schema")
    scenarios = object_value(strict_json(SCENARIOS_PATH), "scenarios")
    categories = validate_policy(policy)
    validate_schema(schema, list(categories))
    results = validate_scenarios(scenarios, policy, categories)
    mutation_count = run_policy_mutations(policy) + run_schema_mutations(
        schema, list(categories)
    )
    summary = {
        "categoryCount": len(categories),
        "mutationCount": mutation_count,
        "policyDigest": digest(policy),
        "scenarioCount": len(results),
        "scenarioDigest": digest(results),
    }
    if not SHA256.fullmatch(summary["policyDigest"]) or not SHA256.fullmatch(
        summary["scenarioDigest"]
    ):
        raise AssertionError("summary digest generation failed")
    print(
        "ADR-019 unsafe-boundary policy passed: "
        f"{summary['categoryCount']} categories, "
        f"{summary['scenarioCount']} scenarios, "
        f"{summary['mutationCount']} fail-closed mutations"
    )
    print("UNSAFE_BOUNDARY_SUMMARY=" + json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
