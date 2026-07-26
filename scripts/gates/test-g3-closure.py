#!/usr/bin/env python3
"""Exercise the G3 closure validator and representative fail-closed mutations."""

from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/gates/check-g3-closure.py"
RECEIPT = ROOT / "manifests/evidence/g3-semantic-ownership.json"


def run(receipt: dict[str, object]) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="wordpresshx-g3-receipt-") as temporary:
        path = Path(temporary) / "receipt.json"
        path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        return subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "--root",
                str(ROOT),
                "--receipt",
                str(path),
                "--template",
            ],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )


def negative(
    baseline: dict[str, object],
    name: str,
    mutate: Callable[[dict[str, object]], None],
    diagnostic: str,
) -> None:
    candidate = copy.deepcopy(baseline)
    mutate(candidate)
    result = run(candidate)
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator unexpectedly passed")
    if diagnostic not in result.stderr:
        raise AssertionError(f"{name}: missing {diagnostic!r}\n{result.stderr}")


def main() -> int:
    baseline = json.loads(RECEIPT.read_text(encoding="utf-8"))
    baseline["status"] = "pending-hosted-proof"
    baseline["implementation"]["commit"] = None
    baseline["hostedWorkflow"] = {
        "workflow": "Repository bootstrap",
        "runId": None,
        "commit": None,
        "status": "pending",
        "jobCount": None,
        "allJobsPassed": None,
        "jobs": {
            "repository": None,
            "semantic-plan": None,
            "haxe": None,
        },
    }
    baseline["claimBoundary"]["g3SemanticPlanAndOwnership"] = (
        "pending-hosted-proof"
    )
    positive = run(baseline)
    if positive.returncode != 0:
        raise AssertionError(f"positive G3 template validation failed\n{positive.stderr}")

    negative(
        baseline,
        "evidence-digest",
        lambda value: value["evidenceReceipts"][0].__setitem__("sha256", "0" * 64),
        "evidence digest mismatch",
    )
    negative(
        baseline,
        "subject-digest",
        lambda value: value["currentSubjects"]["cliArguments"].__setitem__("sha256", "0" * 64),
        "current subject digest mismatch",
    )
    negative(
        baseline,
        "missing-path-scenario",
        lambda value: value["acceptance"]["failClosedFilesystem"]["requiredScenarios"].remove("path-traversal"),
        "filesystem scenario set changed",
    )
    negative(
        baseline,
        "partial-stage",
        lambda value: value["acceptance"]["stagedFullTree"].__setitem__("incompleteAndExtraStageRejected", False),
        "staged full-tree acceptance changed",
    )
    negative(
        baseline,
        "quality-publication",
        lambda value: value["acceptance"]["transactionValidators"].__setitem__("failedQualityPublicationCount", 1),
        "transaction-validator acceptance changed",
    )
    negative(
        baseline,
        "recovery-coverage",
        lambda value: value["acceptance"]["interruptionRecovery"].__setitem__("crashCheckpointCount", 1),
        "interruption-recovery acceptance changed",
    )
    negative(
        baseline,
        "name-inference",
        lambda value: value["acceptance"]["manifestOnlyClean"].__setitem__("nameOrCommentInference", True),
        "manifest-only clean acceptance changed",
    )
    negative(
        baseline,
        "archive-drift",
        lambda value: value["acceptance"]["determinism"].__setitem__("unsignedArchiveReplay", "different"),
        "determinism acceptance changed",
    )
    negative(
        baseline,
        "partial-provenance",
        lambda value: value["acceptance"]["inspectWhy"].__setitem__("fixtureArtifactCount", 1),
        "inspect --why acceptance changed",
    )
    negative(
        baseline,
        "wordpress-overclaim",
        lambda value: value["claimBoundary"].__setitem__("wordpressRuntimeCompatibility", "verified"),
        "overclaims WordPress runtime",
    )
    negative(
        baseline,
        "publication-bypass",
        lambda value: value["claimBoundary"].__setitem__("publicPackagePublication", "authorized"),
        "bypasses publication policy",
    )
    negative(
        baseline,
        "invented-hosted-proof",
        lambda value: value.__setitem__("status", "verified"),
        "template status must be pending-hosted-proof",
    )

    print("G3 closure tests passed: 1 positive and 12 fail-closed mutations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
