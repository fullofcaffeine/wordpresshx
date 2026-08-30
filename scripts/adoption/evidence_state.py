#!/usr/bin/env python3
"""Pure local-evidence state rules for the bounded ADR-015 gate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


OBSERVER_IDS = ("schema", "native", "haxe", "mutation", "ownership")
# Decision records and evidence receipts report this subject; they do not define
# the executable contract and are excluded to avoid a self-invalidating cycle.
EVIDENCE_SUBJECT_STATIC_PATHS = (
    ".github/workflows/adoption-contract.yml",
    "fixtures/adoption-contract/expected/capability-plan.txt",
    "manifests/toolchain.lock.json",
    "packages/cli/.haxerc",
    "packages/cli/dependency-lock.json",
    "packages/cli/src/wordpresshx/cli/NodeGlobals.hx",
    "packages/cli/src/wordpresshx/cli/ownership/ArtifactOwner.hx",
    "packages/gutenberg/build-tooling/package-lock.json",
    "packages/gutenberg/build-tooling/package.json",
    "schemas/adoption-bundle.schema.json",
    "schemas/adoption-capability.schema.json",
    "schemas/adoption-contract.schema.json",
    "schemas/adoption-review.schema.json",
)


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


def evidence_subject_paths(root: Path) -> tuple[str, ...]:
    """Return the complete non-recursive ADR-015 evidence subject inventory."""

    paths = set(EVIDENCE_SUBJECT_STATIC_PATHS)
    trees = (
        (root / "fixtures/adoption-contract/inputs", None),
        (root / "fixtures/adoption-contract/contract", None),
        (root / "fixtures/adoption-contract/src", ".hx"),
        (root / "fixtures/adoption-contract/test-support", ".hx"),
        (root / "fixtures/adoption-contract/test", ".hx"),
        (root / "fixtures/adoption-contract/test-native", ".hx"),
        (root / "fixtures/adoption-contract/test-negative", ".hx"),
        (root / "fixtures/adoption-contract/test-ownership", ".hx"),
        (root / "scripts/adoption", (".py", ".cjs", ".sh")),
        (root / "packages/cli/haxe_libraries", ".hxml"),
        (root / "packages/cli/src/wordpresshx/cli/closedjson", ".hx"),
        (root / "packages/cli/src/wordpresshx/cli/ownership", ".hx"),
    )
    for directory, suffix in trees:
        if not directory.is_dir():
            raise ValueError(
                f"ADR-015 evidence subject directory is absent: {directory.relative_to(root)}"
            )
        for path in directory.rglob("*"):
            if path.is_file() and (
                suffix is None
                or (isinstance(suffix, str) and path.suffix == suffix)
                or (isinstance(suffix, tuple) and path.suffix in suffix)
            ):
                paths.add(path.relative_to(root).as_posix())
    forbidden = {
        "manifests/adoption-contract-architecture.json",
        "manifests/evidence/adr-015-interop-adoption-contract.json",
    }
    if paths & forbidden:
        raise ValueError("ADR-015 evidence subject contains a recursive receipt")
    for relative in paths:
        if not (root / relative).is_file():
            raise ValueError(f"ADR-015 evidence subject file is absent: {relative}")
    return tuple(sorted(paths))


def evidence_subject_sha256(root: Path) -> str:
    material = [
        {
            "path": relative,
            "sha256": sha256((root / relative).read_bytes()),
            "sizeBytes": (root / relative).stat().st_size,
        }
        for relative in evidence_subject_paths(root)
    ]
    return sha256(canonical(material))


def current_content_root(root: Path) -> str:
    contract_root = root / "fixtures/adoption-contract/contract"
    bundle_path = contract_root / "acme-calendar.bundle.json"
    bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
    if not isinstance(bundle, dict):
        raise ValueError("ADR-015 content bundle is not an object")
    value = bundle.get("bundleDigest")
    unsigned = dict(bundle)
    unsigned.pop("bundleDigest", None)
    if (
        not isinstance(value, str)
        or len(value) != 64
        or value != sha256(canonical(unsigned))
        or bundle_path.read_bytes() != canonical(bundle) + b"\n"
    ):
        raise ValueError("ADR-015 content bundle omits its digest")
    members = bundle.get("members")
    if not isinstance(members, list):
        raise ValueError("ADR-015 content bundle omits its members")
    for raw in members:
        if not isinstance(raw, dict):
            raise ValueError("ADR-015 content bundle has an invalid member")
        relative = raw.get("path")
        digest = raw.get("sha256")
        size = raw.get("sizeBytes")
        if not isinstance(relative, str) or not isinstance(digest, str) or not isinstance(size, int):
            raise ValueError("ADR-015 content bundle has an invalid member record")
        member = contract_root / relative
        data = member.read_bytes()
        if len(data) != size or sha256(data) != digest:
            raise ValueError(f"ADR-015 content member is stale: {relative}")
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
                "scripts/adoption/observe-javascript-source.cjs",
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
                "fixtures/adoption-contract/test-ownership/adoption/ownership/ExpectedAdoptionStage.hx",
                "fixtures/adoption-contract/test-ownership/adoption/ownership/Main.hx",
                "scripts/adoption/test-ownership.py",
            ),
        ),
    }


def hosted_gate_identity(root: Path) -> str:
    """Bind a hosted pass to the complete non-recursive evidence subject."""

    return sha256(
        canonical(
            {
                "contentRoot": current_content_root(root),
                "evidenceSubjectSha256": evidence_subject_sha256(root),
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
        "evidenceSubjectSha256": evidence_subject_sha256(root),
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
        and existing.get("evidenceSubjectSha256")
        == pending["evidenceSubjectSha256"]
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
    if observer_record.get("evidenceSubjectSha256") != expected["evidenceSubjectSha256"]:
        raise ValueError("local observers did not use the current evidence subject")
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
        "evidenceSubjectSha256": expected["evidenceSubjectSha256"],
        "executionMode": execution_mode,
        "outcome": "passed",
        "observedAt": observed_at,
        "observers": expected_observers,
    }
