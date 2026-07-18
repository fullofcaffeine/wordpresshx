#!/usr/bin/env python3
"""Build and verify deterministic production/debug SDK-025 package companions."""

from __future__ import annotations

import argparse
import hashlib
import json
import stat
import zipfile
from pathlib import Path, PurePosixPath


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = PACKAGE_ROOT / "build" / "source-correlation"
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
PRODUCTION_ENTRIES = (
    "includes/Bootstrap.php",
    "includes/FailureCallbacks.php",
    "includes/autoload.php",
    "includes/register-adapters.php",
    "source-correlation.php",
)
DEBUG_ENTRIES = (
    "includes/FailureCallbacks.php.haxe-map.json",
    "source-index.json",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def require_safe_path(value: str) -> None:
    path = PurePosixPath(value)
    if (
        not value
        or value.endswith("/")
        or "//" in value
        or path.is_absolute()
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise ValueError(f"unsafe package entry: {value}")


def write_zip(destination: Path, source: Path, entries: tuple[str, ...]) -> dict:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_STORED) as archive:
        for relative in sorted(entries):
            require_safe_path(relative)
            data = (source / relative).read_bytes()
            info = zipfile.ZipInfo(relative, FIXED_TIME)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, data)
    data = destination.read_bytes()
    return {
        "path": destination.name,
        "sha256": digest(data),
        "byteLength": len(data),
        "entries": list(sorted(entries)),
    }


def verify_binding(production_root: Path, debug_root: Path) -> dict:
    runtime_path = production_root / "includes/FailureCallbacks.php"
    map_path = debug_root / DEBUG_ENTRIES[0]
    index_path = debug_root / DEBUG_ENTRIES[1]
    runtime = runtime_path.read_bytes()
    map_bytes = map_path.read_bytes()
    php_map = json.loads(map_bytes)
    index = json.loads(index_path.read_bytes())
    if php_map["generated"]["path"] != "includes/FailureCallbacks.php":
        raise ValueError("PHP map generated path differs from production package")
    if php_map["generated"]["sha256"] != digest(runtime):
        raise ValueError("PHP map is stale relative to production package")
    files = index["files"]
    if index["artifactSetSha256"] != digest(canonical(files)):
        raise ValueError("source-index artifact-set hash is stale")
    runtime_record = next(record for record in files if record["role"] == "runtime")
    map_record = next(record for record in files if record["role"] == "source-map")
    if runtime_record["sha256"] != digest(runtime):
        raise ValueError("source index is stale relative to production package")
    if map_record["sha256"] != digest(map_bytes):
        raise ValueError("source index is stale relative to debug companion map")
    retention = index["retention"]
    if retention != {
        "profile": "production-evidence",
        "indexDistribution": "debug-companion",
        "mapsInProduction": False,
        "inlineMapsInProduction": False,
        "sourceContentPolicy": "omitted",
        "machinePathsAllowed": False,
        "developmentHandler": "disabled",
        "secretScanRequiredForShipping": True,
    }:
        raise ValueError("packaged debug-companion retention contract changed")
    for payload in (map_bytes, index_path.read_bytes()):
        if any(marker in payload for marker in (b"/Users/", b"/home/", b"workspace/code")):
            raise ValueError("debug companion contains a machine-local path")
    return {
        "runtimeSha256": digest(runtime),
        "mapSha256": digest(map_bytes),
        "sourceContentIncluded": False,
        "mapsInProduction": False,
    }


def extract_combined(production_zip: Path, debug_zip: Path, destination: Path) -> None:
    if destination.exists() and any(destination.iterdir()):
        raise ValueError(f"combined extraction root is not empty: {destination}")
    destination.mkdir(parents=True, exist_ok=True)
    for archive_path in (production_zip, debug_zip):
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                require_safe_path(info.filename)
                target = destination.joinpath(*PurePosixPath(info.filename).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, default=BUILD_ROOT / "packages")
    parser.add_argument("--extract-root", type=Path)
    args = parser.parse_args()

    production_root = BUILD_ROOT / "production-plugin"
    debug_root = BUILD_ROOT / "packaged-evidence"
    production_zip = args.output_root / "source-correlation-production.zip"
    debug_zip = args.output_root / "source-correlation-debug-companion.zip"
    production = write_zip(production_zip, production_root, PRODUCTION_ENTRIES)
    debug = write_zip(debug_zip, debug_root, DEBUG_ENTRIES)
    binding = verify_binding(production_root, debug_root)

    if any(
        entry.endswith((".json", ".map", ".map.json", ".hx"))
        for entry in production["entries"]
    ):
        raise ValueError("default production ZIP retained correlation metadata")
    if any(entry.endswith(".php") for entry in debug["entries"]):
        raise ValueError("debug companion duplicated production PHP")

    manifest = {
        "schemaVersion": 1,
        "format": "wordpresshx.sdk025-source-correlation-packages.v1",
        "production": production,
        "debugCompanion": debug,
        "binding": binding,
    }
    manifest_path = args.output_root / "package-manifest.json"
    manifest_path.write_bytes(canonical(manifest) + b"\n")

    if args.extract_root is not None:
        extract_combined(production_zip, debug_zip, args.extract_root)
        if digest(
            (args.extract_root / "includes/FailureCallbacks.php").read_bytes()
        ) != binding[
            "runtimeSha256"
        ]:
            raise ValueError("combined package extraction changed production PHP")

    print(
        "source-correlation packages passed: production PHP only, separate "
        "content-bound debug companion, no source content"
    )


if __name__ == "__main__":
    main()
