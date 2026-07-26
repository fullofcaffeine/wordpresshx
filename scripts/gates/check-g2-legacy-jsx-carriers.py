#!/usr/bin/env python3
"""Verify the historical Genes 1.36 inventory and its G2.5 replacement."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = (
    ROOT / "manifests/evidence/g2.1-legacy-jsx-marker-temporaries.json"
)
ADOPTION_RECEIPT_PATH = (
    ROOT / "manifests/evidence/g2.5-typed-linked-jsx-carrier-adoption.json"
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
        assert len(subject["sha256"]) == 64

    historical = receipt["currentCompiler"]
    assert historical["markerBoundary"] == {
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

    adoption = load_json(ADOPTION_RECEIPT_PATH)
    assert adoption["schemaVersion"] == 1
    assert adoption["receiptId"] == "G2.5-TYPED-LINKED-JSX-CARRIER-ADOPTION"
    assert adoption["status"] in {"implemented-hosted-pending", "verified"}
    for subject in adoption["subjects"].values():
        path = ROOT / subject["path"]
        assert path.is_file(), f"missing G2.5 subject: {path}"
        assert sha256(path) == subject["sha256"], f"stale G2.5 subject: {path}"

    previous = adoption["previousCompiler"]
    for field in ("name", "version", "tag", "commit", "tree"):
        assert previous[field] == historical[field]
    compiler = load_json(
        ROOT / adoption["subjects"]["gutenbergDependencyLock"]["path"]
    )["compiler"]
    adopted = adoption["adoptedCompiler"]
    for field in ("name", "version", "tag", "commit", "tree"):
        assert compiler[field] == adopted[field]
    assert compiler["releaseArtifact"] == adopted["releaseArtifact"]

    protocol = adoption["genericProtocol"]
    assert protocol["legacyArrayMarkersRemoved"] is True
    assert protocol["propAndChildEvaluationOrderPreserved"] is True
    assert protocol["wordpressSymbolsInProtocol"] is False
    lowerer = (
        ROOT / adoption["subjects"]["browserHxxLowerer"]["path"]
    ).read_text(encoding="utf-8")
    for carrier in protocol["adapterCarriers"]:
        assert carrier in lowerer
    assert "Array<Dynamic>" not in lowerer

    strict_types = adoption["localVerification"]["strictTypes"]
    assert strict_types["publicWeakTypes"] == []
    assert strict_types["internalWeakInventory"] == []
    assert strict_types["forbiddenAuthoredHaxeTypes"] == []
    print(
        "G2.1/G2.5 JSX carrier gate passed: historical three-local inventory "
        "replaced by typed linked carriers with zero weak generated types"
    )


if __name__ == "__main__":
    main()
