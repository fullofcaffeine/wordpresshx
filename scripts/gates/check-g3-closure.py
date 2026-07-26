#!/usr/bin/env python3
"""Validate Gate G3's aggregate, fail-closed closure receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")

EVIDENCE = [
    ("ADR-006-SEMANTIC-PLAN-CONTRACT", "wordpresshx-adr-006", "manifests/evidence/adr-006-semantic-plan-contract.json"),
    ("SDK-040-SEMANTIC-COLLECTOR", "wordpresshx-sdk-040", "manifests/evidence/sdk-040-semantic-collector.json"),
    ("ADR-007-GENERATED-ARTIFACT-OWNERSHIP", "wordpresshx-adr-007", "manifests/evidence/adr-007-generated-artifact-ownership.json"),
    ("SDK-041-OWNERSHIP-TRANSACTION", "wordpresshx-sdk-041", "manifests/evidence/sdk-041-ownership-transaction.json"),
    ("SDK-042-DETERMINISTIC-BUILD", "wordpresshx-sdk-042", "manifests/evidence/sdk-042-deterministic-build.json"),
    ("SDK-043-PROJECT-CLI", "wordpresshx-sdk-043", "manifests/evidence/sdk-043-project-cli.json"),
    ("SDK-026-GENERATED-PHP-QUALITY", "wordpresshx-sdk-026", "manifests/evidence/sdk-026-generated-php-quality.json"),
    ("SDK-045-PLUGIN-SCAFFOLD", "wordpresshx-sdk-045.2", "manifests/evidence/sdk-045-plugin-scaffold.json"),
]

SUBJECTS = {
    "projectCliImplementation": "manifests/project-cli-implementation.json",
    "cliArguments": "packages/cli/src/wordpresshx/cli/CliArguments.hx",
    "projectCliCorpus": "scripts/project-cli/test-production.py",
    "cliDocumentation": "packages/cli/README.md",
}

SCENARIOS = [
    "path-traversal",
    "symlink",
    "duplicate",
    "case-collision",
    "unowned-destination",
    "modified-owned-file",
    "stale-modified-file",
    "malformed-manifest",
]


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def json(self, relative: str, label: str) -> dict[str, Any]:
        try:
            value = json.loads((self.root / relative).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self.errors.append(f"cannot read {label}: {error}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be an object")
            return {}
        return value

    def digest(self, relative: str) -> str:
        try:
            return hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
        except OSError as error:
            self.errors.append(f"cannot hash {relative}: {error}")
            return ""


def nested(value: dict[str, Any], *keys: str) -> Any:
    current: Any = value
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def exact_keys(audit: Audit, value: Any, expected: set[str], label: str) -> None:
    audit.check(isinstance(value, dict), f"{label} must be an object")
    if isinstance(value, dict):
        audit.check(set(value) == expected, f"{label} keys differ")


def validate_references(audit: Audit, receipt: dict[str, Any]) -> dict[str, dict[str, Any]]:
    references = receipt.get("evidenceReceipts")
    audit.check(isinstance(references, list), "evidenceReceipts must be a list")
    if not isinstance(references, list):
        return {}
    observed: dict[str, dict[str, Any]] = {}
    actual_identity: list[tuple[Any, Any, Any]] = []
    for index, item in enumerate(references):
        exact_keys(audit, item, {"receiptId", "bead", "path", "sha256"}, f"evidenceReceipts[{index}]")
        if not isinstance(item, dict):
            continue
        identity = (item.get("receiptId"), item.get("bead"), item.get("path"))
        actual_identity.append(identity)
        path = item.get("path")
        digest = item.get("sha256")
        audit.check(isinstance(digest, str) and SHA256.fullmatch(digest) is not None, f"{path} needs an exact SHA-256")
        if isinstance(path, str) and isinstance(digest, str):
            audit.check(audit.digest(path) == digest, f"evidence digest mismatch for {path}")
            child = audit.json(path, f"evidence receipt {path}")
            audit.check(child.get("receiptId") == item.get("receiptId"), f"receipt ID mismatch for {path}")
            audit.check(child.get("bead") == item.get("bead"), f"bead mismatch for {path}")
            if isinstance(item.get("receiptId"), str):
                observed[item["receiptId"]] = child
    audit.check(actual_identity == EVIDENCE, "evidence receipt set or order changed")
    return observed


def validate_subjects(audit: Audit, receipt: dict[str, Any]) -> None:
    subjects = receipt.get("currentSubjects")
    exact_keys(audit, subjects, set(SUBJECTS), "currentSubjects")
    if not isinstance(subjects, dict):
        return
    for name, expected_path in SUBJECTS.items():
        item = subjects.get(name)
        exact_keys(audit, item, {"path", "sha256"}, f"currentSubjects.{name}")
        if not isinstance(item, dict):
            continue
        audit.check(item.get("path") == expected_path, f"current subject path changed for {name}")
        digest = item.get("sha256")
        audit.check(isinstance(digest, str) and digest == audit.digest(expected_path), f"current subject digest mismatch for {name}")


def validate_acceptance(audit: Audit, receipt: dict[str, Any], children: dict[str, dict[str, Any]]) -> None:
    acceptance = receipt.get("acceptance")
    exact_keys(
        audit,
        acceptance,
        {
            "semanticPlan",
            "stagedFullTree",
            "failClosedFilesystem",
            "transactionValidators",
            "interruptionRecovery",
            "manifestOnlyClean",
            "determinism",
            "inspectWhy",
        },
        "acceptance",
    )
    if not isinstance(acceptance, dict):
        return

    semantic = acceptance.get("semanticPlan", {})
    audit.check(semantic == {
        "schema": "wordpress-hx.semantic-plan.v1",
        "canonicalization": "wordpress-hx.canonical-json.v1",
        "directBuildCount": 2,
        "serverBuildCount": 2,
        "outcome": "passed",
    }, "semantic-plan acceptance changed")
    audit.check(nested(children.get("SDK-040-SEMANTIC-COLLECTOR", {}), "verification", "outcome") == "passed", "SDK-040 is not passing")
    audit.check(nested(children.get("ADR-006-SEMANTIC-PLAN-CONTRACT", {}), "contract", "planSchema") == semantic.get("schema"), "ADR-006 plan schema mismatch")

    staged = acceptance.get("stagedFullTree", {})
    audit.check(staged == {
        "transactionProtocol": "wordpress-hx.ownership-transaction.v1",
        "directVsReplayGeneratedTree": "byte-identical",
        "incompleteAndExtraStageRejected": True,
        "outcome": "passed",
    }, "staged full-tree acceptance changed")

    filesystem = acceptance.get("failClosedFilesystem", {})
    audit.check(filesystem.get("requiredScenarios") == SCENARIOS, "fail-closed filesystem scenario set changed")
    audit.check(filesystem.get("negativeInvocationCount") == 26, "ownership negative invocation count changed")
    audit.check(filesystem.get("outcome") == "passed", "fail-closed filesystem outcome is not passed")
    sdk041 = children.get("SDK-041-OWNERSHIP-TRANSACTION", {})
    audit.check(nested(sdk041, "verification", "negativeInvocationCount") == 26, "SDK-041 negative corpus changed")
    audit.check(nested(sdk041, "verification", "outcome") == "passed", "SDK-041 is not passing")

    validators = acceptance.get("transactionValidators", {})
    audit.check(validators == {
        "qualityTools": [
            "php-syntax-lint",
            "formatter-stability",
            "WordPress-Coding-Standards",
            "PHPCompatibility",
            "PHPStan",
        ],
        "qualityExecutionBeforePublication": True,
        "exactStageContentBinding": True,
        "failedQualityPublicationCount": 0,
        "outcome": "passed",
    }, "transaction-validator acceptance changed")
    sdk026 = children.get("SDK-026-GENERATED-PHP-QUALITY", {})
    audit.check(nested(sdk026, "claims", "lintFormatWpcsCompatibilityStaticAnalysis") == "hosted-runtime-tested", "SDK-026 quality tools are not hosted-runtime-tested")
    audit.check(nested(sdk026, "claims", "failClosedBeforePublication") == "hosted-negative-tested", "SDK-026 fail-closed publication proof changed")

    recovery = acceptance.get("interruptionRecovery", {})
    audit.check(recovery == {
        "crashCheckpointCount": 13,
        "recoveryModes": ["finalize-complete-next", "rollback-partial"],
        "outcome": "passed",
    }, "interruption-recovery acceptance changed")
    audit.check(nested(sdk041, "verification", "crashCheckpointCount") == 13, "SDK-041 crash corpus changed")

    clean = acceptance.get("manifestOnlyClean", {})
    audit.check(clean == {
        "cleanPreservesUnowned": True,
        "modifiedOwnedFileRejected": True,
        "nameOrCommentInference": False,
        "outcome": "passed",
    }, "manifest-only clean acceptance changed")

    determinism = acceptance.get("determinism", {})
    audit.check(determinism == {
        "freshRootCount": 2,
        "ownedGenerationReplay": "byte-identical",
        "manifestReplay": "byte-identical",
        "unsignedArchiveReplay": "byte-identical",
        "outcome": "passed",
    }, "determinism acceptance changed")
    sdk042 = children.get("SDK-042-DETERMINISTIC-BUILD", {})
    for key in ("freshRootCount", "ownedGenerationReplay", "manifestReplay", "unsignedArchiveReplay"):
        audit.check(nested(sdk042, "verification", key) == determinism.get(key), f"SDK-042 {key} mismatch")

    inspect = acceptance.get("inspectWhy", {})
    audit.check(inspect == {
        "fixtureArtifactCount": 3,
        "everyFixtureArtifact": "passed",
        "manifestAndContentBinding": "passed",
        "legacyProvenanceFormPreserved": True,
        "outcome": "passed",
    }, "inspect --why acceptance changed")
    implementation = audit.json("manifests/project-cli-implementation.json", "project CLI implementation")
    audit.check(nested(implementation, "commandSurface", "inspectOptions") == ["--why <generated-path>"], "inspect --why is absent from the CLI manifest")
    audit.check(nested(implementation, "g3ClosureReverification", "fixtureArtifactCount") == 3, "fixture-wide provenance proof changed")
    audit.check(nested(implementation, "g3ClosureReverification", "inspectWhyEveryFixtureArtifact") == "passed", "fixture-wide provenance is not passing")


def validate_status(audit: Audit, receipt: dict[str, Any], template: bool) -> None:
    implementation = receipt.get("implementation")
    hosted = receipt.get("hostedWorkflow")
    boundary = receipt.get("claimBoundary")
    exact_keys(audit, implementation, {"commit"}, "implementation")
    exact_keys(audit, hosted, {"workflow", "runId", "commit", "status", "jobCount", "allJobsPassed", "jobs"}, "hostedWorkflow")
    exact_keys(
        audit,
        boundary,
        {
            "g3SemanticPlanAndOwnership",
            "wordpressRuntimeCompatibility",
            "nextjsRuntimeCompatibility",
            "publicPackagePublication",
            "productionSupport",
        },
        "claimBoundary",
    )
    if not isinstance(implementation, dict) or not isinstance(hosted, dict) or not isinstance(boundary, dict):
        return
    audit.check(hosted.get("workflow") == "Repository bootstrap", "hosted workflow changed")
    jobs = hosted.get("jobs")
    exact_keys(audit, jobs, {"repository", "semantic-plan", "haxe"}, "hostedWorkflow.jobs")
    audit.check(boundary.get("wordpressRuntimeCompatibility") == "not-claimed-by-g3", "G3 overclaims WordPress runtime")
    audit.check(boundary.get("nextjsRuntimeCompatibility") == "not-claimed-by-g3", "G3 overclaims Next.js runtime")
    audit.check(boundary.get("publicPackagePublication") == "blocked", "G3 bypasses publication policy")
    audit.check(boundary.get("productionSupport") == "not-tested", "G3 overclaims production support")

    if template:
        audit.check(receipt.get("status") == "pending-hosted-proof", "template status must be pending-hosted-proof")
        audit.check(implementation.get("commit") is None, "template implementation commit must be null")
        audit.check(hosted.get("status") == "pending", "template hosted status must be pending")
        for key in ("runId", "commit", "jobCount", "allJobsPassed"):
            audit.check(hosted.get(key) is None, f"template hosted {key} must be null")
        audit.check(isinstance(jobs, dict) and all(value is None for value in jobs.values()), "template job IDs must be null")
        audit.check(boundary.get("g3SemanticPlanAndOwnership") == "pending-hosted-proof", "template gate claim must be pending")
        return

    audit.check(receipt.get("status") == "verified", "final receipt status must be verified")
    commit = implementation.get("commit")
    audit.check(isinstance(commit, str) and SHA1.fullmatch(commit) is not None, "final receipt needs an exact implementation commit")
    audit.check(hosted.get("status") == "passed", "final hosted status must be passed")
    audit.check(hosted.get("commit") == commit, "hosted commit must equal implementation commit")
    audit.check(isinstance(hosted.get("runId"), int) and hosted["runId"] > 0, "final receipt needs a hosted run ID")
    audit.check(hosted.get("jobCount") == 13, "hosted job count must be 13")
    audit.check(hosted.get("allJobsPassed") is True, "all hosted jobs must pass")
    audit.check(isinstance(jobs, dict) and all(isinstance(value, int) and value > 0 for value in jobs.values()), "final receipt needs exact required job IDs")
    audit.check(boundary.get("g3SemanticPlanAndOwnership") == "verified", "final G3 claim must be verified")
    if isinstance(commit, str) and SHA1.fullmatch(commit):
        shallow = subprocess.run(
            ["git", "rev-parse", "--is-shallow-repository"],
            cwd=audit.root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        audit.check(shallow.returncode == 0, "cannot inspect repository history depth")
        if shallow.returncode == 0 and shallow.stdout.strip() != "true":
            result = subprocess.run(
                ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
                cwd=audit.root,
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            audit.check(result.returncode == 0, "implementation commit is absent from repository history")


def validate(root: Path, receipt_path: Path, template: bool) -> list[str]:
    audit = Audit(root)
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"cannot read G3 receipt: {error}"]
    if not isinstance(receipt, dict):
        return ["G3 receipt must be an object"]
    exact_keys(
        audit,
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "bead",
            "status",
            "gateContract",
            "evidenceReceipts",
            "currentSubjects",
            "acceptance",
            "localVerification",
            "implementation",
            "hostedWorkflow",
            "claimBoundary",
        },
        "G3 receipt",
    )
    audit.check(receipt.get("schemaVersion") == 1, "schemaVersion must be 1")
    audit.check(receipt.get("receiptId") == "G3-SEMANTIC-PLAN-FAIL-CLOSED-OWNERSHIP", "receiptId changed")
    audit.check(receipt.get("bead") == "wordpresshx-g3", "bead changed")
    contract = receipt.get("gateContract")
    exact_keys(audit, contract, {"path", "sha256", "section"}, "gateContract")
    if isinstance(contract, dict):
        audit.check(contract.get("path") == "wordpress-hx-sdk-product-requirements.md", "gate contract path changed")
        audit.check(contract.get("sha256") == audit.digest("wordpress-hx-sdk-product-requirements.md"), "gate contract digest mismatch")
        audit.check(contract.get("section") == "Gate G3 — Semantic plan and fail-closed ownership", "gate section changed")
        try:
            prd = (root / "wordpress-hx-sdk-product-requirements.md").read_text(encoding="utf-8")
        except OSError:
            prd = ""
        audit.check("## Gate G3 — Semantic plan and fail-closed ownership" in prd, "G3 section is absent from the PRD")
    children = validate_references(audit, receipt)
    validate_subjects(audit, receipt)
    validate_acceptance(audit, receipt, children)
    local = receipt.get("localVerification")
    exact_keys(audit, local, {"commands", "outcome"}, "localVerification")
    if isinstance(local, dict):
        audit.check(local.get("commands") == [
            "bash scripts/semantic-collector/test.sh",
            "bash scripts/ownership/test.sh",
            "bash scripts/determinism/test-production.sh",
            "bash scripts/project-cli/test-production.sh",
            "bash scripts/php-quality/test-production.sh",
            "bash scripts/scaffold/test-production.sh",
            "bash scripts/check-repository.sh",
        ], "local verification command set changed")
        audit.check(local.get("outcome") == "passed", "local verification outcome is not passed")
    validate_status(audit, receipt, template)
    return audit.errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--template", action="store_true")
    arguments = parser.parse_args()
    root = arguments.root.resolve()
    receipt_path = arguments.receipt
    if not receipt_path.is_absolute():
        receipt_path = root / receipt_path
    errors = validate(root, receipt_path, arguments.template)
    if errors:
        for error in errors:
            print(f"G3 closure error: {error}", file=sys.stderr)
        return 1
    print("G3 semantic-plan and fail-closed ownership receipt passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
