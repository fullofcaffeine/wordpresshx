#!/usr/bin/env python3
"""Build deterministic final ZIP fixtures for the SDK-051 lifecycle gate."""

from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "lifecycle"
PACKAGES = BUILD / "packages"
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def package_bytes(source: Path, prefix: str) -> bytes:
    manifest_path = source / "wordpresshx-plugin-lifecycle.v1.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected = {
        item["path"]: (item["bytes"], item["sha256"])
        for item in manifest["files"]
    }
    actual = {
        path.relative_to(source).as_posix(): path
        for path in source.rglob("*.php")
    }
    if set(actual) != set(expected):
        raise SystemExit(f"lifecycle package inventory differs for {source.name}")
    entries: list[tuple[str, bytes]] = []
    for relative, path in sorted(actual.items()):
        data = path.read_bytes()
        expected_bytes, expected_sha = expected[relative]
        if len(data) != expected_bytes or hashlib.sha256(data).hexdigest() != expected_sha:
            raise SystemExit(f"lifecycle file identity differs: {source.name}/{relative}")
        logical = f"{prefix}/{relative}" if prefix else relative
        entries.append((logical, data))
    manifest_logical = (
        f"{prefix}/wordpresshx-plugin-lifecycle.v1.json"
        if prefix
        else f"{manifest['plugin']['slug']}/wordpresshx-plugin-lifecycle.v1.json"
    )
    entries.append((manifest_logical, manifest_path.read_bytes()))
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for logical, data in sorted(entries):
            info = zipfile.ZipInfo(logical, FIXED_TIME)
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    return output.getvalue()


def write_package(source_name: str, archive_name: str, prefix: str) -> None:
    source = BUILD / source_name
    first = package_bytes(source, prefix)
    second = package_bytes(source, prefix)
    if first != second:
        raise SystemExit(f"lifecycle ZIP replay differed: {archive_name}")
    destination = PACKAGES / archive_name
    destination.write_bytes(first)
    with zipfile.ZipFile(io.BytesIO(first)) as archive:
        if any(item.compress_type != zipfile.ZIP_STORED for item in archive.infolist()):
            raise SystemExit(f"lifecycle ZIP compression policy differed: {archive_name}")


def main() -> None:
    PACKAGES.mkdir(parents=True, exist_ok=True)
    write_package("standard-v1", "acme-lifecycle-v1.zip", "acme-lifecycle")
    write_package("standard-v3", "acme-lifecycle-v3.zip", "acme-lifecycle")
    write_package("must-use-v3", "acme-lifecycle-mu-v3.zip", "")
    print("SDK-051 deterministic lifecycle ZIP fixtures passed")


if __name__ == "__main__":
    main()
