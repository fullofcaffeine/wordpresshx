#!/usr/bin/env python3
"""Exercise the ADR-015 generated set through the production ADR-007 owner."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


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


def self_digest(value: dict[str, object], field: str) -> None:
    unsigned = dict(value)
    unsigned.pop(field, None)
    value[field] = sha256(canonical(unsigned))


def snapshot(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file() and not path.is_symlink()
    }


def manifest(stage: Path) -> dict[str, object]:
    return json.loads((stage / "generated/_GeneratedFiles.json").read_text(encoding="utf-8"))


def make_stage(source: Path, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=False)
    for value in manifest(source)["files"]:
        relative = Path(value["path"])
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, target)
    return destination


def provider_snapshot(project: Path) -> dict[str, bytes]:
    provider = project / "native-provider"
    return {
        path.relative_to(provider).as_posix(): path.read_bytes()
        for path in sorted(provider.rglob("*"))
        if path.is_file()
    }


def create_project(root: Path, name: str) -> Path:
    project = root / name / "project"
    project.mkdir(parents=True)
    shutil.copytree(ROOT / "fixtures/adoption-contract/inputs", project / "native-provider")
    return project


def self_consistent_stale_source(
    current: Path,
    stage: Path,
    destination: Path,
) -> Path:
    destination_manifest = destination / "generated/_GeneratedFiles.json"
    destination_manifest.parent.mkdir(parents=True, exist_ok=False)
    value = manifest(current)
    contract_path = "generated/adoption/acme-calendar/contract.json"
    contract = stage / contract_path
    contract_value = json.loads(contract.read_text(encoding="utf-8"))
    contract_value["provider"]["version"] = "9.9.9"
    self_digest(contract_value, "contractDigest")
    contract.write_bytes(canonical(contract_value) + b"\n")
    bundle_path = "generated/adoption/acme-calendar/adoption.bundle.json"
    bundle_file = stage / bundle_path
    bundle = json.loads(bundle_file.read_text(encoding="utf-8"))
    contract_record = next(
        record for record in bundle["members"] if record["role"] == "contract"
    )
    contract_record["sha256"] = sha256(contract.read_bytes())
    contract_record["sizeBytes"] = len(contract.read_bytes())
    self_digest(bundle, "bundleDigest")
    bundle_file.write_bytes(canonical(bundle) + b"\n")
    for record in value["files"]:
        relative = record["path"]
        data = (stage / relative).read_bytes()
        record["contentSha256"] = sha256(data)
        record["sizeBytes"] = len(data)
    material = [
        {
            "contentSha256": record["contentSha256"],
            "path": record["path"],
            "sizeBytes": record["sizeBytes"],
        }
        for record in value["files"]
    ]
    value["inputs"]["generationSha256"] = sha256(canonical(material))
    self_digest(value, "manifestDigest")
    destination_manifest.write_bytes(canonical(value) + b"\n")
    return destination


def invoke(
    node: str,
    runtime: Path,
    command: str,
    project: Path,
    arguments: list[str] | None = None,
    *,
    fault: str | None = None,
    expected: int = 0,
) -> dict[str, object] | None:
    environment = os.environ.copy()
    if fault is not None:
        environment["WPHX_OWNERSHIP_FAULT"] = fault
    result = subprocess.run(
        [node, str(runtime), command, str(project), *(arguments or [])],
        cwd=ROOT,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != expected:
        raise AssertionError(
            f"{command} exited {result.returncode}, expected {expected}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )
    if expected == 91:
        return None
    payload = result.stdout if expected == 0 else result.stderr
    return json.loads(payload)


def publish(
    node: str,
    runtime: Path,
    project: Path,
    source: Path,
    stage: Path,
    *,
    fault: str | None = None,
    expected: int = 0,
) -> dict[str, object] | None:
    return invoke(
        node,
        runtime,
        "publish-adoption",
        project,
        [str(source / "generated/_GeneratedFiles.json"), str(stage), "pass"],
        fault=fault,
        expected=expected,
    )


def assert_owned(project: Path, source: Path) -> None:
    for value in manifest(source)["files"]:
        relative = Path(value["path"])
        if (project / relative).read_bytes() != (source / relative).read_bytes():
            raise AssertionError(f"published ownership byte mismatch: {relative}")
    if (project / "generated/_GeneratedFiles.json").read_bytes() != (
        source / "generated/_GeneratedFiles.json"
    ).read_bytes():
        raise AssertionError("published ownership manifest differs from generated authority")


def main() -> None:
    if len(sys.argv) != 6:
        raise SystemExit(
            "usage: test-ownership.py <runtime.js> <current-stage> "
            "<updated-stage> <work-root> <node>"
        )
    runtime = Path(sys.argv[1]).resolve()
    current = Path(sys.argv[2]).resolve()
    updated = Path(sys.argv[3]).resolve()
    work = Path(sys.argv[4]).resolve()
    node = sys.argv[5]
    work.mkdir(parents=True, exist_ok=False)

    project = create_project(work, "stale-bundle-semantics")
    before_failure = snapshot(project)
    stale_stage = make_stage(
        current, work / "stale-bundle-semantics/stage-current"
    )
    stale_source = self_consistent_stale_source(
        current,
        stale_stage,
        work / "stale-bundle-semantics/source",
    )
    failure = publish(
        node,
        runtime,
        project,
        stale_source,
        stale_stage,
        expected=3,
    )
    if failure is None or failure.get("code") != "validator-failed":
        raise AssertionError(
            f"self-consistent ownership accepted stale bundle semantics: {failure}"
        )
    if snapshot(project) != before_failure:
        raise AssertionError("semantic bundle rejection began a transaction")

    project = create_project(work, "publish-noop-clean")
    provider_before = provider_snapshot(project)
    current_stage = make_stage(current, work / "publish-noop-clean/stage-current")
    result = publish(node, runtime, project, current, current_stage)
    if result != {"outcome": "published"}:
        raise AssertionError(f"initial publication failed: {result}")
    assert_owned(project, current)
    before_noop = snapshot(project)
    replay_stage = make_stage(current, work / "publish-noop-clean/stage-replay")
    result = publish(node, runtime, project, current, replay_stage)
    if result != {"outcome": "no-op"} or snapshot(project) != before_noop:
        raise AssertionError("byte-identical regeneration was not a true no-op")
    result = invoke(node, runtime, "clean-adoption", project)
    if result != {"outcome": "published"}:
        raise AssertionError(f"adoption removal failed: {result}")
    for value in manifest(current)["files"]:
        if (project / Path(value["path"])).exists():
            raise AssertionError(f"clean retained an owned file: {value['path']}")
    clean_manifest = json.loads(
        (project / "generated/_GeneratedFiles.json").read_text(encoding="utf-8")
    )
    if clean_manifest["files"] != [] or provider_snapshot(project) != provider_before:
        raise AssertionError("clean removed provider-owned bytes or retained generated entries")

    project = create_project(work, "update")
    provider_before = provider_snapshot(project)
    publish(
        node,
        runtime,
        project,
        current,
        make_stage(current, work / "update/stage-current"),
    )
    result = publish(
        node,
        runtime,
        project,
        updated,
        make_stage(updated, work / "update/stage-updated"),
    )
    if result != {"outcome": "published"}:
        raise AssertionError(f"changed-provider regeneration failed: {result}")
    assert_owned(project, updated)
    if provider_snapshot(project) != provider_before:
        raise AssertionError("regeneration changed provider-owned bytes")

    project = create_project(work, "modified-owned")
    publish(
        node,
        runtime,
        project,
        current,
        make_stage(current, work / "modified-owned/stage-current"),
    )
    owned_path = Path(manifest(current)["files"][0]["path"])
    (project / owned_path).write_bytes((project / owned_path).read_bytes() + b"manual edit\n")
    before_failure = snapshot(project)
    failure = publish(
        node,
        runtime,
        project,
        updated,
        make_stage(updated, work / "modified-owned/stage-updated"),
        expected=3,
    )
    if failure is None or failure.get("code") != "modified-owned-file":
        raise AssertionError(f"modified owned file did not fail closed: {failure}")
    if snapshot(project) != before_failure:
        raise AssertionError("modified-owned-file rejection changed the project")

    project = create_project(work, "rollback")
    provider_before = provider_snapshot(project)
    publish(
        node,
        runtime,
        project,
        current,
        make_stage(current, work / "rollback/stage-current"),
    )
    before_crash = snapshot(project)
    publish(
        node,
        runtime,
        project,
        updated,
        make_stage(updated, work / "rollback/stage-updated"),
        fault="crash:after-operation-1",
        expected=91,
    )
    recovered = invoke(node, runtime, "recover-adoption", project)
    if recovered != {"outcome": "rolled-back"}:
        raise AssertionError(f"interrupted adoption update did not roll back: {recovered}")
    if snapshot(project) != before_crash or provider_snapshot(project) != provider_before:
        raise AssertionError("rollback did not restore exact project/provider bytes")

    print(
        "ADR-015 production ownership rejected stale bundle semantics before "
        "transaction and passed publish, no-op, update, removal, rollback, "
        "and provider-untouched cases"
    )


if __name__ == "__main__":
    main()
