#!/usr/bin/env python3
"""Create a local Haxelib archive from one exact installed dependency."""

from __future__ import annotations

import argparse
import json
import os
import sys
import zipfile
from pathlib import Path


ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


class DependencyPackageFailure(RuntimeError):
    """A fail-closed installed-dependency packaging error."""


def validate_source(source: Path, name: str, version: str) -> list[Path]:
    metadata_path = source / "haxelib.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DependencyPackageFailure(f"invalid installed haxelib metadata: {error}") from error
    if metadata.get("name") != name or metadata.get("version") != version:
        raise DependencyPackageFailure(
            f"installed haxelib identity does not match {name} {version}"
        )
    dependencies = metadata.get("dependencies", {})
    if dependencies not in ({}, None):
        raise DependencyPackageFailure(
            "installed haxelib seed has transitive dependencies; package them explicitly"
        )

    files: list[Path] = []
    for path in sorted(
        source.rglob("*"), key=lambda candidate: candidate.relative_to(source).as_posix()
    ):
        relative = path.relative_to(source).as_posix()
        if path.is_symlink():
            raise DependencyPackageFailure(
                f"installed haxelib seed contains a symbolic link: {relative}"
            )
        if path.is_file():
            files.append(path)
    if metadata_path not in files:
        raise DependencyPackageFailure("installed haxelib seed has no metadata file")
    return files


def write_archive(source: Path, output: Path, files: list[Path]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.unlink(missing_ok=True)
    with zipfile.ZipFile(temporary, "w", allowZip64=True) as archive:
        for path in files:
            relative = path.relative_to(source).as_posix()
            info = zipfile.ZipInfo(relative, date_time=ZIP_TIMESTAMP)
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    os.replace(temporary, output)


def package(source: Path, output: Path, name: str, version: str) -> None:
    resolved_source = source.resolve(strict=True)
    if not resolved_source.is_dir():
        raise DependencyPackageFailure("installed haxelib seed is not a directory")
    files = validate_source(resolved_source, name, version)
    write_archive(resolved_source, output, files)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--name", required=True)
    parser.add_argument("--version", required=True)
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    try:
        package(arguments.source, arguments.out, arguments.name, arguments.version)
    except DependencyPackageFailure as error:
        print(f"installed haxelib packaging failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
