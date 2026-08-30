#!/usr/bin/env python3
"""Record a local ADR-015 pass only from one complete observer record."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from evidence_state import evidence_subject_sha256, record_local_pass


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = ROOT / "manifests/evidence/adr-015-interop-adoption-contract.json"


def pretty(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--observers", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--mode", choices=("local", "container"), default="local")
    arguments = parser.parse_args()
    if arguments.output is not None and arguments.write:
        raise SystemExit("choose --output or --write")
    observer_record = json.loads(arguments.observers.read_text(encoding="utf-8"))
    receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))
    key = "localObservation" if arguments.mode == "local" else "containerObservation"
    receipt[key] = record_local_pass(ROOT, observer_record, arguments.mode)
    complete = all(
        isinstance(receipt.get(observation_key), dict)
        and receipt[observation_key].get("outcome") == "passed"
        and receipt[observation_key].get("evidenceSubjectSha256")
        == evidence_subject_sha256(ROOT)
        for observation_key in ("localObservation", "containerObservation")
    )
    verification = receipt["verification"]
    verification["outcome"] = (
        "passed-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    claims = receipt["claims"]
    claims["typedCapabilityPrototype"] = (
        "compile-tested-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    claims["noProviderExecution"] = (
        "static-generation-tested-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    claims["fixtureGenerator"] = (
        "deterministic-source-derived-tested-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    claims["nativeProviderAbi"] = (
        "synthetic-provider-tested-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    claims["ownershipTransaction"] = (
        "production-owner-tested-local-and-container-current-evidence-subject"
        if complete
        else "pending-current-observers"
    )
    encoded = pretty(receipt)
    if arguments.write:
        RECEIPT_PATH.write_bytes(encoded)
        print(
            f"ADR-015 {arguments.mode} observer outcome recorded; "
            "hosted and review state unchanged"
        )
    elif arguments.output is not None:
        arguments.output.write_bytes(encoded)
        print("ADR-015 local observer outcome validated and staged")
    else:
        raise SystemExit("choose --output or --write")


if __name__ == "__main__":
    main()
