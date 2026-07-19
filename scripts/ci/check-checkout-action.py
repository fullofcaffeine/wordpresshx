#!/usr/bin/env python3
"""Validate the immutable Node 24 checkout action upgrade and its evidence."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_PATH = ROOT / ".github/workflows/repository.yml"
RECEIPT_PATH = ROOT / "manifests/evidence/ci-checkout-node24.json"
COMPONENTS_PATH = ROOT / "LICENSES/components.json"
PIN = "9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0"
TREE = "2ddbcfc53840ba99a608fb2a72dd13c3ea7cb8dc"
VERSION = "7.0.0"
LICENSE_BLOB = "a67dca8b4f65d6bd351f6b1e333ce2cd84d843a5"
SHA1 = re.compile(r"[0-9a-f]{40}")


def exact_keys(value: Any, expected: set[str], context: str) -> None:
    assert isinstance(value, dict), f"{context} must be an object"
    assert set(value) == expected, (
        f"{context} keys differ: expected {sorted(expected)}, found {sorted(value)}"
    )


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
    receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))
    inventory = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))

    checkout_lines = re.findall(
        r"^\s+uses:\s+actions/checkout@([^\s]+)\s+#\s+v([^\s]+)\s*$",
        workflow,
        re.MULTILINE,
    )
    assert len(checkout_lines) == 11
    assert checkout_lines == [(PIN, VERSION)] * 11
    assert workflow.count("fetch-depth: 0") == 1
    assert re.search(
        r"(?ms)^  security:\n.*?uses: actions/checkout@[^\n]+\n\s+with:\n\s+fetch-depth: 0",
        workflow,
    )
    assert "allow-unsafe-pr-checkout" not in workflow

    component = next(
        item for item in inventory["components"] if item["id"] == "actions-checkout-7.0.0"
    )
    assert component["version"] == VERSION
    assert component["commit"] == PIN
    assert component["tree"] == TREE
    assert component["declaredLicense"] == "MIT"
    assert component["licenseEvidence"][0]["blob"] == LICENSE_BLOB

    exact_keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "bead",
            "status",
            "source",
            "subject",
            "historicalVerification",
            "change",
            "localVerification",
            "implementation",
            "hostedWorkflow",
            "claims",
            "limitations",
        },
        "checkout receipt",
    )
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "CI-CHECKOUT-NODE24"
    assert receipt["bead"] == "wordpresshx-88h"
    assert receipt["status"] in {"implemented-hosted-pending", "verified"}

    source = receipt["source"]
    exact_keys(
        source,
        {
            "repository",
            "release",
            "publishedAt",
            "releaseUrl",
            "tagObjectType",
            "commit",
            "tree",
            "commitSignatureVerified",
            "packageVersion",
            "packageLicense",
            "packageNodeEngine",
            "actionRuntime",
            "licenseBlob",
        },
        "checkout receipt source",
    )
    assert source == {
        "repository": "https://github.com/actions/checkout",
        "release": "v7.0.0",
        "publishedAt": "2026-06-18T13:53:05Z",
        "releaseUrl": "https://github.com/actions/checkout/releases/tag/v7.0.0",
        "tagObjectType": "commit",
        "commit": PIN,
        "tree": TREE,
        "commitSignatureVerified": True,
        "packageVersion": VERSION,
        "packageLicense": "MIT",
        "packageNodeEngine": ">=24",
        "actionRuntime": "node24",
        "licenseBlob": LICENSE_BLOB,
    }

    subjects = receipt["subject"]
    exact_keys(subjects, {"validator", "workflow"}, "checkout receipt subject")
    subject_records = sorted(subjects.items(), key=lambda item: item[1]["path"])
    material = bytearray()
    historical = receipt["historicalVerification"]
    exact_keys(
        historical,
        {
            "algorithm",
            "subjectCommit",
            "subjectContentSha256",
            "depthOneFallback",
        },
        "checkout historical verification",
    )
    assert historical["algorithm"] == (
        "sha256-lines-of-sha256-two-spaces-path-lf-v1"
    )
    assert SHA1.fullmatch(historical["subjectCommit"])
    assert historical["depthOneFallback"] == (
        "self-contained-subject-digest-inventory"
    )
    historical_available = (
        subprocess.run(
            [
                "git",
                "cat-file",
                "-e",
                f"{historical['subjectCommit']}^{{commit}}",
            ],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )
    for name, subject in subject_records:
        exact_keys(subject, {"path", "sha256"}, f"checkout receipt subject {name}")
        material.extend(f"{subject['sha256']}  {subject['path']}\n".encode())
        subject_path = ROOT / subject["path"]
        if subject_path.is_file() and digest(subject_path) == subject["sha256"]:
            continue
        if historical_available:
            content = subprocess.run(
                [
                    "git",
                    "show",
                    f"{historical['subjectCommit']}:{subject['path']}",
                ],
                cwd=ROOT,
                check=True,
                capture_output=True,
            ).stdout
            assert hashlib.sha256(content).hexdigest() == subject["sha256"]
    assert hashlib.sha256(material).hexdigest() == (
        historical["subjectContentSha256"]
    )
    assert subjects["validator"]["path"] == "scripts/ci/check-checkout-action.py"
    assert subjects["workflow"]["path"] == ".github/workflows/repository.yml"

    change = receipt["change"]
    exact_keys(
        change,
        {
            "workflowUseCount",
            "fullCommitPins",
            "securityFetchDepth",
            "otherCheckoutFetchDepth",
            "unsafePullRequestOverrideEnabled",
        },
        "checkout receipt change",
    )
    assert change == {
        "workflowUseCount": 11,
        "fullCommitPins": True,
        "securityFetchDepth": 0,
        "otherCheckoutFetchDepth": "default-1",
        "unsafePullRequestOverrideEnabled": False,
    }

    local = receipt["localVerification"]
    exact_keys(local, {"commands", "outcome"}, "checkout receipt local verification")
    assert local["commands"] == [
        "bash scripts/ci/check-security-tooling.sh",
        "bash scripts/check-repository.sh",
        "bash scripts/hooks/test.sh",
    ]
    assert local["outcome"] == "passed"

    implementation = receipt["implementation"]
    exact_keys(implementation, {"baseCommit", "commit"}, "checkout receipt implementation")
    assert SHA1.fullmatch(implementation["baseCommit"])
    assert implementation["commit"] is None or SHA1.fullmatch(implementation["commit"])

    hosted = receipt["hostedWorkflow"]
    exact_keys(
        hosted,
        {
            "workflow",
            "runId",
            "commit",
            "status",
            "fullMatrixStatus",
            "jobCount",
            "checkoutNode20DeprecationWarningCount",
        },
        "checkout receipt hosted workflow",
    )
    assert hosted["workflow"] == "repository.yml"
    if receipt["status"] == "implemented-hosted-pending":
        assert implementation["commit"] is None
        assert hosted == {
            "workflow": "repository.yml",
            "runId": None,
            "commit": None,
            "status": "pending",
            "fullMatrixStatus": "pending",
            "jobCount": 11,
            "checkoutNode20DeprecationWarningCount": None,
        }
        expected_claims = {
            "checkoutActionRuntime": "inventoried",
            "warningRemoval": "not-tested",
            "sdkCompatibility": "not-tested",
            "productionSupport": "not-tested",
        }
    else:
        assert implementation["commit"] == hosted["commit"]
        assert isinstance(hosted["runId"], int) and hosted["runId"] > 0
        assert isinstance(hosted["commit"], str) and SHA1.fullmatch(hosted["commit"])
        assert hosted["status"] == "passed"
        assert hosted["fullMatrixStatus"] == "passed"
        assert hosted["jobCount"] == 11
        assert hosted["checkoutNode20DeprecationWarningCount"] == 0
        expected_claims = {
            "checkoutActionRuntime": "runtime-tested",
            "warningRemoval": "runtime-tested",
            "sdkCompatibility": "not-tested",
            "productionSupport": "not-tested",
        }
    exact_keys(
        receipt["claims"],
        {"checkoutActionRuntime", "warningRemoval", "sdkCompatibility", "productionSupport"},
        "checkout receipt claims",
    )
    assert receipt["claims"] == expected_claims
    assert receipt["limitations"] == [
        "github-hosted-ubuntu-24.04-only",
        "no-container-action-authentication-coverage",
        "no-sdk-or-generated-artifact-claim",
    ]

    print(
        f"checkout action policy passed: v{VERSION} at {PIN}, "
        f"hosted status {hosted['status']}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, KeyError, StopIteration, TypeError, ValueError) as error:
        print(f"checkout action policy failed: {error}", file=sys.stderr)
        raise SystemExit(1)
