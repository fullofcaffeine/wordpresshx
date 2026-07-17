#!/usr/bin/env python3
"""Golden and fail-closed tests for the SDK-014 exact-profile diff."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE_PATH = ROOT / "fixtures" / "profiles" / "valid" / "wp70-release.json"
DIFF_PATH = ROOT / "scripts" / "profiles" / "diff-catalogs.py"
VALIDATOR_PATH = ROOT / "scripts" / "profiles" / "validate-profile-schema.py"
PROFILE_SCHEMA_PATH = ROOT / "schemas" / "profile.schema.json"
DIFF_SCHEMA_PATH = ROOT / "schemas" / "profile-diff.schema.json"
EXPECTED_ROOT = ROOT / "fixtures" / "profile-diffs" / "expected"
INVENTORY_RECEIPT = "SDK-010-WP70-RELEASE-SOURCE"


def load_module(path: Path, name: str) -> object:
    sys.dont_write_bytecode = True
    specification = importlib.util.spec_from_file_location(name, path)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def digest(label: str, algorithm: str = "sha256") -> str:
    return hashlib.new(algorithm, label.encode("utf-8")).hexdigest()


def review_receipt(capability_id: str) -> str:
    return f"CONTRACT-{digest(capability_id)[:12].upper()}"


def typed_capability(
    capability_id: str,
    kind: str,
    contract: dict[str, object],
    *,
    classification: str = "public",
    available_in: list[str] | None = None,
) -> dict[str, object]:
    receipt = review_receipt(capability_id)
    value = copy.deepcopy(contract)
    if "signature" in value:
        value["signature"]["receiptId"] = receipt
    return {
        "capabilityId": capability_id,
        "providerIdentity": "wordpress:profile-diff-fixture",
        "kind": kind,
        "classification": classification,
        "classificationMetadata": {},
        "contract": value,
        "evidenceStatus": "typed",
        "availableIn": available_in or ["wp70-release", "wp71-release"],
        "provenance": [
            {
                "sourceInputId": "wordpress-source",
                "sourcePath": f"fixture/{digest(capability_id)[:16]}.php",
                "sourceDigest": digest(f"source:{capability_id}"),
                "locator": capability_id,
            }
        ],
        "evidence": {
            "inventory": {"receiptId": INVENTORY_RECEIPT},
            "typed": {"contractReviewReceiptId": receipt},
        },
        "receiptIds": [INVENTORY_RECEIPT, receipt],
        "administrativeResults": [],
    }


def signature(shape: str) -> dict[str, object]:
    return {
        "signature": {
            "shape": shape,
            "authority": "curated-reviewed-contract-with-exact-citations",
        }
    }


def profile_pair(validator_module: object) -> tuple[dict[str, object], dict[str, object]]:
    before = json.loads(BASE_PATH.read_text(encoding="utf-8"))
    before["catalog"]["capabilities"][0]["availableIn"] = [
        "wp70-release",
        "wp71-release",
    ]
    capabilities = [
        typed_capability(
            "gutenberg.package.@wordpress/widgets",
            "gutenberg-package",
            {
                "nativeIdentity": "@wordpress/widgets",
                "dependencies": ["@wordpress/data", "@wordpress/element"],
            },
        ),
        typed_capability(
            "wordpress.block-metadata-key.apiVersion",
            "block-metadata-key",
            {
                "metadata": [
                    {"path": "allowedValues", "value": "[1,2,3]"},
                    {"path": "required", "value": "true"},
                ]
            },
        ),
        typed_capability(
            "wordpress.hook.widgets_init",
            "hook",
            signature("widgets_init(): void"),
        ),
        typed_capability(
            "wordpress.php.function.register_widget",
            "php-function",
            signature("register_widget(className: string): void"),
        ),
        typed_capability(
            "wordpress.php.function.removed_api",
            "php-function",
            signature("removed_api(value: string): bool"),
            available_in=["wp70-release"],
        ),
        typed_capability(
            "wordpress.script-handle.wp-widgets",
            "script-handle",
            {"nativeIdentity": "wp-widgets"},
        ),
    ]
    before["catalog"]["capabilities"].extend(capabilities)
    before["catalog"]["capabilities"].sort(
        key=lambda capability: capability["capabilityId"]
    )
    validator_module.refresh_digest(before)

    after = copy.deepcopy(before)
    after_catalog = after["catalog"]
    after_catalog["profileId"] = "wp71-release"
    after_catalog["catalogRevision"] = "wp71-release/catalog-v1"
    source, release = after_catalog["upstreamInputs"]
    source.update(
        {
            "providerIdentity": "wordpress:7.1-source",
            "commit": digest("wordpress-7.1-commit", "sha1"),
            "tree": digest("wordpress-7.1-tree", "sha1"),
            "tag": "7.1.0",
        }
    )
    release.update(
        {
            "providerIdentity": "wordpress:7.1-release",
            "url": "https://wordpress.org/wordpress-7.1.zip",
            "sizeBytes": 32000001,
            "sha256": digest("wordpress-7.1.zip"),
            "contentTreeSha256": digest("wordpress-7.1-tree.zip"),
        }
    )
    by_id = {
        capability["capabilityId"]: capability
        for capability in after_catalog["capabilities"]
    }
    del by_id["wordpress.php.function.removed_api"]
    by_id["wordpress.php.function.register_widget"]["contract"]["signature"][
        "shape"
    ] = "register_widget(className: string, options: array): void"
    by_id["wordpress.script-handle.wp-widgets"]["contract"][
        "nativeIdentity"
    ] = "wp-widgets-v2"
    by_id["wordpress.block-metadata-key.apiVersion"]["contract"]["metadata"][
        0
    ]["value"] = "[2,3]"
    by_id["gutenberg.package.@wordpress/widgets"]["contract"]["dependencies"] = [
        "@wordpress/data",
        "@wordpress/element",
        "@wordpress/hooks",
    ]
    hook = by_id["wordpress.hook.widgets_init"]
    hook["classification"] = "deprecated"
    hook["classificationMetadata"] = {
        "deprecatedSince": "wp71-release",
        "replacementOrReason": "Use wordpress.hook.block_widgets_init.",
        "earliestRemoval": "wp73-release",
    }
    added = typed_capability(
        "gutenberg.export.@wordpress/widgets.registerWidget",
        "gutenberg-export",
        signature("registerWidget(settings: WidgetSettings): WidgetType"),
        available_in=["wp71-release"],
    )
    by_id[added["capabilityId"]] = added
    after_catalog["capabilities"] = sorted(
        by_id.values(), key=lambda capability: capability["capabilityId"]
    )
    validator_module.refresh_digest(after)
    return before, after


def correction_pair(
    before: dict[str, object], validator_module: object
) -> tuple[dict[str, object], dict[str, object]]:
    correction_before = copy.deepcopy(before)
    correction_after = copy.deepcopy(correction_before)
    old_digest = correction_before["catalogDigest"]
    correction_after["catalog"]["catalogRevision"] = "wp70-release/catalog-v2"
    capabilities = {
        capability["capabilityId"]: capability
        for capability in correction_after["catalog"]["capabilities"]
    }
    capabilities["wordpress.php.function.register_widget"]["contract"][
        "signature"
    ]["shape"] = "register_widget(className: class-string): void"
    correction_after["catalog"]["correctionAncestry"] = [old_digest]
    correction_after["catalog"]["correction"] = {
        "correctionOfCatalogDigest": old_digest,
        "priorSdkArtifactIdentity": "wordpress-hx-sdk@0.1.0",
        "reason": "The prior curated contract accepted arbitrary strings instead of class-string values.",
        "consumerContractImpact": "breaking",
        "schemaInterpretationImpact": "unchanged",
        "migration": "Pass a typed class-string value and rerun the widget registration integration fixture.",
        "receiptId": "SDK-014-BREAKING-CORRECTION",
    }
    validator_module.refresh_digest(correction_after)
    return correction_before, correction_after


def write_catalog(path: Path, document: dict[str, object]) -> None:
    path.write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def run_cli(before: Path, after: Path, as_json: bool) -> bytes:
    command = [
        sys.executable,
        str(DIFF_PATH),
        "--from",
        str(before),
        "--to",
        str(after),
    ]
    if as_json:
        command.append("--json")
    result = subprocess.run(command, check=True, capture_output=True)
    assert result.stderr == b""
    return result.stdout


def assert_golden(name: str, suffix: str, actual: bytes) -> None:
    expected_path = EXPECTED_ROOT / f"{name}.{suffix}"
    expected = expected_path.read_bytes()
    assert actual == expected, f"golden output drifted: {expected_path}"


def expect_diff_error(
    diff_module: object,
    before: dict[str, object],
    after: dict[str, object],
    expected: str,
) -> None:
    try:
        diff_module.build_report(before, after)
    except diff_module.ProfileDiffError as error:
        assert expected in str(error), error
        return
    raise AssertionError(f"profile diff did not fail: {expected}")


def main() -> None:
    validator_module = load_module(
        VALIDATOR_PATH, "wordpresshx_profile_diff_test_validator"
    )
    diff_module = load_module(DIFF_PATH, "wordpresshx_profile_diff_test_subject")
    profile_schema = json.loads(PROFILE_SCHEMA_PATH.read_text(encoding="utf-8"))
    profile_validator = validator_module.ClosedSchemaValidator(profile_schema)
    diff_schema = json.loads(DIFF_SCHEMA_PATH.read_text(encoding="utf-8"))
    validator_module.assert_closed_objects(diff_schema)
    diff_validator = validator_module.ClosedSchemaValidator(diff_schema)

    before, after = profile_pair(validator_module)
    correction_before, correction_after = correction_pair(
        before, validator_module
    )
    for document in (before, after, correction_before, correction_after):
        validator_module.validate_document(document, profile_validator)

    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk014-") as temporary:
        temporary_root = Path(temporary)
        pairs = {
            "upstream": (before, after),
            "correction": (correction_before, correction_after),
        }
        for name, (old_document, new_document) in pairs.items():
            old_path = temporary_root / f"{name}-from.json"
            new_path = temporary_root / f"{name}-to.json"
            write_catalog(old_path, old_document)
            write_catalog(new_path, new_document)
            json_output = run_cli(old_path, new_path, True)
            human_output = run_cli(old_path, new_path, False)
            assert json_output == run_cli(old_path, new_path, True)
            report = json.loads(json_output)
            diff_validator.validate(report)
            diff_module.validate_report_semantics(report)
            assert report["policy"] == diff_module.POLICY
            assert report["policy"]["rangeSupport"] == "not-inferred"
            assert report["policy"]["sourceRewrite"] == "not-performed"
            assert_golden(name, "json", json_output)
            assert_golden(name, "txt", human_output)

    upstream_report = diff_module.build_report(before, after)
    correction_report = diff_module.build_report(
        correction_before, correction_after
    )
    assert upstream_report["comparison"]["authority"] == (
        "upstream-profile-change"
    )
    assert correction_report["comparison"]["authority"] == (
        "sdk-catalog-correction"
    )
    assert correction_report["summary"]["breakingChangeCount"] >= 1
    assert any(
        action["action"]
        == correction_after["catalog"]["correction"]["migration"]
        for action in correction_report["migrationActions"]
    )

    unrecorded = copy.deepcopy(correction_before)
    unrecorded["catalog"]["capabilities"][0]["classification"] = "experimental"
    validator_module.refresh_digest(unrecorded)
    expect_diff_error(
        diff_module,
        correction_before,
        unrecorded,
        "lacks an additive correction record",
    )

    mixed_authority = copy.deepcopy(after)
    mixed_authority["catalog"]["correctionAncestry"] = [before["catalogDigest"]]
    mixed_authority["catalog"]["correction"] = {
        "correctionOfCatalogDigest": before["catalogDigest"],
        "priorSdkArtifactIdentity": "wordpress-hx-sdk@0.1.0",
        "reason": "invalid mixed-authority fixture",
        "consumerContractImpact": "breaking",
        "schemaInterpretationImpact": "unchanged",
        "migration": "Do not accept mixed authority.",
        "receiptId": "SDK-014-MIXED-AUTHORITY",
    }
    validator_module.refresh_digest(mixed_authority)
    validator_module.validate_document(mixed_authority, profile_validator)
    expect_diff_error(
        diff_module,
        before,
        mixed_authority,
        "changing the exact profile or upstream inputs",
    )

    invalid_report = copy.deepcopy(upstream_report)
    invalid_report["supportRange"] = "7+"
    try:
        diff_validator.validate(invalid_report)
    except validator_module.ProfileValidationError as error:
        assert "unknown field" in str(error)
    else:
        raise AssertionError("profile diff schema accepted an unknown range claim")

    noncanonical_report = copy.deepcopy(upstream_report)
    noncanonical_report["catalogChanges"][0]["before"]["canonicalJson"] += " "
    noncanonical_report["reportDigest"] = diff_module.report_digest(
        noncanonical_report
    )
    try:
        diff_module.validate_report_semantics(noncanonical_report)
    except diff_module.ProfileDiffError as error:
        assert "non-canonical before JSON" in str(error)
    else:
        raise AssertionError("profile diff accepted non-canonical change JSON")

    print(
        "profile diff tests passed: 2 JSON and 2 human goldens, "
        "4 fail-closed authority/schema negatives"
    )


if __name__ == "__main__":
    main()
