#!/usr/bin/env python3
"""Validate the closed ADR-017 generated-output version-control policy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


SHA1 = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")

EXPECTED_ARTIFACT_CLASSES = [
    "authored-haxe-and-hand-owned-assets",
    "exact-toolchain-bootstrap-and-locks",
    "private-stage-cache-and-transaction-state",
    "release-archives-and-debug-companions",
    "reviewed-contract-snapshots-and-required-build-inputs",
    "runtime-and-deployment-output",
]

EXPECTED_MODES = [
    "consumer-committed-output-opt-in",
    "consumer-default",
    "sdk",
]

EXPECTED_MODE_CONTRACTS = {
    "consumer-committed-output-opt-in": {
        "selectedByDefault": False,
        "commits": [
            "authored-haxe-and-hand-owned-assets",
            "exact-toolchain-bootstrap-and-locks",
            "runtime-and-deployment-output",
        ],
        "ignores": [
            "private-stage-cache-and-transaction-state",
            "release-archives-and-debug-companions",
        ],
        "requiredMetadata": [
            "exact-generated-manifest",
            "explicit-output-root-policy",
        ],
        "generatedOutputAdmission": "explicit-per-output-root-with-adr007-manifest",
        "requiredGate": "fresh-regenerate-and-byte-compare",
    },
    "consumer-default": {
        "selectedByDefault": True,
        "commits": [
            "authored-haxe-and-hand-owned-assets",
            "exact-toolchain-bootstrap-and-locks",
        ],
        "ignores": [
            "private-stage-cache-and-transaction-state",
            "release-archives-and-debug-companions",
            "runtime-and-deployment-output",
        ],
        "requiredMetadata": [],
        "generatedOutputAdmission": "none",
        "requiredGate": "clean-regenerate-and-test",
    },
    "sdk": {
        "selectedByDefault": True,
        "commits": [
            "authored-haxe-and-hand-owned-assets",
            "exact-toolchain-bootstrap-and-locks",
            "reviewed-contract-snapshots-and-required-build-inputs",
        ],
        "ignores": [
            "private-stage-cache-and-transaction-state",
            "release-archives-and-debug-companions",
            "runtime-and-deployment-output",
        ],
        "requiredMetadata": [
            "declared-generated-artifact-role",
            "provenance-record",
        ],
        "generatedOutputAdmission": "review-contract-or-required-build-input-with-provenance",
        "requiredGate": "fresh-regenerate-and-byte-compare",
    },
}

EXPECTED_DRIFT_STEPS = [
    "resolve-exact-source-tool-profile-and-generator-identities",
    "regenerate-into-new-private-stage",
    "validate-complete-adr007-manifest-and-artifacts",
    "compare-path-set-byte-size-sha256-and-bytes",
    "review-authored-and-generated-diffs-together",
    "publish-manifest-last-when-requested-or-succeed-validation-only-without-live-mutation",
]

EXPECTED_FAILURES = [
    "committed-output-without-declared-role",
    "generated-diff-without-corresponding-authority-change",
    "manual-generated-file-edit",
    "missing-extra-or-byte-different-regeneration",
    "stale-or-mismatched-source-tool-profile-or-generator-identity",
]

EXPECTED_REFERENCES = {
    "haxe.elixir.codex": {
        "commit": "a4897cd3106f916c26f813388215f69699e742cc",
        "path": "test/AGENTS.md",
        "blob": "f66aa0813a96f356684ec040572ae1de3d525e5b",
        "sha256": "bf4bee56b022503fb50449ddb419d6c33ea5f952f7fb2bea4cfab445339af397",
    },
    "haxe.ocaml": {
        "commit": "945a0a2896fa8cc2e47b1a375df319d4acce32d8",
        "path": "docs/02-user-guide/SOURCE_NATIVE_RUNTIME_PACKAGING_STRATEGY.md",
        "blob": "27028808e9ac7c14b58fcc6d73e545ef8a877430",
        "sha256": "1959eb2a6c9755e6632662655e07d25522949c9761017b916336acd408f05c77",
    },
    "haxe.ruby": {
        "commit": "a647b11055bde552823c4e7cede31ecf9f5d0bc5",
        "path": "docs/railshx-generated-artifact-ownership.md",
        "blob": "d4b0a998a9bcbf2286f8d78b9bae902458f5098f",
        "sha256": "5faf4040863ed189b6a8907cb0930026ed7bb52d4cee8e78e0fa3b83d7a4e761",
    },
}


class Audit:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def keys(self, value: Any, expected: set[str], context: str) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{context}: expected object")
            return
        actual = set(value)
        if actual != expected:
            self.errors.append(
                f"{context}: closed keys differ; expected {sorted(expected)}, "
                f"found {sorted(actual)}"
            )


def read_object(path: Path, audit: Audit) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        audit.errors.append(f"{path}: cannot read valid JSON: {error}")
        return {}
    if not isinstance(value, dict):
        audit.errors.append(f"{path}: top level must be an object")
        return {}
    return value


def validate_authority(audit: Audit, authority: Any) -> None:
    audit.keys(
        authority,
        {
            "authoredApplicationSource",
            "generatedOutputRole",
            "ownershipContract",
            "canonicalization",
            "exactProjectLockRequired",
            "generatedBytesMaySupersedeAuthoredSource",
            "handEditGeneratedOutputAllowed",
            "sameBytesGrantOwnership",
        },
        "policy.authority",
    )
    if not isinstance(authority, dict):
        return
    audit.check(
        authority.get("authoredApplicationSource") == "haxe",
        "authority.authoredApplicationSource must be haxe",
    )
    audit.check(
        authority.get("generatedOutputRole")
        == "derived-inspectable-non-authoritative",
        "authority.generatedOutputRole must remain derived and non-authoritative",
    )
    audit.check(
        authority.get("ownershipContract") == "wordpress-hx.generated-files.v1",
        "authority.ownershipContract must use ADR-007 v1",
    )
    audit.check(
        authority.get("canonicalization") == "wordpress-hx.canonical-json.v1",
        "authority.canonicalization must use the repository canonical JSON contract",
    )
    audit.check(
        authority.get("exactProjectLockRequired") is True,
        "authority.exactProjectLockRequired must be true",
    )
    for field in (
        "generatedBytesMaySupersedeAuthoredSource",
        "handEditGeneratedOutputAllowed",
        "sameBytesGrantOwnership",
    ):
        audit.check(authority.get(field) is False, f"authority.{field} must be false")


def validate_artifact_classes(audit: Audit, classes: Any) -> None:
    if not isinstance(classes, list):
        audit.errors.append("policy.artifactClasses must be an array")
        return
    ids = [item.get("id") for item in classes if isinstance(item, dict)]
    audit.check(ids == EXPECTED_ARTIFACT_CLASSES, "artifactClasses must be complete and sorted")
    for index, item in enumerate(classes):
        context = f"policy.artifactClasses[{index}]"
        audit.keys(item, {"id", "vcsDefault", "authority", "examples"}, context)
        if not isinstance(item, dict):
            continue
        examples = item.get("examples")
        audit.check(
            isinstance(examples, list)
            and len(examples) > 0
            and examples == sorted(set(examples)),
            f"{context}.examples must be a non-empty sorted unique array",
        )
    by_id = {
        item["id"]: item for item in classes if isinstance(item, dict) and "id" in item
    }
    expected_defaults = {
        "authored-haxe-and-hand-owned-assets": ("commit", "authored"),
        "exact-toolchain-bootstrap-and-locks": ("commit", "derived-input"),
        "private-stage-cache-and-transaction-state": ("ignore", "ephemeral"),
        "release-archives-and-debug-companions": ("ignore", "release-artifact"),
        "reviewed-contract-snapshots-and-required-build-inputs": (
            "conditional-sdk",
            "derived-review-contract",
        ),
        "runtime-and-deployment-output": (
            "ignore-consumer-default",
            "derived-deployment",
        ),
    }
    for class_id, expected in expected_defaults.items():
        item = by_id.get(class_id, {})
        audit.check(
            (item.get("vcsDefault"), item.get("authority")) == expected,
            f"artifact class {class_id} has the wrong VCS default or authority",
        )


def validate_modes(audit: Audit, modes: Any) -> None:
    if not isinstance(modes, list):
        audit.errors.append("policy.repositoryModes must be an array")
        return
    ids = [item.get("id") for item in modes if isinstance(item, dict)]
    audit.check(ids == EXPECTED_MODES, "repositoryModes must be complete and sorted")
    for index, item in enumerate(modes):
        context = f"policy.repositoryModes[{index}]"
        audit.keys(
            item,
            {
                "id",
                "selectedByDefault",
                "commits",
                "ignores",
                "requiredMetadata",
                "generatedOutputAdmission",
                "requiredGate",
            },
            context,
        )
        if not isinstance(item, dict):
            continue
        for field in ("commits", "ignores", "requiredMetadata"):
            value = item.get(field)
            audit.check(
                isinstance(value, list) and value == sorted(set(value)),
                f"{context}.{field} must be a sorted unique array",
            )
        mode_id = item.get("id")
        expected = EXPECTED_MODE_CONTRACTS.get(mode_id)
        actual_contract = {key: value for key, value in item.items() if key != "id"}
        audit.check(
            actual_contract == expected,
            f"{context} must match the complete closed {mode_id} contract",
        )
        artifact_ids = set(EXPECTED_ARTIFACT_CLASSES)
        commits = item.get("commits", [])
        ignores = item.get("ignores", [])
        audit.check(
            isinstance(commits, list) and set(commits) <= artifact_ids,
            f"{context}.commits contains an undeclared artifact class",
        )
        audit.check(
            isinstance(ignores, list) and set(ignores) <= artifact_ids,
            f"{context}.ignores contains an undeclared artifact class",
        )
        audit.check(
            isinstance(commits, list)
            and isinstance(ignores, list)
            and set(commits).isdisjoint(ignores),
            f"{context} cannot both commit and ignore one artifact class",
        )
    by_id = {
        item["id"]: item for item in modes if isinstance(item, dict) and "id" in item
    }
    default_consumer = by_id.get("consumer-default", {})
    audit.check(
        default_consumer.get("selectedByDefault") is True,
        "consumer-default must be selected by default",
    )
    audit.check(
        default_consumer.get("generatedOutputAdmission") == "none",
        "consumer-default must not admit committed generated output",
    )
    audit.check(
        default_consumer.get("requiredGate") == "clean-regenerate-and-test",
        "consumer-default must regenerate and test in CI",
    )
    audit.check(
        "runtime-and-deployment-output" in default_consumer.get("ignores", []),
        "consumer-default must ignore runtime and deployment output",
    )

    opt_in = by_id.get("consumer-committed-output-opt-in", {})
    audit.check(
        opt_in.get("selectedByDefault") is False,
        "consumer committed output must be opt-in",
    )
    audit.check(
        opt_in.get("generatedOutputAdmission")
        == "explicit-per-output-root-with-adr007-manifest",
        "consumer opt-in must be explicit per root and use ADR-007 ownership",
    )
    audit.check(
        opt_in.get("requiredGate") == "fresh-regenerate-and-byte-compare",
        "consumer opt-in must compare a fresh regeneration",
    )

    sdk = by_id.get("sdk", {})
    audit.check(sdk.get("selectedByDefault") is True, "SDK mode must be its default")
    audit.check(
        sdk.get("generatedOutputAdmission")
        == "review-contract-or-required-build-input-with-provenance",
        "SDK generated commits must have a named review or build-input role",
    )
    audit.check(
        sdk.get("requiredGate") == "fresh-regenerate-and-byte-compare",
        "SDK committed generated artifacts must compare fresh bytes",
    )


def validate_drift(audit: Audit, drift: Any) -> None:
    audit.keys(
        drift,
        {
            "committedOutputChangeUnit",
            "steps",
            "failureConditions",
            "reviewRequirements",
            "manualEditRemediation",
        },
        "policy.driftWorkflow",
    )
    if not isinstance(drift, dict):
        return
    audit.check(
        drift.get("committedOutputChangeUnit")
        == "same-change-as-source-generator-policy-or-lock",
        "committed output must travel with its authority change",
    )
    audit.check(drift.get("steps") == EXPECTED_DRIFT_STEPS, "drift steps must be exact")
    audit.check(
        drift.get("failureConditions") == EXPECTED_FAILURES,
        "drift failure conditions must be complete and sorted",
    )
    expected_review = [
        "generated-diff-is-evidence-never-authority",
        "review-source-generator-lock-and-output-diff-together",
        "unexplained-or-out-of-scope-generated-diff-fails",
    ]
    audit.check(
        drift.get("reviewRequirements") == expected_review,
        "drift review requirements must be complete and sorted",
    )
    audit.check(
        drift.get("manualEditRemediation") == "edit-haxe-or-generator-then-regenerate",
        "manual generated edits must be remediated through source or generator",
    )


def validate_release(audit: Audit, release: Any) -> None:
    audit.keys(
        release,
        {
            "sourceIdentity",
            "workingTreeGeneratedOutputTrusted",
            "committedGeneratedOutputTrustedWithoutRegeneration",
            "ambientCacheTrusted",
            "privateStageOutsideSourceCheckout",
            "regenerationRuns",
            "generatedTreeComparison",
            "archiveBuilds",
            "archiveComparison",
            "checkoutMustRemainUnchanged",
            "provenanceBinds",
            "committedGeneratedBuildInputRule",
            "publicationAuthorization",
        },
        "policy.releaseProtocol",
    )
    if not isinstance(release, dict):
        return
    audit.check(
        release.get("sourceIdentity") == "immutable-clean-commit-or-tag",
        "release source must be an immutable clean identity",
    )
    for field in (
        "workingTreeGeneratedOutputTrusted",
        "committedGeneratedOutputTrustedWithoutRegeneration",
        "ambientCacheTrusted",
    ):
        audit.check(release.get(field) is False, f"releaseProtocol.{field} must be false")
    for field in ("privateStageOutsideSourceCheckout", "checkoutMustRemainUnchanged"):
        audit.check(release.get(field) is True, f"releaseProtocol.{field} must be true")
    audit.check(release.get("regenerationRuns") == 2, "release must regenerate twice")
    audit.check(release.get("archiveBuilds") == 2, "release must build the archive twice")
    audit.check(
        release.get("generatedTreeComparison")
        == "exact-path-size-sha256-and-bytes",
        "release generated trees must use exact path, size, digest, and byte comparison",
    )
    audit.check(
        release.get("archiveComparison") == "byte-for-byte",
        "release archives must compare byte-for-byte",
    )
    audit.check(
        release.get("provenanceBinds")
        == [
            "archive-digest",
            "generated-manifest-digest",
            "generator-identity",
            "profile-identity",
            "source-commit",
            "toolchain-lock",
        ],
        "release provenance bindings must be complete and sorted",
    )
    audit.check(
        release.get("committedGeneratedBuildInputRule")
        == "fresh-regeneration-must-compare-exactly",
        "committed generated release inputs must be freshly compared",
    )
    audit.check(
        release.get("publicationAuthorization") == "separate-adr020-and-adr021-gates",
        "ADR-017 must not authorize publication",
    )


def validate_change_control(audit: Audit, change: Any) -> None:
    audit.keys(
        change,
        {
            "consumerDefaultChangeRequires",
            "generatedArtifactClassExpansionRequiresReview",
            "releaseRegenerationMayBeRelaxed",
            "ownershipMeaningChangeRequires",
        },
        "policy.changeControl",
    )
    if not isinstance(change, dict):
        return
    audit.check(
        change.get("consumerDefaultChangeRequires")
        == "superseding-adr-and-scaffold-migration",
        "the consumer default requires an explicit migration to change",
    )
    audit.check(
        change.get("generatedArtifactClassExpansionRequiresReview") is True,
        "new committed generated artifact classes require review",
    )
    audit.check(
        change.get("releaseRegenerationMayBeRelaxed") is False,
        "release regeneration is an invariant stop condition",
    )
    audit.check(
        change.get("ownershipMeaningChangeRequires") == "new-adr007-contract-major",
        "ownership meaning changes require a new ADR-007 contract major",
    )


def validate_references(audit: Audit, references: Any) -> None:
    if not isinstance(references, list):
        audit.errors.append("policy.referencePatterns must be an array")
        return
    repositories = [item.get("repository") for item in references if isinstance(item, dict)]
    audit.check(
        repositories == sorted(EXPECTED_REFERENCES),
        "referencePatterns must be the complete sorted read-only reference set",
    )
    for index, reference in enumerate(references):
        context = f"policy.referencePatterns[{index}]"
        audit.keys(
            reference,
            {
                "repository",
                "commit",
                "path",
                "blob",
                "sha256",
                "concept",
                "copiedBytes",
                "dependencyCreated",
            },
            context,
        )
        if not isinstance(reference, dict):
            continue
        repository = reference.get("repository")
        expected = EXPECTED_REFERENCES.get(repository, {})
        for field in ("commit", "path", "blob", "sha256"):
            audit.check(
                reference.get(field) == expected.get(field),
                f"{context}.{field} must match the reviewed identity",
            )
        audit.check(
            isinstance(reference.get("concept"), str) and len(reference["concept"]) > 20,
            f"{context}.concept must state the adapted concept",
        )
        audit.check(reference.get("copiedBytes") is False, f"{context} copied bytes")
        audit.check(
            reference.get("dependencyCreated") is False,
            f"{context} created a sibling dependency",
        )
        audit.check(
            SHA1.fullmatch(str(reference.get("commit"))) is not None,
            f"{context}.commit must be a SHA-1 identity",
        )
        audit.check(
            SHA1.fullmatch(str(reference.get("blob"))) is not None,
            f"{context}.blob must be a SHA-1 identity",
        )
        audit.check(
            SHA256.fullmatch(str(reference.get("sha256"))) is not None,
            f"{context}.sha256 must be a SHA-256 identity",
        )


def validate_claims(audit: Audit, claims: Any, policy_status: object) -> None:
    decision_status = (
        "accepted"
        if policy_status == "accepted"
        else "proposed-hosted-evidence-pending"
    )
    expected = {
        "architectureDecision": decision_status,
        "closedPolicyContract": "validated",
        "gitFixtureReplay": "runtime-tested",
        "productionWphxIntegration": "not-tested",
        "deterministicWordPressZip": "not-tested",
        "registryRelease": "not-tested",
        "productionSupport": "not-tested",
    }
    audit.keys(claims, set(expected), "policy.claims")
    audit.check(claims == expected, "policy.claims must preserve the exact evidence boundary")


def validate_policy(policy: dict[str, Any]) -> list[str]:
    audit = Audit()
    audit.keys(
        policy,
        {
            "schemaVersion",
            "policyId",
            "decision",
            "status",
            "authority",
            "artifactClasses",
            "repositoryModes",
            "driftWorkflow",
            "releaseProtocol",
            "changeControl",
            "referencePatterns",
            "claims",
        },
        "policy",
    )
    audit.check(policy.get("schemaVersion") == 1, "policy.schemaVersion must be 1")
    audit.check(
        policy.get("policyId") == "wordpress-hx.generated-output-vcs.v1",
        "policy.policyId must identify v1",
    )
    audit.check(policy.get("decision") == "ADR-017", "policy.decision must be ADR-017")
    audit.check(
        policy.get("status") in {"proposed-hosted-evidence-pending", "accepted"},
        "policy.status must be pending hosted evidence or accepted",
    )
    validate_authority(audit, policy.get("authority"))
    validate_artifact_classes(audit, policy.get("artifactClasses"))
    validate_modes(audit, policy.get("repositoryModes"))
    validate_drift(audit, policy.get("driftWorkflow"))
    validate_release(audit, policy.get("releaseProtocol"))
    validate_change_control(audit, policy.get("changeControl"))
    validate_references(audit, policy.get("referencePatterns"))
    validate_claims(audit, policy.get("claims"), policy.get("status"))
    return audit.errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--policy",
        type=Path,
        default=Path("manifests/generated-output-vcs-policy.json"),
    )
    arguments = parser.parse_args()
    audit = Audit()
    policy = read_object(arguments.policy, audit)
    audit.errors.extend(validate_policy(policy))
    if audit.errors:
        for error in audit.errors:
            print(f"generated-output VCS policy error: {error}", file=sys.stderr)
        return 1
    print("ADR-017 generated-output VCS policy is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
