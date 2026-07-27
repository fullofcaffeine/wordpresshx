#!/usr/bin/env python3
"""Verify committed SDK-013 catalogs, fingerprints, and omission reports."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SELECTION_PATH = ROOT / "profiles" / "catalog-selection.json"
SCHEMA_PATH = ROOT / "schemas" / "profile.schema.json"
GENERATOR_PATH = ROOT / "scripts" / "profiles" / "generate-catalogs.py"
CATALOG_CORE_PATH = ROOT / "scripts" / "profiles" / "catalog-core-v1.py"
GENERATED_ROOT = ROOT / "generated"
VALIDATOR_PATH = ROOT / "scripts" / "profiles" / "validate-profile-schema.py"
TOOLCHAIN_IDENTITY = "python-stdlib-json-v1+git-object-reader-v1"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def pointer_component(value: str) -> str:
    return value.replace("~", "~0").replace("/", "~1")


def leaf_fields(value: object, path: str = "") -> list[tuple[str, object]]:
    if isinstance(value, dict):
        if not value:
            return [(path, value)]
        fields: list[tuple[str, object]] = []
        for name, child in value.items():
            fields.extend(
                leaf_fields(child, path + "/" + pointer_component(str(name)))
            )
        return fields
    if isinstance(value, list):
        if not value:
            return [(path, value)]
        fields = []
        for index, child in enumerate(value):
            fields.extend(leaf_fields(child, f"{path}/{index}"))
        return fields
    return [(path, value)]


def pointer(value: object, path: str) -> object:
    current = value
    assert path.startswith("/")
    for raw_component in path[1:].split("/"):
        component = raw_component.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict):
            current = current[component]
        else:
            assert isinstance(current, list) and component.isdigit()
            current = current[int(component)]
    return current


def exact_keys(value: dict[str, object], expected: set[str], label: str) -> None:
    assert set(value) == expected, f"{label}: closed fields drifted"


def load_validator() -> object:
    sys.dont_write_bytecode = True
    specification = importlib.util.spec_from_file_location(
        "wordpresshx_profile_validator", VALIDATOR_PATH
    )
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def expected_input(
    definition: dict[str, object], source_lock: dict[str, object]
) -> dict[str, object]:
    output = {
        "inputId": definition["inputId"],
        "kind": definition["kind"],
        "providerIdentity": definition["providerIdentity"],
    }
    for field, path in definition["pointers"].items():
        output[field] = pointer(source_lock, path)
    return output


def verify_omissions(
    document: dict[str, object],
    profile: dict[str, object],
    generator: dict[str, object],
) -> None:
    exact_keys(
        document,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "omissionsDigestAlgorithm",
            "omissionsDigest",
            "generator",
            "omissions",
        },
        "omissions",
    )
    assert document["schemaVersion"] == 1
    assert document["profileId"] == profile["profileId"]
    assert document["catalogRevision"] == profile["catalogRevision"]
    assert document["generator"] == generator
    assert document["omissionsDigestAlgorithm"] == "sha256-canonical-json-v1"
    material = canonical(
        {
            "schemaVersion": document["schemaVersion"],
            "profileId": document["profileId"],
            "catalogRevision": document["catalogRevision"],
            "generator": document["generator"],
            "omissions": document["omissions"],
        }
    )
    assert document["omissionsDigest"] == digest(material)
    expected_ids = sorted(item["omissionId"] for item in profile["omissions"])
    actual_ids = [item["omissionId"] for item in document["omissions"]]
    assert actual_ids == expected_ids
    for entry in document["omissions"]:
        exact_keys(
            entry,
            {
                "omissionId",
                "kind",
                "sourceInputId",
                "sourcePath",
                "sourceDigest",
                "locator",
                "reasonCode",
                "reason",
                "receiptIds",
            },
            f"omission {entry['omissionId']}",
        )
        assert SHA256.fullmatch(entry["sourceDigest"])
        assert entry["reasonCode"] in {
            "dynamic-name-needs-curated-pattern",
            "signature-needs-curation",
            "private-api-forbidden",
        }


def verify_field_origins(
    document: dict[str, object],
    profile: dict[str, object],
    generator: dict[str, object],
    effective_inputs: set[tuple[str, str, str]],
    catalog_bytes: bytes,
    catalog: dict[str, object],
    omission_bytes: bytes,
    omissions: dict[str, object],
) -> None:
    exact_keys(
        document,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "status",
            "legalAdvice",
            "publicationAuthorized",
            "distributionConclusion",
            "fieldOriginsDigestAlgorithm",
            "fieldOriginsDigest",
            "generator",
            "upstreamLicenseEvidence",
            "outputs",
            "summary",
        },
        "field origins",
    )
    assert document["schemaVersion"] == 1
    assert document["profileId"] == profile["profileId"]
    assert document["catalogRevision"] == profile["catalogRevision"]
    assert document["status"] == "field-origins-inventoried-review-pending"
    assert document["legalAdvice"] is False
    assert document["publicationAuthorized"] is False
    assert document["distributionConclusion"] == (
        "pending-product-owner-and-qualified-review-of-exact-generated-catalog"
    )
    assert document["fieldOriginsDigestAlgorithm"] == "sha256-canonical-json-v1"
    assert document["generator"] == generator
    digest_material = {
        key: value
        for key, value in document.items()
        if key != "fieldOriginsDigest"
    }
    assert document["fieldOriginsDigest"] == digest(canonical(digest_material))

    licenses = document["upstreamLicenseEvidence"]
    assert isinstance(licenses, list)
    expected_license_count = sum(
        int(definition.get("licenseEvidence") is not None)
        for definition in profile["inputs"]
    )
    assert len(licenses) == expected_license_count
    for license_evidence in licenses:
        exact_keys(
            license_evidence,
            {
                "sourceInputId",
                "repository",
                "commit",
                "tree",
                "expression",
                "sourcePath",
                "sourceBlob",
                "sourceSha256",
                "snapshotPath",
                "snapshotSha256",
            },
            "upstream license evidence",
        )
        assert SHA256.fullmatch(license_evidence["sourceSha256"])
        assert (
            license_evidence["sourceSha256"]
            == license_evidence["snapshotSha256"]
        )
        snapshot = ROOT / license_evidence["snapshotPath"]
        assert snapshot.is_file()
        assert digest(snapshot.read_bytes()) == license_evidence["snapshotSha256"]
        assert (
            license_evidence["sourceInputId"],
            license_evidence["sourcePath"],
            license_evidence["sourceSha256"],
        ) in effective_inputs

    expected_outputs = {
        "catalog.json": (catalog_bytes, catalog),
        "omissions.json": (omission_bytes, omissions),
    }
    outputs = document["outputs"]
    assert isinstance(outputs, list)
    assert [output["path"] for output in outputs] == sorted(expected_outputs)
    origin_counts: dict[str, int] = {}
    field_count = 0
    upstream_span_sources: dict[str, int] = {}
    for output in outputs:
        exact_keys(
            output,
            {"path", "sha256", "fieldCount", "fields"},
            "field-origin output",
        )
        output_bytes, output_document = expected_outputs[output["path"]]
        assert output["sha256"] == digest(output_bytes)
        expected_fields = {
            path: digest(canonical(value))
            for path, value in leaf_fields(output_document)
        }
        fields = output["fields"]
        assert isinstance(fields, list)
        assert output["fieldCount"] == len(fields) == len(expected_fields)
        assert [field["outputPointer"] for field in fields] == sorted(
            expected_fields
        )
        for field in fields:
            exact_keys(
                field,
                {"outputPointer", "valueSha256", "origin"},
                "field-origin entry",
            )
            field_pointer = field["outputPointer"]
            assert field["valueSha256"] == expected_fields[field_pointer]
            origin = field["origin"]
            exact_keys(
                origin,
                {"class", "authority", "transform", "source"},
                f"field origin {field_pointer}",
            )
            origin_class = origin["class"]
            assert origin_class in {
                "sdk-authored",
                "sdk-generated",
                "upstream-identity-derived",
                "upstream-identity-verbatim",
                "upstream-normalized",
            }
            origin_counts[origin_class] = origin_counts.get(origin_class, 0) + 1
            source = origin["source"]
            source_kind = source["kind"]
            if source_kind == "repository-file":
                exact_keys(
                    source,
                    {"kind", "path", "sha256"},
                    "repository-file origin",
                )
                source_path = ROOT / source["path"]
                assert source_path.is_file()
                assert digest(source_path.read_bytes()) == source["sha256"]
            elif source_kind == "repository-json-field":
                exact_keys(
                    source,
                    {"kind", "path", "sha256", "jsonPointer"},
                    "repository JSON origin",
                )
                source_path = ROOT / source["path"]
                assert source_path.is_file()
                assert digest(source_path.read_bytes()) == source["sha256"]
                pointer(
                    json.loads(source_path.read_bytes()),
                    source["jsonPointer"],
                )
            elif source_kind == "upstream-source-span":
                exact_keys(
                    source,
                    {
                        "kind",
                        "sourceInputId",
                        "sourcePath",
                        "sourceSha256",
                        "locator",
                        "matches",
                    },
                    "upstream source-span origin",
                )
                assert (
                    source["sourceInputId"],
                    source["sourcePath"],
                    source["sourceSha256"],
                ) in effective_inputs
                matches = source["matches"]
                assert isinstance(matches, list) and matches
                upstream_span_sources[
                    digest(canonical(source))
                ] = len(matches)
                for match in matches:
                    exact_keys(
                        match,
                        {
                            "byteStart",
                            "byteEnd",
                            "lineStart",
                            "columnStart",
                            "sha256",
                        },
                        "upstream source span",
                    )
                    assert 0 <= match["byteStart"] < match["byteEnd"]
                    assert match["lineStart"] > 0 and match["columnStart"] > 0
                    assert SHA256.fullmatch(match["sha256"])
            else:
                raise AssertionError(
                    f"unknown field-origin source kind: {source_kind}"
                )
            field_count += 1

    summary = document["summary"]
    exact_keys(
        summary,
        {
            "fieldCount",
            "originFieldCounts",
            "upstreamSourceSpanCount",
            "upstreamLicenseEvidenceCount",
        },
        "field-origin summary",
    )
    assert summary["fieldCount"] == field_count
    assert summary["originFieldCounts"] == {
        key: origin_counts[key] for key in sorted(origin_counts)
    }
    assert summary["upstreamSourceSpanCount"] == sum(
        upstream_span_sources.values()
    )
    assert summary["upstreamLicenseEvidenceCount"] == len(licenses)


def verify_report(
    report: dict[str, object],
    profile: dict[str, object],
    generator: dict[str, object],
    selection_digest: str,
    source_lock_bytes: bytes,
    upstream_inputs: list[dict[str, object]],
    catalog_bytes: bytes,
    catalog: dict[str, object],
    omission_bytes: bytes,
    omissions: dict[str, object],
    field_origins_bytes: bytes,
    field_origins: dict[str, object],
) -> None:
    exact_keys(
        report,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "generator",
            "inventoryReceiptId",
            "inputFingerprintAlgorithm",
            "inputFingerprint",
            "selection",
            "profileSchema",
            "sourceLock",
            "effectiveInputs",
            "outputs",
            "claims",
        },
        "generation report",
    )
    assert report["schemaVersion"] == 1
    assert report["profileId"] == profile["profileId"]
    assert report["catalogRevision"] == profile["catalogRevision"]
    assert report["generator"] == generator
    assert report["inventoryReceiptId"] == "SDK-013-PROFILE-GENERATOR"
    assert report["inputFingerprintAlgorithm"] == "sha256-canonical-json-v1"
    assert report["selection"] == {
        "path": "profiles/catalog-selection.json",
        "sha256": selection_digest,
    }
    assert report["profileSchema"] == {
        "path": "schemas/profile.schema.json",
        "sha256": digest(SCHEMA_PATH.read_bytes()),
    }
    assert report["sourceLock"] == {
        "path": profile["sourceLockPath"],
        "sha256": digest(source_lock_bytes),
    }
    effective_inputs = report["effectiveInputs"]
    assert effective_inputs == sorted(
        effective_inputs,
        key=lambda item: (item["sourceInputId"], item["sourcePath"]),
    )
    effective_keys: set[tuple[str, str, str]] = set()
    for entry in effective_inputs:
        exact_keys(
            entry,
            {"sourceInputId", "sourcePath", "sourceDigest"},
            "effective input",
        )
        assert SHA256.fullmatch(entry["sourceDigest"])
        key = (
            entry["sourceInputId"],
            entry["sourcePath"],
            entry["sourceDigest"],
        )
        assert key not in effective_keys
        effective_keys.add(key)
    for capability in catalog["catalog"]["capabilities"]:
        for provenance in capability["provenance"]:
            assert (
                provenance["sourceInputId"],
                provenance["sourcePath"],
                provenance["sourceDigest"],
            ) in effective_keys
    for omission in omissions["omissions"]:
        assert (
            omission["sourceInputId"],
            omission["sourcePath"],
            omission["sourceDigest"],
        ) in effective_keys

    fingerprint_material = {
        "generatorSourceDigest": generator["sourceDigest"],
        "selectionDigest": selection_digest,
        "profileSchemaDigest": digest(SCHEMA_PATH.read_bytes()),
        "sourceLockDigest": digest(source_lock_bytes),
        "upstreamInputs": upstream_inputs,
        "effectiveInputs": effective_inputs,
    }
    assert report["inputFingerprint"] == digest(canonical(fingerprint_material))
    assert report["outputs"] == {
        "catalog": {
            "path": "catalog.json",
            "sha256": digest(catalog_bytes),
            "catalogDigest": catalog["catalogDigest"],
            "capabilityCount": len(catalog["catalog"]["capabilities"]),
        },
        "omissions": {
            "path": "omissions.json",
            "sha256": digest(omission_bytes),
            "omissionsDigest": omissions["omissionsDigest"],
            "omissionCount": len(omissions["omissions"]),
        },
        "fieldOrigins": {
            "path": "field-origins.json",
            "sha256": digest(field_origins_bytes),
            "fieldOriginsDigest": field_origins["fieldOriginsDigest"],
            "fieldCount": field_origins["summary"]["fieldCount"],
        },
    }
    assert report["claims"] == {
        "catalogEvidenceStatus": "inventoried",
        "typedContracts": "not-tested",
        "runtimeCompatibility": "not-tested",
        "productionSupport": "not-tested",
        "upstreamCodeExecuted": False,
    }


def main() -> None:
    selection_bytes = SELECTION_PATH.read_bytes()
    selection = json.loads(selection_bytes)
    assert selection["schemaVersion"] == 1
    assert selection["inventoryReceiptId"] == "SDK-013-PROFILE-GENERATOR"
    selection_digest = digest(selection_bytes)
    catalog_generator = {
        "identity": selection["generatorIdentity"],
        "version": selection["generatorVersion"],
        "sourceDigest": digest(CATALOG_CORE_PATH.read_bytes()),
        "toolchainIdentity": TOOLCHAIN_IDENTITY,
    }
    evidence_generator = {
        "identity": selection["generatorIdentity"],
        "version": selection["generatorVersion"],
        "sourceDigest": digest(GENERATOR_PATH.read_bytes()),
        "toolchainIdentity": TOOLCHAIN_IDENTITY,
    }
    validator_module = load_validator()
    schema = json.loads(SCHEMA_PATH.read_bytes())
    validator = validator_module.ClosedSchemaValidator(schema)

    profiles = sorted(selection["profiles"], key=lambda item: item["profileId"])
    assert [profile["profileId"] for profile in profiles] == [
        "gutenberg-forward-23.4",
        "wp70-release",
    ]
    expected_files: set[Path] = set()
    catalogs: dict[str, dict[str, object]] = {}
    omissions_by_profile: dict[str, dict[str, object]] = {}
    for profile in profiles:
        target = GENERATED_ROOT / profile["targetPath"]
        catalog_path = target / "catalog.json"
        omission_path = target / "omissions.json"
        field_origins_path = target / "field-origins.json"
        report_path = target / "generation-report.json"
        expected_files.update(
            {catalog_path, omission_path, field_origins_path, report_path}
        )
        catalog_bytes = catalog_path.read_bytes()
        omission_bytes = omission_path.read_bytes()
        field_origins_bytes = field_origins_path.read_bytes()
        catalog = json.loads(catalog_bytes)
        omissions = json.loads(omission_bytes)
        field_origins = json.loads(field_origins_bytes)
        report = json.loads(report_path.read_bytes())
        validator_module.validate_document(catalog, validator)
        assert catalog["generator"] == catalog_generator
        assert catalog["catalog"]["profileId"] == profile["profileId"]
        assert catalog["catalog"]["catalogRevision"] == profile["catalogRevision"]
        source_lock_bytes = (ROOT / profile["sourceLockPath"]).read_bytes()
        source_lock = json.loads(source_lock_bytes)
        upstream_inputs = [
            expected_input(definition, source_lock)
            for definition in profile["inputs"]
        ]
        assert catalog["catalog"]["upstreamInputs"] == upstream_inputs
        expected_capabilities = sorted(
            item["capabilityId"] for item in profile["capabilities"]
        )
        actual_capabilities = [
            item["capabilityId"] for item in catalog["catalog"]["capabilities"]
        ]
        assert actual_capabilities == expected_capabilities
        for capability in catalog["catalog"]["capabilities"]:
            assert capability["evidenceStatus"] == "inventoried"
            assert set(capability["evidence"]) == {"inventory"}
            assert capability["administrativeResults"][0]["result"] == "not-tested"
        verify_omissions(omissions, profile, catalog_generator)
        effective_keys = {
            (
                entry["sourceInputId"],
                entry["sourcePath"],
                entry["sourceDigest"],
            )
            for entry in report["effectiveInputs"]
        }
        verify_field_origins(
            field_origins,
            profile,
            evidence_generator,
            effective_keys,
            catalog_bytes,
            catalog,
            omission_bytes,
            omissions,
        )
        verify_report(
            report,
            profile,
            evidence_generator,
            selection_digest,
            source_lock_bytes,
            upstream_inputs,
            catalog_bytes,
            catalog,
            omission_bytes,
            omissions,
            field_origins_bytes,
            field_origins,
        )
        catalogs[profile["profileId"]] = catalog
        omissions_by_profile[profile["profileId"]] = omissions

    actual_files = set(GENERATED_ROOT.glob("**/*.json"))
    assert actual_files == expected_files
    wp_ids = {
        item["capabilityId"]
        for item in catalogs["wp70-release"]["catalog"]["capabilities"]
    }
    forward_ids = {
        item["capabilityId"]
        for item in catalogs["gutenberg-forward-23.4"]["catalog"]["capabilities"]
    }
    assert len(wp_ids) == 31
    assert len(forward_ids) == 5
    assert {
        "wordpress.php.function.add_action",
        "wordpress.php.function.register_rest_route",
        "wordpress.hook.init",
        "gutenberg.export.@wordpress/blocks.registerBlockType",
        "wordpress.script-handle.wp-blocks",
        "wordpress.script-handle.react",
        "wordpress.script-handle.react-dom",
        "wordpress.script-handle.react-jsx-runtime",
        "wordpress.block-metadata-key.apiVersion",
    }.issubset(wp_ids)
    assert "gutenberg.package.@wordpress/content-types" in forward_ids
    assert "gutenberg.package.@wordpress/content-types" not in wp_ids
    assert all(
        capability["availableIn"] == ["gutenberg-forward-23.4"]
        for capability in catalogs["gutenberg-forward-23.4"]["catalog"][
            "capabilities"
        ]
    )
    wp_omissions = {
        item["omissionId"]
        for item in omissions_by_profile["wp70-release"]["omissions"]
    }
    forward_omissions = {
        item["omissionId"]
        for item in omissions_by_profile["gutenberg-forward-23.4"]["omissions"]
    }
    assert "wordpress.dynamic-hook.save_post_post_type" in wp_omissions
    assert "gutenberg.content-types.private-api-lock" in forward_omissions
    print(
        "generated profile catalog checks passed: "
        "36 inventoried capabilities, 4 explicit omissions"
    )


if __name__ == "__main__":
    main()
