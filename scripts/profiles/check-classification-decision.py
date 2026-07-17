#!/usr/bin/env python3
"""Validate ADR-008's evidence and API-classification architecture."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = ROOT / "profiles" / "classification-decision-lock.json"
SHA256_A = "a" * 64
SHA256_B = "b" * 64


class ClassificationPolicyError(ValueError):
    pass


def state_index(policy: dict[str, object], state: str) -> int:
    states = policy["machineVocabulary"]["evidenceStates"]
    if state not in states:
        raise ClassificationPolicyError(f"unknown evidence state: {state}")
    return states.index(state)


def validate_classification(
    policy: dict[str, object], entry: dict[str, object]
) -> None:
    classifications = policy["machineVocabulary"]["apiClassifications"]
    classification = entry.get("classification")
    if classification not in classifications:
        raise ClassificationPolicyError(
            f"unknown API classification: {classification}"
        )
    state_index(policy, str(entry.get("evidenceStatus")))
    required = classifications[classification].get("requiredMetadata", [])
    metadata = entry.get("classificationMetadata", {})
    for field in required:
        if not metadata.get(field):
            raise ClassificationPolicyError(
                f"{classification} entry lacks required metadata: {field}"
            )
    if classification == "private" and entry.get("consumerImport") is True:
        raise ClassificationPolicyError("private entry entered consumer graph")


def promote(
    policy: dict[str, object],
    entry: dict[str, object],
    target: str,
    receipt: dict[str, object],
) -> dict[str, object]:
    validate_classification(policy, entry)
    current_index = state_index(policy, str(entry["evidenceStatus"]))
    target_index = state_index(policy, target)
    if target_index != current_index + 1:
        raise ClassificationPolicyError(
            "evidence promotion must advance exactly one contiguous state"
        )
    classification = str(entry["classification"])
    classification_rule = policy["machineVocabulary"]["apiClassifications"][
        classification
    ]
    if target == "production-supported" and not classification_rule[
        "productionSupportEligible"
    ]:
        raise ClassificationPolicyError(
            f"{classification} entry is ineligible for production support"
        )
    if entry.get("blockingAdministrativeResult") is not None:
        raise ClassificationPolicyError(
            "blocking administrative result prevents promotion"
        )
    for exact_key in ("profileId", "capabilityId", "catalogDigest"):
        if receipt.get(exact_key) != entry.get(exact_key):
            raise ClassificationPolicyError(
                f"promotion receipt has wrong {exact_key}"
            )
    requirements = policy["promotionPolicy"]["requiredEvidence"][target]
    for field in requirements:
        if receipt.get(field) in (None, "", [], False):
            raise ClassificationPolicyError(
                f"{target} receipt lacks required evidence: {field}"
            )
    updated = copy.deepcopy(entry)
    updated["evidenceStatus"] = target
    updated.setdefault("receiptIds", []).append(receipt["receiptId"])
    return updated


def admit_publication(
    policy: dict[str, object],
    entry: dict[str, object],
    *,
    explicit_opt_in: bool = False,
) -> None:
    validate_classification(policy, entry)
    classification = str(entry["classification"])
    rule = policy["machineVocabulary"]["apiClassifications"][classification]
    if not rule["consumerImportAllowed"]:
        raise ClassificationPolicyError(
            f"{classification} entry cannot be published to consumers"
        )
    if rule["explicitOptIn"] and not explicit_opt_in:
        raise ClassificationPolicyError(
            f"{classification} entry requires explicit opt-in"
        )
    minimum = rule["minimumPublishEvidence"]
    if minimum is None or state_index(
        policy, str(entry["evidenceStatus"])
    ) < state_index(policy, minimum):
        raise ClassificationPolicyError(
            f"{classification} entry is below its publication evidence floor"
        )


def apply_administrative_result(
    policy: dict[str, object],
    entry: dict[str, object],
    result: str,
    reason: str,
) -> dict[str, object]:
    if result not in policy["machineVocabulary"]["administrativeResults"]:
        raise ClassificationPolicyError(
            f"unknown administrative result: {result}"
        )
    if not reason:
        raise ClassificationPolicyError(
            "administrative result requires a reason"
        )
    updated = copy.deepcopy(entry)
    updated["blockingAdministrativeResult"] = {
        "result": result,
        "reason": reason,
    }
    assert updated["evidenceStatus"] == entry["evidenceStatus"]
    return updated


def validate_correction(
    policy: dict[str, object],
    old: dict[str, object],
    replacement: dict[str, object],
) -> None:
    correction = policy["correctionPolicy"]
    if replacement.get("catalogDigest") == old.get("catalogDigest"):
        raise ClassificationPolicyError(
            "replacement correction requires a new catalog digest"
        )
    if replacement.get("sdkArtifactIdentity") == old.get(
        "sdkArtifactIdentity"
    ):
        raise ClassificationPolicyError(
            "replacement correction requires a new SDK/artifact identity"
        )
    if replacement.get("correctionOf") != old.get("catalogDigest"):
        raise ClassificationPolicyError(
            "replacement correction lacks exact correction ancestry"
        )
    if not replacement.get("consumerContractImpact"):
        raise ClassificationPolicyError(
            "replacement correction lacks consumer-contract impact"
        )
    if replacement.get("copyInvalidatedDownstreamEvidence") is True:
        assert correction["invalidatedDownstreamEvidenceMayBeCopied"] is False
        raise ClassificationPolicyError(
            "correction copied invalidated downstream evidence"
        )


def serialize_runtime_result(policy: dict[str, object]) -> None:
    runtime = policy["capabilityTokenPolicy"]["runtimeCapabilityResult"]
    if runtime["serializableAsBuildAuthority"] is False:
        raise ClassificationPolicyError(
            "request-scoped runtime result is not serializable build authority"
        )


def expect_rejected(run: Callable[[], object], label: str) -> None:
    try:
        run()
    except ClassificationPolicyError:
        return
    raise AssertionError(f"classification policy did not fail closed: {label}")


def main() -> None:
    policy = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    vocabulary = policy["machineVocabulary"]
    classifications = vocabulary["apiClassifications"]
    states = vocabulary["evidenceStates"]

    assert policy["schemaVersion"] == 1
    assert policy["decision"] == "ADR-008"
    assert policy["status"] == "accepted-architecture"
    assert policy["claim"] == "not-tested"
    assert policy["schemaImplementationStatus"] == "pending-sdk-012"
    assert policy["generatorImplementationStatus"] == "pending-sdk-013"
    assert set(classifications) == {
        "public",
        "experimental",
        "private",
        "unsafe",
        "deprecated",
    }
    assert classifications["public"]["minimumPublishEvidence"] == (
        "runtime-tested"
    )
    assert classifications["public"]["productionSupportEligible"] is True
    assert classifications["experimental"]["minimumPublishEvidence"] == (
        "typed"
    )
    assert classifications["experimental"][
        "productionSupportEligible"
    ] is False
    assert classifications["private"]["consumerImportAllowed"] is False
    assert classifications["unsafe"]["productionSupportEligible"] is False
    assert classifications["deprecated"]["productionSupportEligible"] is True
    assert vocabulary["serializedClassificationAliases"] == []
    assert states == [
        "inventoried",
        "typed",
        "generated",
        "runtime-tested",
        "production-supported",
    ]
    assert vocabulary["serializedEvidenceAliases"] == []
    assert set(vocabulary["administrativeResults"]) == {
        "not-tested",
        "failed",
        "not-applicable",
        "unsupported",
        "withdrawn",
    }
    assert policy["promotionPolicy"]["contiguous"] is True
    assert policy["promotionPolicy"]["attainedHistoryImmutable"] is True
    assert policy["evidenceAuthority"]["precedenceModel"] == (
        "question-scoped-not-global"
    )
    assert policy["evidenceAuthority"]["ambiguousContract"] == (
        "omit-and-report"
    )
    assert policy["evidenceAuthority"]["broadDynamicFallbackAllowed"] is False

    fixture = policy["knownInventoryFixture"]
    assert fixture["capabilityId"] == (
        "gutenberg.package.@wordpress/content-types"
    )
    assert fixture["availableIn"] == ["gutenberg-forward-23.4"]
    assert fixture["classification"] == "experimental"
    assert fixture["evidenceStatus"] == "inventoried"
    assert fixture["runtimeClaim"] == "not-tested"
    assert fixture["productionClaim"] == "not-tested"

    entry = {
        "profileId": "wp70-release",
        "capabilityId": "fixture.wordpress.hook.init",
        "catalogDigest": SHA256_A,
        "classification": "public",
        "classificationMetadata": {},
        "evidenceStatus": "inventoried",
        "receiptIds": ["INVENTORY-001"],
        "blockingAdministrativeResult": None,
        "consumerImport": False,
    }
    validate_classification(policy, entry)
    expect_rejected(
        lambda: admit_publication(policy, entry),
        "inventoried public candidate published as stable",
    )
    expect_rejected(
        lambda: promote(
            policy,
            entry,
            "generated",
            {
                "receiptId": "GENERATED-001",
                "profileId": entry["profileId"],
                "capabilityId": entry["capabilityId"],
                "catalogDigest": entry["catalogDigest"],
            },
        ),
        "skipped typed evidence state",
    )

    typed = promote(
        policy,
        entry,
        "typed",
        {
            "receiptId": "TYPED-001",
            "profileId": entry["profileId"],
            "capabilityId": entry["capabilityId"],
            "catalogDigest": entry["catalogDigest"],
            "contractReviewReceiptId": "CONTRACT-REVIEW-001",
            "exactProfileId": entry["profileId"],
        },
    )
    generated = promote(
        policy,
        typed,
        "generated",
        {
            "receiptId": "GENERATED-001",
            "profileId": entry["profileId"],
            "capabilityId": entry["capabilityId"],
            "catalogDigest": entry["catalogDigest"],
            "artifactDigest": SHA256_B,
            "generatorIdentity": "fixture-generator@1",
            "staticCheckReceiptId": "STATIC-001",
            "determinismReceiptId": "DETERMINISM-001",
        },
    )
    runtime_tested = promote(
        policy,
        generated,
        "runtime-tested",
        {
            "receiptId": "RUNTIME-001",
            "profileId": entry["profileId"],
            "capabilityId": entry["capabilityId"],
            "catalogDigest": entry["catalogDigest"],
            "artifactDigest": SHA256_B,
            "realRuntime": True,
            "providerIdentity": "wordpress:7.0",
            "environmentIdentity": "fixture-environment",
            "runtimeReceiptId": "REAL-WP-001",
        },
    )
    admit_publication(policy, runtime_tested)
    production_supported = promote(
        policy,
        runtime_tested,
        "production-supported",
        {
            "receiptId": "PRODUCTION-PUBLIC-001",
            "profileId": entry["profileId"],
            "capabilityId": entry["capabilityId"],
            "catalogDigest": entry["catalogDigest"],
            "productionReadinessReceiptId": "READINESS-PUBLIC-001",
            "supportWindow": "2026-2027",
            "maintenanceOwner": "sdk-maintainers",
            "noBlockingResult": True,
        },
    )
    assert production_supported["evidenceStatus"] == "production-supported"
    expect_rejected(
        lambda: promote(
            policy,
            generated,
            "runtime-tested",
            {
                "receiptId": "RUNTIME-WRONG-PROFILE",
                "profileId": "gutenberg-forward-23.4",
                "capabilityId": entry["capabilityId"],
                "catalogDigest": entry["catalogDigest"],
                "artifactDigest": SHA256_B,
                "realRuntime": True,
                "providerIdentity": "wordpress:7.0",
                "environmentIdentity": "fixture-environment",
                "runtimeReceiptId": "REAL-WP-002",
            },
        ),
        "runtime receipt from another profile",
    )

    experimental = copy.deepcopy(typed)
    experimental["classification"] = "experimental"
    expect_rejected(
        lambda: admit_publication(policy, experimental),
        "experimental publication without opt-in",
    )
    admit_publication(policy, experimental, explicit_opt_in=True)
    experimental_runtime = copy.deepcopy(runtime_tested)
    experimental_runtime["classification"] = "experimental"
    expect_rejected(
        lambda: promote(
            policy,
            experimental_runtime,
            "production-supported",
            {
                "receiptId": "PRODUCTION-EXPERIMENTAL-001",
                "profileId": entry["profileId"],
                "capabilityId": entry["capabilityId"],
                "catalogDigest": entry["catalogDigest"],
                "productionReadinessReceiptId": "READINESS-EXPERIMENTAL-001",
                "supportWindow": "2026-2027",
                "maintenanceOwner": "sdk-maintainers",
                "noBlockingResult": True,
            },
        ),
        "experimental entry promoted to production-supported",
    )

    private = copy.deepcopy(runtime_tested)
    private["classification"] = "private"
    expect_rejected(
        lambda: admit_publication(policy, private),
        "private entry in consumer graph",
    )

    unsafe = copy.deepcopy(typed)
    unsafe["classification"] = "unsafe"
    expect_rejected(
        lambda: validate_classification(policy, unsafe),
        "unsafe entry without waiver/security/removal metadata",
    )
    unsafe["classificationMetadata"] = {
        "waiverReceiptId": "WAIVER-001",
        "securityReviewReceiptId": "SECURITY-001",
        "removalOwner": "sdk-maintainers",
    }
    admit_publication(policy, unsafe, explicit_opt_in=True)

    deprecated = copy.deepcopy(runtime_tested)
    deprecated["classification"] = "deprecated"
    expect_rejected(
        lambda: validate_classification(policy, deprecated),
        "deprecated entry without migration/removal metadata",
    )
    deprecated["classificationMetadata"] = {
        "deprecatedSince": "0.9.0",
        "replacementOrReason": "fixture.wordpress.hook.initV2",
        "earliestRemoval": "2.0.0",
    }
    admit_publication(policy, deprecated)

    withdrawn = apply_administrative_result(
        policy,
        runtime_tested,
        "withdrawn",
        "real provider regression invalidated the effective claim",
    )
    assert withdrawn["evidenceStatus"] == "runtime-tested"
    expect_rejected(
        lambda: promote(
            policy,
            withdrawn,
            "production-supported",
            {
                "receiptId": "PRODUCTION-001",
                "profileId": entry["profileId"],
                "capabilityId": entry["capabilityId"],
                "catalogDigest": entry["catalogDigest"],
                "productionReadinessReceiptId": "READINESS-001",
                "supportWindow": "2026-2027",
                "maintenanceOwner": "sdk-maintainers",
                "noBlockingResult": True,
            },
        ),
        "promotion despite withdrawn result",
    )

    expect_rejected(
        lambda: serialize_runtime_result(policy),
        "request-scoped runtime result serialized as build authority",
    )

    old_catalog = {
        "catalogDigest": SHA256_A,
        "sdkArtifactIdentity": "wordpress-hx-sdk@0.1.0",
    }
    corrected_catalog = {
        "catalogDigest": SHA256_B,
        "sdkArtifactIdentity": "wordpress-hx-sdk@0.1.1",
        "correctionOf": SHA256_A,
        "consumerContractImpact": "breaking-signature-correction",
        "copyInvalidatedDownstreamEvidence": False,
    }
    validate_correction(policy, old_catalog, corrected_catalog)
    silently_mutated = copy.deepcopy(corrected_catalog)
    silently_mutated["catalogDigest"] = SHA256_A
    expect_rejected(
        lambda: validate_correction(policy, old_catalog, silently_mutated),
        "correction silently reused released catalog digest",
    )
    copied_evidence = copy.deepcopy(corrected_catalog)
    copied_evidence["copyInvalidatedDownstreamEvidence"] = True
    expect_rejected(
        lambda: validate_correction(policy, old_catalog, copied_evidence),
        "correction copied invalidated downstream evidence",
    )

    print("ADR-008 classification and evidence decision lock passed")


if __name__ == "__main__":
    main()
