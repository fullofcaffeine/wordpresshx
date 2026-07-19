#!/usr/bin/env python3
"""Compare two published WordPressHx generations without exposing host paths."""

from __future__ import annotations

import hashlib
import json
import stat
import sys
from pathlib import Path, PurePosixPath


SCHEMA = "wordpress-hx.determinism-comparison.v1"


class InvalidBuild(ValueError):
    pass


def canonical(value: object, *, newline: bool = False) -> bytes:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode()
    return encoded + (b"\n" if newline else b"")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative_path(value: object, label: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value or value.startswith("/"):
        raise InvalidBuild(f"{label} is not a portable relative path")
    parts = PurePosixPath(value).parts
    if any(part in {"", ".", ".."} for part in parts) or PurePosixPath(value).as_posix() != value:
        raise InvalidBuild(f"{label} is not a normalized relative path")
    return value


def read_regular(root: Path, relative: str, label: str) -> tuple[bytes, int]:
    current = root
    for part in PurePosixPath(relative).parts:
        current = current / part
        try:
            metadata = current.lstat()
        except FileNotFoundError as error:
            raise InvalidBuild(f"{label} is missing") from error
        if stat.S_ISLNK(metadata.st_mode):
            raise InvalidBuild(f"{label} crosses a symbolic link")
    metadata = current.lstat()
    if not stat.S_ISREG(metadata.st_mode):
        raise InvalidBuild(f"{label} is not a regular file")
    return current.read_bytes(), stat.S_IMODE(metadata.st_mode)


def manifest_path(root: Path) -> str:
    config_bytes, _ = read_regular(root, "wordpress-hx.json", "project configuration")
    try:
        config = json.loads(config_bytes)
        output_roots = config["paths"]["outputRoots"]
        selected = sorted(output_roots, key=lambda item: (item["path"], item["id"]))[0]
        return relative_path(f'{selected["path"]}/_GeneratedFiles.json', "manifest path")
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as error:
        raise InvalidBuild("project configuration cannot resolve the ownership manifest") from error


def snapshot(root: Path) -> dict[str, object]:
    manifest_relative = manifest_path(root)
    manifest_bytes, manifest_mode = read_regular(root, manifest_relative, "ownership manifest")
    try:
        manifest = json.loads(manifest_bytes)
    except json.JSONDecodeError as error:
        raise InvalidBuild("ownership manifest is not JSON") from error
    if manifest_bytes != canonical(manifest, newline=True):
        raise InvalidBuild("ownership manifest is not canonical JSON with one final LF")
    if manifest.get("schema") != "wordpress-hx.generated-files.v1":
        raise InvalidBuild("ownership manifest has the wrong schema")
    material = dict(manifest)
    claimed_digest = material.pop("manifestDigest", None)
    if claimed_digest != sha256(canonical(material)):
        raise InvalidBuild("ownership manifest self-digest mismatch")
    files = manifest.get("files")
    if not isinstance(files, list):
        raise InvalidBuild("ownership manifest files are not an array")
    artifacts: dict[str, dict[str, object]] = {}
    previous: str | None = None
    for index, record in enumerate(files):
        if not isinstance(record, dict):
            raise InvalidBuild("ownership manifest contains a non-object file record")
        path = relative_path(record.get("path"), f"manifest file {index}")
        if previous is not None and previous >= path:
            raise InvalidBuild("ownership manifest files are not sorted and unique")
        previous = path
        data, mode = read_regular(root, path, f"owned artifact {path}")
        actual_digest = sha256(data)
        if record.get("contentSha256") != actual_digest or record.get("sizeBytes") != len(data):
            raise InvalidBuild(f"owned artifact bytes do not match their record: {path}")
        artifacts[path] = {"sha256": actual_digest, "sizeBytes": len(data), "mode": mode}
    inputs = manifest.get("inputs")
    if not isinstance(inputs, dict) or not isinstance(inputs.get("sourceTreeSha256"), str):
        raise InvalidBuild("ownership manifest lacks its source fingerprint")
    return {
        "fingerprint": inputs["sourceTreeSha256"],
        "manifestBytes": manifest_bytes,
        "manifestDigest": claimed_digest,
        "manifestMode": manifest_mode,
        "artifacts": artifacts,
    }


def difference(scope: str, path: str, left: object, right: object) -> dict[str, object]:
    return {"scope": scope, "path": path, "left": left, "right": right}


def compare(left: dict[str, object], right: dict[str, object]) -> dict[str, object] | None:
    if left["fingerprint"] != right["fingerprint"]:
        return difference("effective-input-fingerprint", "wordpress-hx.json", left["fingerprint"], right["fingerprint"])
    left_artifacts = left["artifacts"]
    right_artifacts = right["artifacts"]
    assert isinstance(left_artifacts, dict) and isinstance(right_artifacts, dict)
    paths = sorted(set(left_artifacts) | set(right_artifacts))
    for path in paths:
        if path not in left_artifacts or path not in right_artifacts:
            return difference("artifact-presence", path, path in left_artifacts, path in right_artifacts)
        left_record = left_artifacts[path]
        right_record = right_artifacts[path]
        assert isinstance(left_record, dict) and isinstance(right_record, dict)
        if left_record["sha256"] != right_record["sha256"]:
            return difference("artifact-bytes", path, left_record["sha256"], right_record["sha256"])
        if left_record["mode"] != right_record["mode"]:
            return difference("artifact-mode", path, left_record["mode"], right_record["mode"])
        if left_record["mode"] != 0o644:
            return difference("artifact-mode-policy", path, 0o644, left_record["mode"])
    if left["manifestBytes"] != right["manifestBytes"]:
        return difference("ownership-manifest-bytes", manifest_path_label(), left["manifestDigest"], right["manifestDigest"])
    if left["manifestMode"] != right["manifestMode"]:
        return difference("ownership-manifest-mode", manifest_path_label(), left["manifestMode"], right["manifestMode"])
    if left["manifestMode"] != 0o644:
        return difference("ownership-manifest-mode-policy", manifest_path_label(), 0o644, left["manifestMode"])
    return None


def manifest_path_label() -> str:
    return "_GeneratedFiles.json"


def result(status: str, first_difference: dict[str, object] | None, left: dict[str, object], right: dict[str, object]) -> dict[str, object]:
    return {
        "schema": SCHEMA,
        "status": status,
        "firstDifference": first_difference,
        "left": {
            "fingerprint": left["fingerprint"],
            "manifestDigest": left["manifestDigest"],
            "artifactCount": len(left["artifacts"]),
        },
        "right": {
            "fingerprint": right["fingerprint"],
            "manifestDigest": right["manifestDigest"],
            "artifactCount": len(right["artifacts"]),
        },
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: compare-builds.py <left-project-root> <right-project-root>")
    try:
        left = snapshot(Path(sys.argv[1]).resolve())
        right = snapshot(Path(sys.argv[2]).resolve())
        first = compare(left, right)
        print(canonical(result("equal" if first is None else "different", first, left, right), newline=True).decode(), end="")
        raise SystemExit(0 if first is None else 1)
    except InvalidBuild as error:
        document = {"schema": SCHEMA, "status": "invalid", "reason": str(error)}
        print(canonical(document, newline=True).decode(), end="")
        raise SystemExit(2) from error


if __name__ == "__main__":
    main()
