#!/usr/bin/env python3
"""Pure local-evidence state rules for the bounded ADR-015 gate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


OBSERVER_IDS = ("schema", "native", "haxe", "mutation", "ownership")


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_identity(root: Path, paths: tuple[str, ...]) -> str:
    material = [
        {"path": relative, "sha256": sha256((root / relative).read_bytes())}
        for relative in sorted(paths)
    ]
    return sha256(canonical(material))


def current_content_root(root: Path) -> str:
    bundle = json.loads(
        (
            root
            / "fixtures/adoption-contract/contract/acme-calendar.bundle.json"
        ).read_text(encoding="utf-8")
    )
    value = bundle.get("bundleDigest")
    if not isinstance(value, str) or len(value) != 64:
        raise ValueError("ADR-015 content bundle omits its digest")
    return value


def observer_identities(root: Path) -> dict[str, str]:
    return {
        "schema": file_identity(
            root,
            (
                "schemas/adoption-contract.schema.json",
                "schemas/adoption-capability.schema.json",
                "schemas/adoption-review.schema.json",
                "schemas/adoption-bundle.schema.json",
                "scripts/adoption/test-json-schema.cjs",
            ),
        ),
        "native": file_identity(
            root,
            (
                "scripts/adoption/test-native-provider.py",
                "scripts/adoption/generate-fixture.py",
                "scripts/adoption/abi_model.py",
            ),
        ),
        "haxe": file_identity(
            root,
            tuple(
                path.relative_to(root).as_posix()
                for source in (
                    root / "fixtures/adoption-contract/src",
                    root / "fixtures/adoption-contract/test-support",
                    root / "fixtures/adoption-contract/test",
                    root / "fixtures/adoption-contract/test-native",
                    root / "fixtures/adoption-contract/test-negative",
                    root / "fixtures/adoption-contract/test-ownership",
                )
                if source.exists()
                for path in source.rglob("*.hx")
            )
            + (
                "packages/cli/dependency-lock.json",
                "packages/gutenberg/build-tooling/package-lock.json",
                "manifests/toolchain.lock.json",
            ),
        ),
        "mutation": file_identity(
            root,
            (
                "scripts/adoption/validate-architecture.py",
                "scripts/adoption/abi_model.py",
                "scripts/adoption/evidence_state.py",
                "scripts/adoption/record-evidence.py",
                "scripts/adoption/refresh-evidence.py",
                "scripts/adoption/test-evidence.py",
                "scripts/adoption/test.sh",
            ),
        ),
        "ownership": file_identity(
            root,
            (
                "packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx",
                "fixtures/adoption-contract/test-ownership/adoption/ownership/AdoptionBundleValidator.hx",
                "fixtures/adoption-contract/test-ownership/adoption/ownership/Main.hx",
                "scripts/adoption/test-ownership.py",
            ),
        ),
    }


def hosted_gate_identity(root: Path) -> str:
    """Bind a hosted pass to the content root and every local observer implementation."""

    return sha256(
        canonical(
            {
                "contentRoot": current_content_root(root),
                "observers": observer_identities(root),
                "workflowSha256": sha256(
                    (root / ".github/workflows/adoption-contract.yml").read_bytes()
                ),
                "gateSha256": sha256(
                    (root / "scripts/adoption/test.sh").read_bytes()
                ),
            }
        )
    )


def pending_local_state(
    root: Path, execution_mode: str = "local"
) -> dict[str, object]:
    if execution_mode not in ("local", "container"):
        raise ValueError("ADR-015 execution mode must be local or container")
    identities = observer_identities(root)
    return {
        "contentRoot": current_content_root(root),
        "executionMode": execution_mode,
        "outcome": "pending",
        "observedAt": None,
        "observers": [
            {
                "id": observer_id,
                "identitySha256": identities[observer_id],
                "outcome": "pending",
            }
            for observer_id in OBSERVER_IDS
        ],
    }


def refresh_local_state(
    root: Path,
    existing: object,
    *,
    reset_stale_pass: bool,
    execution_mode: str = "local",
) -> dict[str, object]:
    pending = pending_local_state(root, execution_mode)
    if not isinstance(existing, dict) or existing.get("outcome") != "passed":
        return pending
    expected_observers = [
        {
            "id": value["id"],
            "identitySha256": value["identitySha256"],
            "outcome": "passed",
        }
        for value in pending["observers"]
    ]
    same_identity = (
        existing.get("contentRoot") == pending["contentRoot"]
        and existing.get("executionMode") == pending["executionMode"]
        and existing.get("observers") == expected_observers
    )
    if same_identity:
        return existing
    if not reset_stale_pass:
        raise ValueError("identity refresh refuses to retain a stale ADR-015 local pass")
    return pending


def record_local_pass(
    root: Path,
    observer_record: object,
    execution_mode: str = "local",
) -> dict[str, object]:
    if not isinstance(observer_record, dict):
        raise ValueError("local observer record must be an object")
    expected = pending_local_state(root, execution_mode)
    if observer_record.get("contentRoot") != expected["contentRoot"]:
        raise ValueError("local observers did not use the current content root")
    if observer_record.get("executionMode") != execution_mode:
        raise ValueError("local observers used a different PHP execution mode")
    observed_at = observer_record.get("observedAt")
    if not isinstance(observed_at, str) or not observed_at.endswith("Z"):
        raise ValueError("local observers need one UTC observation timestamp")
    raw_observers = observer_record.get("observers")
    if not isinstance(raw_observers, list):
        raise ValueError("local observer outcomes must be an array")
    expected_observers = [
        {
            "id": value["id"],
            "identitySha256": value["identitySha256"],
            "outcome": "passed",
        }
        for value in expected["observers"]
    ]
    if raw_observers != expected_observers:
        raise ValueError("local pass requires every exact observer identity and outcome")
    return {
        "contentRoot": expected["contentRoot"],
        "executionMode": execution_mode,
        "outcome": "passed",
        "observedAt": observed_at,
        "observers": expected_observers,
    }
