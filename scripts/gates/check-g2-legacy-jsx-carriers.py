#!/usr/bin/env python3
"""Verify the bounded Genes 1.36 JSX carrier decision and migration owner."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = (
    ROOT / "manifests/evidence/g2.1-legacy-jsx-marker-temporaries.json"
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    receipt = load_json(RECEIPT_PATH)
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "G2.1-LEGACY-JSX-MARKER-TEMPORARIES"
    assert receipt["bead"] == "wordpresshx-g2.1"
    assert receipt["status"] == "verified-bounded-generated-legacy-inventory"
    assert receipt["profileId"] == "wp70-release"

    for subject in receipt["subjects"].values():
        path = ROOT / subject["path"]
        assert path.is_file(), f"missing G2.1 subject: {path}"
        assert sha256(path) == subject["sha256"], f"stale G2.1 subject: {path}"

    compiler = load_json(
        ROOT / receipt["subjects"]["dependencyLock"]["path"]
    )["compiler"]
    current = receipt["currentCompiler"]
    for field in ("name", "version", "tag", "commit", "tree"):
        assert compiler[field] == current[field]
    assert current["markerBoundary"] == {
        "tag": "Dynamic",
        "props": "Array<Dynamic>",
        "children": "Array<Dynamic>",
    }

    inventory = receipt["generatedWeakInventory"]
    assert inventory["public"] == []
    assert inventory["internal"] == [
        "Main.App:tmp:any[]",
        "Main.ProofCheckRow:tmp1:any[]",
        "Main.ProofCheckRow:tmp:any[]",
    ]
    assert inventory["exactCount"] == len(inventory["internal"]) == 3
    assert inventory["authoredHaxeWeakTypesAdded"] == 0

    verifier = (
        ROOT / receipt["subjects"]["liveVerifier"]["path"]
    ).read_text(encoding="utf-8")
    for item in inventory["internal"]:
        assert f'"{item}"' in verifier
    assert "assert.deepEqual(publicWeakTypes, []" in verifier

    reason = receipt["compilerReason"]
    assert reason["classification"] == "legacy-generic-jsx-marker-protocol"
    assert reason["annotationRemovalSafe"] is False
    assert reason["initializerInliningSafe"] is False
    assert reason["wordpressSpecificCompilerPatchAllowed"] is False

    upstream = receipt["generalizedUpstreamResolution"]
    assert upstream["pullRequest"]["number"] == 10
    assert upstream["pullRequest"]["hostedChecksPassed"] is True
    assert upstream["pullRequest"]["wordpressSymbolsInCompilerOrFixtures"] is False
    assert upstream["protocol"] == "generic-linked-prop-and-child-carriers"
    assert upstream["firstRelease"]["version"] == "1.37.0"
    assert upstream["verifiedCandidateRelease"]["version"] == "1.37.1"

    decision = receipt["decision"]
    assert decision == {
        "legacyInventoryRetained": True,
        "newGenesPatchRequired": False,
        "currentGenesPinChanged": False,
        "migrationOwner": "wordpresshx-g2.5",
        "migrationScope": (
            "adapter plus repository-wide compiler provenance and regression "
            "receipts"
        ),
    }
    print(
        "G2.1 legacy JSX carrier gate passed: "
        "3 generated-only any[] locals, zero public weak types"
    )


if __name__ == "__main__":
    main()
