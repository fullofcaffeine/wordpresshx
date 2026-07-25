#!/usr/bin/env python3
"""Verify the exact-provider optional-property compatibility decision."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = (
    ROOT / "manifests/evidence/g2.2-provider-exact-optional-compatibility.json"
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    receipt = load_json(RECEIPT_PATH)
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "G2.2-PROVIDER-EXACT-OPTIONAL-COMPATIBILITY"
    assert receipt["bead"] == "wordpresshx-g2.2"
    assert receipt["status"] == "verified-precise-provider-limitation"
    assert receipt["profileId"] == "wp70-release"

    for subject in receipt["subjects"].values():
        path = ROOT / subject["path"]
        assert path.is_file(), f"missing G2.2 subject: {path}"
        assert sha256(path) == subject["sha256"], f"stale G2.2 subject: {path}"

    manifest = load_json(ROOT / receipt["subjects"]["manifest"]["path"])
    lock = load_json(ROOT / receipt["subjects"]["lock"]["path"])
    profile = load_json(ROOT / receipt["subjects"]["profile"]["path"])
    exact_provider = receipt["exactProvider"]
    assert manifest["devDependencies"]["@wordpress/components"] == (
        exact_provider["wordpressComponents"]
    )
    assert manifest["overrides"]["@ariakit/react"] == exact_provider[
        "ariakitReact"
    ]
    assert lock["packages"]["node_modules/@ariakit/core"]["version"] == (
        exact_provider["ariakitCore"]
    )
    assert lock["packages"]["node_modules/@ariakit/react-core"]["version"] == (
        exact_provider["ariakitReactCore"]
    )
    assert profile["provider"]["gutenbergCommit"] == exact_provider[
        "gutenbergCommit"
    ]

    diagnostics = load_json(ROOT / receipt["subjects"]["diagnostics"]["path"])
    reproduction = receipt["providerOnlyReproduction"]
    assert len(diagnostics) == reproduction["exactOptionalDiagnosticCount"] == 26
    assert Counter(item["code"] for item in diagnostics) == Counter(
        {2430: 25, 2344: 1}
    )
    assert Counter(item["file"].split("/", 1)[0] for item in diagnostics) == {
        "@ariakit": 26
    }
    assert Counter(
        "/".join(item["file"].split("/", 2)[:2]) for item in diagnostics
    ) == {
        "@ariakit/core": 4,
        "@ariakit/react-core": 22,
    }
    assert all(item["line"] > 0 and item["character"] > 0 for item in diagnostics)
    assert reproduction["baseline"]["skipLibCheck"] is False
    assert reproduction["baseline"]["exactOptionalPropertyTypes"] is False
    assert reproduction["baseline"]["diagnosticCount"] == 0
    assert reproduction["probe"]["skipLibCheck"] is False
    assert reproduction["probe"]["exactOptionalPropertyTypes"] is True

    lanes = receipt["admittedLanes"]
    assert lanes["generatedSource"] == {
        "exactOptionalPropertyTypes": True,
        "skipLibCheck": True,
    }
    assert lanes["completeProviderDeclarations"] == {
        "exactOptionalPropertyTypes": False,
        "skipLibCheck": False,
    }
    assert receipt["classification"]["owner"] == (
        "exact-provider-ariakit-declarations"
    )
    assert receipt["classification"]["wordpressHxGeneratorOwned"] is False
    assert receipt["decision"]["nodeModulesPatched"] is False
    assert receipt["decision"]["normalizedDeclarationsPublished"] is False
    assert receipt["decision"]["providerDiagnosticsSuppressed"] is False

    candidate = receipt["newerAriakitCandidate"]
    assert candidate["version"] == "0.4.35"
    assert candidate["outcome"] == "rejected-incompatible-and-not-corrective"
    assert candidate["diagnosticCount"] > reproduction[
        "exactOptionalDiagnosticCount"
    ]
    print(
        "G2.2 provider exact-optional gate passed: "
        "26 precise Ariakit diagnostics, zero suppressed provider diagnostics"
    )


if __name__ == "__main__":
    main()
