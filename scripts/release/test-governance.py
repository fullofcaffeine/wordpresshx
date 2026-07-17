#!/usr/bin/env python3
"""Validate SDK-003 governance policy and deterministic dry-run scenarios."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "manifests" / "release-support-policy.json"
SCENARIO_PATH = ROOT / "fixtures" / "release-governance" / "scenarios.json"
EXPECTED_PATH = (
    ROOT / "fixtures" / "release-governance" / "expected" / "rehearsal.json"
)
SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def canonical_json(value: object) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def digest(value: object) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise AssertionError(
            f"{label} fields drifted; missing={missing}, unknown={unknown}"
        )


def require_sorted_unique(values: list[str], label: str) -> None:
    assert values == sorted(values), f"{label} must be sorted"
    assert len(values) == len(set(values)), f"{label} must be unique"


def validate_policy(policy: dict[str, object]) -> None:
    exact_keys(
        policy,
        {
            "schemaVersion",
            "policyId",
            "decision",
            "status",
            "currentState",
            "channels",
            "supportTerm",
            "profilePolicy",
            "matrixPolicy",
            "deprecationPolicy",
            "securityPolicy",
            "owners",
            "contributionPolicy",
            "releasePolicy",
            "rollbackPolicy",
            "claims",
        },
        "policy",
    )
    assert policy["schemaVersion"] == 1
    assert policy["policyId"] == "wordpresshx-release-support-v1"
    assert policy["decision"] == "ADR-021"
    assert policy["status"] == "accepted-policy-not-release-ready"

    current = policy["currentState"]
    exact_keys(
        current,
        {
            "phase",
            "supportedVersions",
            "publicationAllowed",
            "stableReleaseAllowed",
            "blockingConditions",
        },
        "current state",
    )
    assert current["phase"] == "0.x-development"
    assert current["supportedVersions"] == []
    assert current["publicationAllowed"] is False
    assert current["stableReleaseAllowed"] is False
    require_sorted_unique(current["blockingConditions"], "stable blockers")
    assert set(current["blockingConditions"]) == {
        "backup-release-security-owner",
        "final-package-consumer-matrix",
        "g8-production-evidence",
        "licensing-and-output-review",
        "private-vulnerability-reporting",
        "production-release-rollback-rehearsal",
    }

    channels = policy["channels"]
    assert [channel["channel"] for channel in channels] == [
        "development",
        "nightly",
        "preview",
        "stable",
        "security-patch",
    ]
    for channel in channels:
        exact_keys(
            channel,
            {
                "channel",
                "minimumIdentity",
                "support",
                "productionClaimAllowed",
            },
            f"channel {channel['channel']}",
        )
    assert all(
        channel["productionClaimAllowed"] is False
        for channel in channels[:3]
    )
    assert all(
        channel["productionClaimAllowed"] is True for channel in channels[3:]
    )

    support = policy["supportTerm"]
    exact_keys(
        support,
        {
            "defaultDays",
            "startAuthority",
            "exactUtcEndRequired",
            "publishedEndMayMoveEarlier",
            "successorEndsPriorTerm",
            "olderPatchMaintenance",
            "endOfSupportEffect",
        },
        "support term",
    )
    assert support["defaultDays"] == 180
    assert support["exactUtcEndRequired"] is True
    assert support["publishedEndMayMoveEarlier"] is False
    assert support["successorEndsPriorTerm"] is False

    profile = policy["profilePolicy"]
    exact_keys(
        profile,
        {
            "authority",
            "firstStableCandidate",
            "forwardProfile",
            "versionRangeInferenceAllowed",
            "unlistedRuntimeInferenceAllowed",
            "supportCannotExceedSdkTerm",
        },
        "profile policy",
    )
    assert profile["authority"] == "exact-profile-catalog-digest-membership"
    assert profile["firstStableCandidate"] == "wp70-release"
    assert profile["forwardProfile"] == (
        "gutenberg-forward-23.4-preview-only"
    )
    assert profile["versionRangeInferenceAllowed"] is False
    assert profile["unlistedRuntimeInferenceAllowed"] is False
    assert profile["supportCannotExceedSdkTerm"] is True

    matrix = policy["matrixPolicy"]
    exact_keys(
        matrix,
        {
            "authority",
            "dimensions",
            "rangeInferenceAllowed",
            "newPatchAdmission",
        },
        "matrix policy",
    )
    assert matrix["authority"] == "closed-exact-release-manifest"
    require_sorted_unique(matrix["dimensions"], "matrix dimensions")
    assert matrix["rangeInferenceAllowed"] is False

    deprecation = policy["deprecationPolicy"]
    exact_keys(
        deprecation,
        {
            "minimumSubsequentStableMinors",
            "minimumDays",
            "normalRemovalRelease",
            "migrationRequired",
            "machineClassificationRequired",
            "securityWithdrawalMayBypassWindow",
            "securityWithdrawalMode",
        },
        "deprecation policy",
    )
    assert deprecation["minimumSubsequentStableMinors"] == 1
    assert deprecation["minimumDays"] == 180
    assert deprecation["normalRemovalRelease"] == "major"
    assert deprecation["migrationRequired"] is True
    assert deprecation["machineClassificationRequired"] is True

    security = policy["securityPolicy"]
    exact_keys(
        security,
        {
            "privateIntake",
            "numericResponseSlaPromised",
            "publicExploitDetailsAllowed",
            "backportsLimitedToActiveStableTerms",
            "activeStableDependencyReviewCadenceDays",
            "exactMatrixRerunRequired",
            "artifactOverwriteAllowed",
        },
        "security policy",
    )
    intake = security["privateIntake"]
    exact_keys(
        intake,
        {
            "provider",
            "repository",
            "enabled",
            "observedAt",
            "observationCommand",
        },
        "private intake",
    )
    assert intake["provider"] == "github-private-vulnerability-reporting"
    assert intake["repository"] == "fullofcaffeine/wordpresshx"
    assert intake["enabled"] is False
    assert intake["observedAt"] == "2026-07-17"
    assert security["numericResponseSlaPromised"] is False
    assert security["publicExploitDetailsAllowed"] is False
    assert security["backportsLimitedToActiveStableTerms"] is True
    assert security["activeStableDependencyReviewCadenceDays"] == 30
    assert security["exactMatrixRerunRequired"] is True
    assert security["artifactOverwriteAllowed"] is False

    owners = policy["owners"]
    responsibilities = [owner["responsibility"] for owner in owners]
    assert responsibilities == sorted(responsibilities)
    assert len(responsibilities) == len(set(responsibilities))
    for owner in owners:
        exact_keys(
            owner,
            {"responsibility", "primary", "backup", "readiness"},
            f"owner {owner['responsibility']}",
        )
    owner_by_role = {owner["responsibility"]: owner for owner in owners}
    assert owner_by_role["product-scope-and-claim-matrix"]["primary"] == (
        "Marcelo Serpa"
    )
    assert owner_by_role["private-security-intake-and-coordination"][
        "readiness"
    ] == "blocked-private-channel-disabled"
    assert owner_by_role["backup-release-security-recovery"] == {
        "responsibility": "backup-release-security-recovery",
        "primary": "unassigned",
        "backup": "unassigned",
        "readiness": "stable-blocker",
    }

    contribution = policy["contributionPolicy"]
    exact_keys(
        contribution,
        {
            "routineMaintainerFlow",
            "pullRequestRole",
            "genesCompilerChange",
            "beadsRequired",
            "hookBypassAllowed",
            "automatedAgentIsAccountableOwner",
        },
        "contribution policy",
    )
    assert contribution["routineMaintainerFlow"] == (
        "direct-main-after-bead-scope-hooks-and-proportionate-gates"
    )
    assert contribution["genesCompilerChange"] == (
        "isolated-upstream-worktree-full-regression-then-pr"
    )
    assert contribution["beadsRequired"] is True
    assert contribution["hookBypassAllowed"] is False
    assert contribution["automatedAgentIsAccountableOwner"] is False

    release = policy["releasePolicy"]
    exact_keys(
        release,
        {
            "cleanCanonicalWorkflowOnly",
            "doubleBuildRequired",
            "downloadedByteVerificationRequired",
            "apiProfileClaimDiffRequired",
            "licenseSbomProvenanceRequired",
            "unsafeInventoryRequired",
            "upgradeRollbackExerciseRequired",
            "localDirtyReleaseAllowed",
        },
        "release policy",
    )
    assert all(
        release[field] is True
        for field in release
        if field != "localDirtyReleaseAllowed"
    )
    assert release["localDirtyReleaseAllowed"] is False

    rollback = policy["rollbackPolicy"]
    exact_keys(
        rollback,
        {
            "tagOrArtifactOverwriteAllowed",
            "lastKnownGoodImmutableIdentityRequired",
            "newReplacementVersionRequired",
            "claimCorrectionAdditive",
            "databaseRollbackRequiresProvenReversibleMigration",
            "forwardRepairWhenStateRollbackUnsafe",
            "downloadedReplacementVerificationRequired",
        },
        "rollback policy",
    )
    assert rollback["tagOrArtifactOverwriteAllowed"] is False
    assert all(
        rollback[field] is True
        for field in rollback
        if field != "tagOrArtifactOverwriteAllowed"
    )

    claims = policy["claims"]
    exact_keys(
        claims,
        {
            "releasePolicy",
            "stableReleaseReadiness",
            "supportedVersions",
            "securityResponseSla",
            "wordpressRuntimeCompatibility",
            "productionSupport",
        },
        "claims",
    )
    assert claims == {
        "releasePolicy": "accepted",
        "stableReleaseReadiness": "blocked",
        "supportedVersions": "none",
        "securityResponseSla": "not-promised",
        "wordpressRuntimeCompatibility": "not-tested",
        "productionSupport": "not-tested",
    }


def validate_scenarios(
    scenarios: dict[str, object], policy: dict[str, object]
) -> None:
    exact_keys(
        scenarios,
        {
            "schemaVersion",
            "scenarioSet",
            "policyId",
            "simulationOnly",
            "sourceCommit",
            "scenarios",
        },
        "scenario set",
    )
    assert scenarios["schemaVersion"] == 1
    assert scenarios["scenarioSet"] == "sdk003-governance-rehearsal-v1"
    assert scenarios["policyId"] == "wordpresshx-release-support-v1"
    assert scenarios["simulationOnly"] is True
    assert SHA1.fullmatch(scenarios["sourceCommit"])
    ids = [scenario["id"] for scenario in scenarios["scenarios"]]
    assert ids == sorted(ids)
    assert len(ids) == len(set(ids)) == 4

    owners = {
        owner["responsibility"]: owner["primary"]
        for owner in policy["owners"]
    }
    owner_role_by_kind = {
        "public-issue-triage": "product-scope-and-claim-matrix",
        "private-security-intake": (
            "private-security-intake-and-coordination"
        ),
        "stable-release-attempt": (
            "release-publish-and-download-verification"
        ),
        "immutable-rollback": (
            "rollback-revocation-and-claim-correction"
        ),
    }

    for scenario in scenarios["scenarios"]:
        kind = scenario["kind"]
        assert scenario["actor"] == owners[owner_role_by_kind[kind]]
        if kind == "public-issue-triage":
            expected = {
                "id",
                "kind",
                "actor",
                "sensitive",
                "channel",
                "expectedDecision",
            }
            assert scenario["sensitive"] is False
        elif kind == "private-security-intake":
            expected = {
                "id",
                "kind",
                "actor",
                "sensitive",
                "privateChannelEnabled",
                "publicDetailsAllowed",
                "expectedDecision",
            }
            assert scenario["sensitive"] is True
            assert scenario["privateChannelEnabled"] is False
            assert scenario["publicDetailsAllowed"] is False
        elif kind == "stable-release-attempt":
            expected = {
                "id",
                "kind",
                "actor",
                "candidateVersion",
                "candidateCommit",
                "profileId",
                "catalogDigest",
                "publicationRequested",
                "expectedBlockers",
                "expectedDecision",
            }
            assert SHA1.fullmatch(scenario["candidateCommit"])
            assert SHA256.fullmatch(scenario["catalogDigest"])
            assert scenario["candidateCommit"] == scenarios["sourceCommit"]
            assert scenario["candidateVersion"] == "1.0.0"
            assert scenario["profileId"] == policy["profilePolicy"][
                "firstStableCandidate"
            ]
            assert scenario["publicationRequested"] is True
            assert scenario["expectedBlockers"] == policy[
                "currentState"
            ]["blockingConditions"]
            require_sorted_unique(
                scenario["expectedBlockers"], "scenario release blockers"
            )
        elif kind == "immutable-rollback":
            expected = {
                "id",
                "kind",
                "actor",
                "badVersion",
                "badArtifactSha256",
                "lastKnownGoodVersion",
                "lastKnownGoodArtifactSha256",
                "overwriteRequested",
                "replacementVersion",
                "expectedDecision",
            }
            assert SHA256.fullmatch(scenario["badArtifactSha256"])
            assert SHA256.fullmatch(
                scenario["lastKnownGoodArtifactSha256"]
            )
            assert scenario["badArtifactSha256"] != scenario[
                "lastKnownGoodArtifactSha256"
            ]
            assert scenario["badArtifactSha256"] == hashlib.sha256(
                f"wordpresshx-sdk-{scenario['badVersion']}-bad".encode()
            ).hexdigest()
            assert scenario["lastKnownGoodArtifactSha256"] == (
                hashlib.sha256(
                    (
                        "wordpresshx-sdk-"
                        f"{scenario['lastKnownGoodVersion']}-good"
                    ).encode()
                ).hexdigest()
            )
            assert scenario["badVersion"] == "1.0.1"
            assert scenario["lastKnownGoodVersion"] == "1.0.0"
            assert scenario["replacementVersion"] == "1.0.2"
            assert scenario["overwriteRequested"] is True
        else:
            raise AssertionError(f"unknown rehearsal kind: {kind}")
        exact_keys(scenario, expected, f"scenario {scenario['id']}")


def scenario_result(
    scenario: dict[str, object], policy: dict[str, object]
) -> dict[str, str]:
    kind = scenario["kind"]
    if kind == "public-issue-triage":
        decision = "accepted-public-triage"
        next_action = (
            "Create or route a Bead with exact scope, evidence, severity, and no sensitive data."
        )
        evidence = f"channel={scenario['channel']};sensitive=false"
    elif kind == "private-security-intake":
        decision = "blocked-request-secure-channel-before-details"
        next_action = (
            "Enable and test private vulnerability reporting; send no exploit details publicly."
        )
        evidence = "private-channel-enabled=false;public-details-allowed=false"
    elif kind == "stable-release-attempt":
        assert scenario["expectedBlockers"] == policy["currentState"][
            "blockingConditions"
        ]
        decision = "blocked-stable-publication"
        next_action = (
            "Resolve every recorded stable blocker; keep the candidate development-only."
        )
        evidence = canonical_json(
            {
                "candidateCommit": scenario["candidateCommit"],
                "catalogDigest": scenario["catalogDigest"],
                "profileId": scenario["profileId"],
                "blockers": scenario["expectedBlockers"],
            }
        )
    elif kind == "immutable-rollback":
        assert policy["rollbackPolicy"]["tagOrArtifactOverwriteAllowed"] is False
        assert scenario["overwriteRequested"] is True
        decision = "reject-overwrite-publish-new-replacement-version"
        next_action = (
            "Restore the last known-good identity, rerun state/installation checks, and publish the replacement version."
        )
        evidence = canonical_json(
            {
                "badArtifactSha256": scenario["badArtifactSha256"],
                "lastKnownGoodArtifactSha256": scenario[
                    "lastKnownGoodArtifactSha256"
                ],
                "replacementVersion": scenario["replacementVersion"],
            }
        )
    else:
        raise AssertionError(f"unknown scenario kind: {kind}")
    assert decision == scenario["expectedDecision"]
    return {
        "id": scenario["id"],
        "kind": kind,
        "outcome": "passed",
        "owner": scenario["actor"],
        "decision": decision,
        "nextAction": next_action,
        "evidence": evidence,
    }


def report_digest(report: dict[str, object]) -> str:
    material = {
        key: value
        for key, value in report.items()
        if key not in {"reportDigestAlgorithm", "reportDigest"}
    }
    return digest(material)


def build_report(
    policy: dict[str, object], scenarios: dict[str, object]
) -> dict[str, object]:
    results = [
        scenario_result(scenario, policy)
        for scenario in scenarios["scenarios"]
    ]
    report = {
        "schemaVersion": 1,
        "reportKind": "wordpresshx-release-governance-rehearsal",
        "reportDigestAlgorithm": "sha256-canonical-json-v1",
        "reportDigest": "",
        "policyId": policy["policyId"],
        "scenarioSet": scenarios["scenarioSet"],
        "simulationOnly": True,
        "resultCount": len(results),
        "results": results,
        "claims": {
            "governanceDryRun": "passed",
            "privateSecurityChannel": "blocked-disabled",
            "stableReleaseReadiness": "blocked",
            "productionSupport": "not-tested",
        },
    }
    report["reportDigest"] = report_digest(report)
    return report


def validate_report(report: dict[str, object]) -> None:
    exact_keys(
        report,
        {
            "schemaVersion",
            "reportKind",
            "reportDigestAlgorithm",
            "reportDigest",
            "policyId",
            "scenarioSet",
            "simulationOnly",
            "resultCount",
            "results",
            "claims",
        },
        "rehearsal report",
    )
    assert report["schemaVersion"] == 1
    assert report["reportKind"] == (
        "wordpresshx-release-governance-rehearsal"
    )
    assert report["reportDigestAlgorithm"] == "sha256-canonical-json-v1"
    assert SHA256.fullmatch(report["reportDigest"])
    assert report["reportDigest"] == report_digest(report)
    assert report["simulationOnly"] is True
    assert report["resultCount"] == len(report["results"]) == 4
    ids = [result["id"] for result in report["results"]]
    assert ids == sorted(ids)
    for result in report["results"]:
        exact_keys(
            result,
            {
                "id",
                "kind",
                "outcome",
                "owner",
                "decision",
                "nextAction",
                "evidence",
            },
            f"result {result['id']}",
        )
        assert result["outcome"] == "passed"
        assert result["owner"] == "Marcelo Serpa"
    assert report["claims"] == {
        "governanceDryRun": "passed",
        "privateSecurityChannel": "blocked-disabled",
        "stableReleaseReadiness": "blocked",
        "productionSupport": "not-tested",
    }


def validate_documents() -> None:
    required_fragments = {
        "GOVERNANCE.md": [
            "Marcelo Serpa",
            "Direct-to-main",
            "unassigned backup",
        ],
        "SUPPORT.md": [
            "No supported versions",
            "180-day",
            "exact release manifest",
        ],
        "SECURITY.md": [
            "private vulnerability reporting is currently disabled",
            "No numeric response-time or resolution SLA",
            "stable-release blocker",
        ],
        "CONTRIBUTING.md": [
            "Routine maintainer changes may land directly on `main`",
            "Pull requests are a coordination tool",
            "Severity and triage",
        ],
        "docs/release/README.md": [
            "ADR-021 is accepted",
            "180 consecutive days",
            "Publication decision: blocked",
        ],
    }
    for relative_path, fragments in required_fragments.items():
        content = (ROOT / relative_path).read_text(encoding="utf-8")
        for fragment in fragments:
            assert fragment in content, f"{relative_path} lacks {fragment!r}"


def main() -> None:
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    scenarios = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    validate_policy(policy)
    validate_scenarios(scenarios, policy)
    report = build_report(policy, scenarios)
    validate_report(report)
    expected = json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))
    validate_report(expected)
    expected_bytes = EXPECTED_PATH.read_bytes()
    actual_bytes = (
        json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    ).encode("utf-8")
    assert actual_bytes == expected_bytes, "release-governance golden drifted"
    validate_documents()
    print(
        "release governance tests passed: closed policy, 4 deterministic "
        "issue/security/release/rollback rehearsals"
    )


if __name__ == "__main__":
    main()
