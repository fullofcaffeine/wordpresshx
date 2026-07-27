#!/usr/bin/env python3
"""Materialize exact profile-source license evidence from pinned Git objects."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SELECTION = ROOT / "profiles/catalog-selection.json"


class SnapshotError(RuntimeError):
    """A profile license-evidence invariant did not hold."""


def sha256_bytes(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def parse_repositories(values: list[str]) -> dict[str, Path]:
    repositories: dict[str, Path] = {}
    for value in values:
        name, separator, raw_path = value.partition("=")
        if not separator or not name or not raw_path or name in repositories:
            raise SnapshotError(f"repository mapping must be unique NAME=PATH: {value!r}")
        repositories[name] = Path(raw_path).resolve()
    return repositories


def git_bytes(repository: Path, *arguments: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise SnapshotError(f"git {' '.join(arguments)} failed: {detail}")
    return result.stdout


def pointer(value: object, path: str) -> object:
    current = value
    if not path.startswith("/"):
        raise SnapshotError(f"invalid JSON pointer: {path}")
    for raw_component in path[1:].split("/"):
        component = raw_component.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict) and component in current:
            current = current[component]
        elif isinstance(current, list) and component.isdigit():
            current = current[int(component)]
        else:
            raise SnapshotError(f"missing JSON pointer: {path}")
    return current


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--repository", action="append", default=[])
    parser.add_argument("--write", action="store_true")
    arguments = parser.parse_args()
    root = arguments.root.resolve()
    selection = json.loads((root / "profiles/catalog-selection.json").read_bytes())
    repositories = parse_repositories(arguments.repository)
    checked = 0

    for profile in selection["profiles"]:
        source_lock = json.loads((root / profile["sourceLockPath"]).read_bytes())
        for definition in profile["inputs"]:
            evidence = definition.get("licenseEvidence")
            if evidence is None:
                continue
            if definition.get("kind") != "git-source" or not isinstance(evidence, dict):
                raise SnapshotError("profile license evidence requires a Git source input")
            commit = pointer(source_lock, definition["pointers"]["commit"])
            if not isinstance(commit, str):
                raise SnapshotError("profile source commit must be a string")
            source_path = evidence.get("sourcePath")
            source_blob = evidence.get("sourceBlob")
            source_sha256 = evidence.get("sourceSha256")
            snapshot_path = evidence.get("snapshotPath")
            if not all(
                isinstance(value, str)
                for value in (
                    source_path,
                    source_blob,
                    source_sha256,
                    snapshot_path,
                )
            ):
                raise SnapshotError("profile license evidence identity is incomplete")
            snapshot = root / snapshot_path
            if arguments.write:
                repository_argument = definition.get("repositoryArgument")
                repository = repositories.get(repository_argument)
                if repository is None:
                    raise SnapshotError(
                        f"missing repository mapping {repository_argument}"
                    )
                actual_blob = git_bytes(
                    repository, "rev-parse", f"{commit}:{source_path}"
                ).decode("utf-8").strip()
                if actual_blob != source_blob:
                    raise SnapshotError(
                        f"{profile['profileId']}: license blob identity drifted"
                    )
                contents = git_bytes(repository, "show", f"{commit}:{source_path}")
                if sha256_bytes(contents) != source_sha256:
                    raise SnapshotError(
                        f"{profile['profileId']}: license content digest drifted"
                    )
                snapshot.parent.mkdir(parents=True, exist_ok=True)
                snapshot.write_bytes(contents)
            if not snapshot.is_file():
                raise SnapshotError(f"missing profile license snapshot: {snapshot_path}")
            if sha256_bytes(snapshot.read_bytes()) != source_sha256:
                raise SnapshotError(f"profile license snapshot drifted: {snapshot_path}")
            checked += 1

    print(f"profile license snapshots passed: {checked} exact source bindings")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, SnapshotError, json.JSONDecodeError) as error:
        print(f"profile license snapshot error: {error}", file=sys.stderr)
        raise SystemExit(1) from error
