#!/usr/bin/env python3
"""Validate the closed SDK-012 profile schema and its exact-profile fixtures."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas" / "profile.schema.json"
CLASSIFICATION_LOCK_PATH = ROOT / "profiles" / "classification-decision-lock.json"
WP_LOCK_PATH = ROOT / "profiles" / "wp70-release" / "source.lock.json"
FORWARD_LOCK_PATH = (
    ROOT / "profiles" / "gutenberg-forward-23.4" / "source.lock.json"
)
FIXTURE_ROOT = ROOT / "fixtures" / "profiles" / "valid"


class ProfileValidationError(ValueError):
    pass


def canonical_catalog_digest(document: dict[str, object]) -> str:
    material = json.dumps(
        {
            "schemaVersion": document["schemaVersion"],
            "generator": document["generator"],
            "catalog": document["catalog"],
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    return hashlib.sha256(material).hexdigest()


class ClosedSchemaValidator:
    def __init__(self, root_schema: dict[str, object]) -> None:
        self.root_schema = root_schema

    def validate(
        self,
        value: object,
        schema: dict[str, object] | None = None,
        path: str = "$",
    ) -> None:
        current = schema or self.root_schema
        if "$ref" in current:
            current = self.resolve_ref(str(current["$ref"]))

        if "oneOf" in current:
            matches = 0
            failures: list[str] = []
            for candidate in current["oneOf"]:
                try:
                    self.validate(value, candidate, path)
                except ProfileValidationError as error:
                    failures.append(str(error))
                    continue
                matches += 1
            if matches != 1:
                details = f"; candidates: {' | '.join(failures)}" if failures else ""
                raise ProfileValidationError(
                    f"{path}: expected exactly one schema match, found {matches}{details}"
                )
            return

        if "const" in current and value != current["const"]:
            raise ProfileValidationError(
                f"{path}: expected constant {current['const']!r}"
            )
        if "enum" in current and value not in current["enum"]:
            raise ProfileValidationError(
                f"{path}: {value!r} is not one of {current['enum']!r}"
            )

        expected_type = current.get("type")
        if expected_type is not None:
            self.require_type(value, str(expected_type), path)

        if isinstance(value, str):
            if len(value) < int(current.get("minLength", 0)):
                raise ProfileValidationError(f"{path}: string is too short")
            pattern = current.get("pattern")
            if pattern is not None and re.fullmatch(str(pattern), value) is None:
                raise ProfileValidationError(
                    f"{path}: {value!r} does not match {pattern!r}"
                )

        if isinstance(value, int) and not isinstance(value, bool):
            if "minimum" in current and value < int(current["minimum"]):
                raise ProfileValidationError(
                    f"{path}: integer is below minimum {current['minimum']}"
                )

        if isinstance(value, list):
            if len(value) < int(current.get("minItems", 0)):
                raise ProfileValidationError(f"{path}: array has too few items")
            if current.get("uniqueItems") is True:
                serialized = [
                    json.dumps(item, sort_keys=True, separators=(",", ":"))
                    for item in value
                ]
                if len(serialized) != len(set(serialized)):
                    raise ProfileValidationError(f"{path}: array items are not unique")
            item_schema = current.get("items")
            if item_schema is not None:
                for index, item in enumerate(value):
                    self.validate(item, item_schema, f"{path}[{index}]")

        if isinstance(value, dict):
            required = current.get("required", [])
            for field in required:
                if field not in value:
                    raise ProfileValidationError(
                        f"{path}: missing required field {field}"
                    )
            properties = current.get("properties", {})
            if current.get("additionalProperties") is False:
                unknown = sorted(set(value) - set(properties))
                if unknown:
                    raise ProfileValidationError(
                        f"{path}: unknown field(s): {', '.join(unknown)}"
                    )
            for field, field_value in value.items():
                if field in properties:
                    self.validate(
                        field_value,
                        properties[field],
                        f"{path}.{field}",
                    )

    def resolve_ref(self, reference: str) -> dict[str, object]:
        if not reference.startswith("#/"):
            raise ProfileValidationError(
                f"external schema reference is forbidden: {reference}"
            )
        current: object = self.root_schema
        for component in reference[2:].split("/"):
            if not isinstance(current, dict) or component not in current:
                raise ProfileValidationError(
                    f"unresolvable schema reference: {reference}"
                )
            current = current[component]
        if not isinstance(current, dict):
            raise ProfileValidationError(
                f"schema reference is not an object: {reference}"
            )
        return current

    @staticmethod
    def require_type(value: object, expected: str, path: str) -> None:
        matches = {
            "object": isinstance(value, dict),
            "array": isinstance(value, list),
            "string": isinstance(value, str),
            "integer": isinstance(value, int) and not isinstance(value, bool),
        }.get(expected)
        if matches is None:
            raise ProfileValidationError(
                f"{path}: unsupported validator schema type {expected}"
            )
        if not matches:
            raise ProfileValidationError(
                f"{path}: expected {expected}, found {type(value).__name__}"
            )


def assert_closed_objects(schema: object, path: str = "$schema") -> None:
    if isinstance(schema, dict):
        if schema.get("type") == "object" and schema.get(
            "additionalProperties"
        ) is not False:
            raise ProfileValidationError(
                f"{path}: object schema is not closed"
            )
        for key, value in schema.items():
            assert_closed_objects(value, f"{path}.{key}")
    elif isinstance(schema, list):
        for index, value in enumerate(schema):
            assert_closed_objects(value, f"{path}[{index}]")


def reject_placeholder_digests(value: object, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            reject_placeholder_digests(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_placeholder_digests(child, f"{path}[{index}]")
    elif isinstance(value, str) and len(value) in (40, 64):
        if re.fullmatch(r"[0-9a-f]+", value) and len(set(value)) == 1:
            raise ProfileValidationError(
                f"{path}: placeholder digest is forbidden"
            )


def require_canonical_json(value: str, path: str) -> None:
    def reject_non_finite(constant: str) -> object:
        raise ValueError(f"non-finite JSON value {constant}")

    try:
        decoded = json.loads(
            value,
            parse_constant=reject_non_finite,
        )
    except (json.JSONDecodeError, ValueError) as error:
        raise ProfileValidationError(
            f"{path}: metadata value is not strict JSON"
        ) from error
    canonical = json.dumps(
        decoded,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    if canonical != value:
        raise ProfileValidationError(
            f"{path}: metadata value is not canonical JSON"
        )


def validate_semantics(document: dict[str, object]) -> None:
    reject_placeholder_digests(document)
    if canonical_catalog_digest(document) != document["catalogDigest"]:
        raise ProfileValidationError("$.catalogDigest: canonical digest mismatch")

    catalog = document["catalog"]
    profile_id = catalog["profileId"]
    if not catalog["catalogRevision"].startswith(f"{profile_id}/catalog-v"):
        raise ProfileValidationError(
            "$.catalog.catalogRevision: revision/profile identity mismatch"
        )

    inputs = catalog["upstreamInputs"]
    input_ids = [item["inputId"] for item in inputs]
    if len(input_ids) != len(set(input_ids)):
        raise ProfileValidationError(
            "$.catalog.upstreamInputs: duplicate inputId"
        )
    for item in inputs:
        source = item.get("repository") or item.get("url")
        if not str(source).startswith("https://"):
            raise ProfileValidationError(
                "$.catalog.upstreamInputs: source must be canonical HTTPS"
            )

    capabilities = catalog["capabilities"]
    capability_ids = [item["capabilityId"] for item in capabilities]
    if len(capability_ids) != len(set(capability_ids)):
        raise ProfileValidationError(
            "$.catalog.capabilities: duplicate capabilityId"
        )
    stages = [
        "inventory",
        "typed",
        "generated",
        "runtimeTested",
        "productionSupported",
    ]
    statuses = [
        "inventoried",
        "typed",
        "generated",
        "runtime-tested",
        "production-supported",
    ]
    for index, capability in enumerate(capabilities):
        path = f"$.catalog.capabilities[{index}]"
        if profile_id not in capability["availableIn"]:
            raise ProfileValidationError(
                f"{path}.availableIn: selected profile is absent"
            )
        for provenance in capability["provenance"]:
            if provenance["sourceInputId"] not in input_ids:
                raise ProfileValidationError(
                    f"{path}.provenance: unknown sourceInputId"
                )

        status_index = statuses.index(capability["evidenceStatus"])
        actual_stages = set(capability["evidence"])
        expected_stages = stages[: status_index + 1]
        if actual_stages != set(expected_stages):
            raise ProfileValidationError(
                f"{path}.evidence: evidence stages must form exact continuous prefix {expected_stages}"
            )
        receipt_ids = set(capability["receiptIds"])
        evidence_receipts: list[str] = []
        for stage in capability["evidence"].values():
            evidence_receipts.extend(
                value
                for key, value in stage.items()
                if key.endswith("ReceiptId") or key == "receiptId"
            )
        if not set(evidence_receipts).issubset(receipt_ids):
            raise ProfileValidationError(
                f"{path}.receiptIds: evidence receipt is not indexed"
            )

        contract = capability.get("contract")
        if status_index == 0 and contract is not None:
            raise ProfileValidationError(
                f"{path}.contract: inventoried evidence cannot publish a reviewed contract"
            )
        if status_index > 0 and contract is None:
            raise ProfileValidationError(
                f"{path}.contract: typed evidence requires a reviewed contract payload"
            )
        if contract is not None:
            if not contract:
                raise ProfileValidationError(
                    f"{path}.contract: contract payload must not be empty"
                )
            signature = contract.get("signature")
            if signature is not None:
                typed_receipt = capability["evidence"]["typed"][
                    "contractReviewReceiptId"
                ]
                if signature["receiptId"] != typed_receipt:
                    raise ProfileValidationError(
                        f"{path}.contract.signature.receiptId: signature must use the typed contract review receipt"
                    )
                if signature["receiptId"] not in receipt_ids:
                    raise ProfileValidationError(
                        f"{path}.contract.signature.receiptId: signature receipt is not indexed"
                    )

            signature_kinds = {
                "php-function",
                "php-class",
                "hook",
                "gutenberg-export",
            }
            if capability["kind"] in signature_kinds and signature is None:
                raise ProfileValidationError(
                    f"{path}.contract.signature: {capability['kind']} requires an exact signature"
                )
            if (
                capability["kind"] == "script-handle"
                and "nativeIdentity" not in contract
            ):
                raise ProfileValidationError(
                    f"{path}.contract.nativeIdentity: script-handle requires an exact native identity"
                )
            if (
                capability["kind"] == "block-metadata-key"
                and "metadata" not in contract
            ):
                raise ProfileValidationError(
                    f"{path}.contract.metadata: block-metadata-key requires exact metadata facts"
                )

            metadata = contract.get("metadata", [])
            metadata_paths = [fact["path"] for fact in metadata]
            if metadata_paths != sorted(metadata_paths):
                raise ProfileValidationError(
                    f"{path}.contract.metadata: facts must be sorted by path"
                )
            if len(metadata_paths) != len(set(metadata_paths)):
                raise ProfileValidationError(
                    f"{path}.contract.metadata: duplicate metadata path"
                )
            for fact_index, fact in enumerate(metadata):
                require_canonical_json(
                    fact["value"],
                    f"{path}.contract.metadata[{fact_index}].value",
                )

            dependencies = contract.get("dependencies", [])
            if dependencies != sorted(dependencies):
                raise ProfileValidationError(
                    f"{path}.contract.dependencies: identities must be sorted"
                )

        classification = capability["classification"]
        metadata = capability["classificationMetadata"]
        required_metadata = {
            "unsafe": {
                "waiverReceiptId",
                "securityReviewReceiptId",
                "removalOwner",
            },
            "deprecated": {
                "deprecatedSince",
                "replacementOrReason",
                "earliestRemoval",
            },
        }.get(classification, set())
        if not required_metadata.issubset(metadata):
            raise ProfileValidationError(
                f"{path}.classificationMetadata: {classification} metadata is incomplete"
            )
        if set(metadata) != required_metadata:
            raise ProfileValidationError(
                f"{path}.classificationMetadata: metadata does not belong to {classification}"
            )
        indexed_receipts = set(evidence_receipts)
        indexed_receipts.update(
            value
            for key, value in metadata.items()
            if key.endswith("ReceiptId")
        )
        indexed_receipts.update(
            result["receiptId"]
            for result in capability["administrativeResults"]
        )
        if not indexed_receipts.issubset(receipt_ids):
            raise ProfileValidationError(
                f"{path}.receiptIds: classification or administrative receipt is not indexed"
            )
        if capability["evidenceStatus"] == "production-supported" and (
            classification not in {"public", "deprecated"}
        ):
            raise ProfileValidationError(
                f"{path}: {classification} is ineligible for production support"
            )

    correction = catalog.get("correction")
    ancestry = catalog["correctionAncestry"]
    if correction is not None:
        prior = correction["correctionOfCatalogDigest"]
        if prior == document["catalogDigest"] or prior not in ancestry:
            raise ProfileValidationError(
                "$.catalog.correction: correction ancestry is not additive"
            )


def validate_document(
    document: dict[str, object], validator: ClosedSchemaValidator
) -> None:
    validator.validate(document)
    validate_semantics(document)


def refresh_digest(document: dict[str, object]) -> None:
    document["catalogDigest"] = canonical_catalog_digest(document)


def expect_invalid(
    validator: ClosedSchemaValidator,
    base: dict[str, object],
    label: str,
    mutate: Callable[[dict[str, object]], None],
    expected_fragment: str,
) -> None:
    document = copy.deepcopy(base)
    mutate(document)
    if "catalogDigest" in document:
        refresh_digest(document)
    try:
        validate_document(document, validator)
    except ProfileValidationError as error:
        if expected_fragment not in str(error):
            raise AssertionError(
                f"{label} failed for wrong reason: {error}"
            ) from error
        return
    raise AssertionError(f"negative schema fixture did not fail: {label}")


def verify_exact_fixture_inputs(
    wp: dict[str, object], forward: dict[str, object]
) -> None:
    wp_lock = json.loads(WP_LOCK_PATH.read_text(encoding="utf-8"))
    forward_lock = json.loads(FORWARD_LOCK_PATH.read_text(encoding="utf-8"))
    wp_source = wp["catalog"]["upstreamInputs"][0]
    wp_release = wp["catalog"]["upstreamInputs"][1]
    forward_source = forward["catalog"]["upstreamInputs"][0]
    forward_release = forward["catalog"]["upstreamInputs"][1]
    assert wp_source["commit"] == wp_lock["wordpressSource"]["commit"]
    assert wp_source["tree"] == wp_lock["wordpressSource"]["tree"]
    locked_wp_release = next(
        artifact
        for artifact in wp_lock["distribution"]["artifacts"]
        if artifact["name"] == "wordpress-7.0.zip"
    )
    assert wp_release["sizeBytes"] == locked_wp_release["sizeBytes"]
    assert wp_release["sha256"] == locked_wp_release["sha256"]
    assert wp_release["contentTreeSha256"] == wp_lock["distribution"][
        "contentTreeSha256"
    ]
    assert forward_source["commit"] == forward_lock["gutenbergSource"]["commit"]
    assert forward_source["tree"] == forward_lock["gutenbergSource"]["tree"]
    assert forward_release["sizeBytes"] == forward_lock["releaseDistribution"][
        "artifact"
    ]["sizeBytes"]
    assert forward_release["sha256"] == forward_lock["releaseDistribution"][
        "artifact"
    ]["sha256"]
    assert forward_release["contentTreeSha256"] == forward_lock[
        "releaseDistribution"
    ]["contentTreeSha256"]
    assert forward["catalog"]["capabilities"][0]["evidenceStatus"] == (
        "inventoried"
    )
    assert forward["catalog"]["capabilities"][0]["classification"] == (
        "experimental"
    )


def main() -> None:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    decision = json.loads(CLASSIFICATION_LOCK_PATH.read_text(encoding="utf-8"))
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["properties"]["schemaVersion"]["const"] == 1
    assert_closed_objects(schema)
    validator = ClosedSchemaValidator(schema)

    classifications = schema["$defs"]["capability"]["properties"][
        "classification"
    ]["enum"]
    evidence_states = schema["$defs"]["capability"]["properties"][
        "evidenceStatus"
    ]["enum"]
    administrative_results = schema["$defs"]["administrativeResult"][
        "properties"
    ]["result"]["enum"]
    signature_authorities = schema["$defs"]["signatureContract"][
        "properties"
    ]["authority"]["enum"]
    assert classifications == list(
        decision["machineVocabulary"]["apiClassifications"]
    )
    assert evidence_states == decision["machineVocabulary"]["evidenceStates"]
    assert administrative_results == decision["machineVocabulary"][
        "administrativeResults"
    ]
    assert signature_authorities == decision["evidenceAuthority"][
        "signatureShape"
    ][:-1]
    assert decision["evidenceAuthority"]["signatureShape"][-1] == (
        "heuristic-inference"
    )

    fixtures = {
        path.stem: json.loads(path.read_text(encoding="utf-8"))
        for path in sorted(FIXTURE_ROOT.glob("*.json"))
    }
    assert set(fixtures) == {"wp70-release", "gutenberg-forward-23.4"}
    for fixture in fixtures.values():
        validate_document(fixture, validator)
    wp = fixtures["wp70-release"]
    forward = fixtures["gutenberg-forward-23.4"]
    verify_exact_fixture_inputs(wp, forward)

    expect_invalid(
        validator,
        forward,
        "unknown root field",
        lambda document: document.update({"supported": True}),
        "unknown field",
    )
    expect_invalid(
        validator,
        forward,
        "unknown classification alias",
        lambda document: document["catalog"]["capabilities"][0].update(
            {"classification": "stable"}
        ),
        "is not one of",
    )
    expect_invalid(
        validator,
        forward,
        "floating upstream source",
        lambda document: document["catalog"]["upstreamInputs"][0].update(
            {"commit": "main"}
        ),
        "does not match",
    )
    expect_invalid(
        validator,
        forward,
        "placeholder upstream pin",
        lambda document: document["catalog"]["upstreamInputs"][0].update(
            {"commit": "0" * 40}
        ),
        "placeholder digest",
    )
    expect_invalid(
        validator,
        forward,
        "skipped evidence stages",
        lambda document: document["catalog"]["capabilities"][0].update(
            {"evidenceStatus": "runtime-tested"}
        ),
        "continuous prefix",
    )
    expect_invalid(
        validator,
        forward,
        "unsafe classification without waiver",
        lambda document: document["catalog"]["capabilities"][0].update(
            {"classification": "unsafe"}
        ),
        "unsafe metadata is incomplete",
    )
    expect_invalid(
        validator,
        forward,
        "capability unavailable in selected profile",
        lambda document: document["catalog"]["capabilities"][0].update(
            {"availableIn": ["wp70-release"]}
        ),
        "selected profile is absent",
    )

    expect_invalid(
        validator,
        forward,
        "reviewed contract attached to inventory-only evidence",
        lambda document: document["catalog"]["capabilities"][0].update(
            {"contract": {"nativeIdentity": "@wordpress/content-types"}}
        ),
        "inventoried evidence cannot publish",
    )

    def promote_without_contract(document: dict[str, object]) -> None:
        capability = document["catalog"]["capabilities"][0]
        capability["evidenceStatus"] = "typed"
        capability["evidence"]["typed"] = {
            "contractReviewReceiptId": "CONTRACT-REVIEW-001"
        }
        capability["receiptIds"].append("CONTRACT-REVIEW-001")

    expect_invalid(
        validator,
        forward,
        "typed evidence without diffable contract",
        promote_without_contract,
        "typed evidence requires a reviewed contract payload",
    )

    def add_heuristic_signature(document: dict[str, object]) -> None:
        promote_without_contract(document)
        capability = document["catalog"]["capabilities"][0]
        capability["kind"] = "gutenberg-export"
        capability["contract"] = {
            "signature": {
                "shape": "register(value: unknown): void",
                "authority": "heuristic-inference",
                "receiptId": "CONTRACT-REVIEW-001",
            }
        }

    expect_invalid(
        validator,
        forward,
        "heuristically inferred signature",
        add_heuristic_signature,
        "is not one of",
    )

    def add_mismatched_signature_receipt(document: dict[str, object]) -> None:
        promote_without_contract(document)
        capability = document["catalog"]["capabilities"][0]
        capability["kind"] = "gutenberg-export"
        capability["receiptIds"].append("CONTRACT-REVIEW-002")
        capability["contract"] = {
            "signature": {
                "shape": "register(value: string): void",
                "authority": "curated-reviewed-contract-with-exact-citations",
                "receiptId": "CONTRACT-REVIEW-002",
            }
        }

    expect_invalid(
        validator,
        forward,
        "signature detached from typed review receipt",
        add_mismatched_signature_receipt,
        "signature must use the typed contract review receipt",
    )

    def add_unsorted_contract_facts(document: dict[str, object]) -> None:
        promote_without_contract(document)
        document["catalog"]["capabilities"][0]["contract"] = {
            "metadata": [
                {"path": "zeta", "value": "true"},
                {"path": "alpha", "value": "1"},
            ]
        }

    expect_invalid(
        validator,
        forward,
        "unsorted contract metadata",
        add_unsorted_contract_facts,
        "facts must be sorted by path",
    )

    def add_bad_correction(document: dict[str, object]) -> None:
        document["catalog"]["correction"] = {
            "correctionOfCatalogDigest": hashlib.sha256(b"prior").hexdigest(),
            "priorSdkArtifactIdentity": "wordpress-hx-sdk@0.0.0",
            "reason": "fixture",
            "consumerContractImpact": "breaking",
            "schemaInterpretationImpact": "unchanged",
            "migration": "fixture migration",
            "receiptId": "CORRECTION-001",
        }

    expect_invalid(
        validator,
        forward,
        "correction without ancestry",
        add_bad_correction,
        "correction ancestry is not additive",
    )

    digest_mismatch = copy.deepcopy(forward)
    digest_mismatch["catalogDigest"] = hashlib.sha256(b"wrong").hexdigest()
    try:
        validate_document(digest_mismatch, validator)
    except ProfileValidationError as error:
        assert "canonical digest mismatch" in str(error)
    else:
        raise AssertionError("catalog digest mismatch did not fail")

    print(
        "profile schema validation passed: 2 exact fixtures, 14 negative fixtures"
    )


if __name__ == "__main__":
    main()
