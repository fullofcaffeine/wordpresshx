#!/usr/bin/env python3
"""Independently validate emitted SDK-025 maps, indexes, retention, and bytes."""

from __future__ import annotations

import hashlib
import json
import re
import runpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COMPILER_ROOT = ROOT / "compiler" / "wordpress"
BUILD_ROOT = COMPILER_ROOT / "build" / "source-correlation"
SCHEMA_HELPERS = runpy.run_path(
    str(ROOT / "scripts" / "source-correlation" / "validate-contracts.py")
)
ClosedSchemaValidator = SCHEMA_HELPERS["ClosedSchemaValidator"]


class ValidationError(ValueError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def safe_path(value: str, label: str) -> None:
    if (
        not value
        or value.startswith("/")
        or re.match(r"^[A-Za-z]:", value)
        or "\\" in value
        or ":" in value
        or "//" in value
        or any(part in {"", ".", ".."} for part in value.split("/"))
    ):
        raise ValidationError(f"{label}: unsafe logical path {value!r}")


def line_count(data: bytes) -> int:
    return data.count(b"\n") + (0 if data.endswith(b"\n") else 1)


def position(data: bytes, offset: int) -> dict[str, int]:
    if not 0 <= offset <= len(data):
        raise ValidationError("span exceeds authenticated content")
    data[:offset].decode("utf-8")
    previous = data.rfind(b"\n", 0, offset)
    return {
        "line": data[:offset].count(b"\n") + 1,
        "columnUtf8": offset if previous < 0 else offset - previous - 1,
    }


def validate_span(span: dict, data: bytes, label: str) -> None:
    start = span["startByte"]
    end = span["endByte"]
    if not 0 <= start < end <= len(data):
        raise ValidationError(f"{label}: invalid half-open byte range")
    if span["start"] != position(data, start) or span["end"] != position(data, end):
        raise ValidationError(f"{label}: redundant coordinates contradict bytes")


def validate_bound(record: dict, path: Path, label: str) -> bytes:
    data = path.read_bytes()
    data.decode("utf-8")
    if b"\r" in data:
        raise ValidationError(f"{label}: content is not LF-normalized")
    if record["sha256"] != digest(data) or record["byteLength"] != len(data):
        raise ValidationError(f"{label}: content identity mismatch")
    if "lineCount" in record and record["lineCount"] != line_count(data):
        raise ValidationError(f"{label}: line count mismatch")
    return data


def validate_profile(name: str, source_location: str) -> tuple[bytes, bytes, dict]:
    profile_root = BUILD_ROOT / name
    index_path = profile_root / "source-index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index_schema = json.loads(
        (ROOT / "schemas" / "source-correlation-index.schema.json").read_text(
            encoding="utf-8"
        )
    )
    ClosedSchemaValidator(index_schema).validate(index)
    files = index["files"]
    if [record["id"] for record in files] != sorted(
        {record["id"] for record in files}
    ):
        raise ValidationError(f"{name}: file IDs are not sorted and unique")
    if index["artifactSetSha256"] != digest(canonical(files)):
        raise ValidationError(f"{name}: artifact-set digest mismatch")

    files_by_id = {record["id"]: record for record in files}
    file_bytes: dict[str, bytes] = {}
    for record in files:
        safe_path(record["path"], f"{name} file")
        if record["role"] == "source":
            identity = record["sourceIdentity"]
            safe_path(identity["path"], f"{name} source identity")
            path = (
                profile_root / record["path"]
                if source_location == "companion"
                else ROOT / identity["path"]
            )
        else:
            path = profile_root / record["path"]
        file_bytes[record["id"]] = validate_bound(
            record, path, f"{name} file {record['id']}"
        )

    correlation = index["correlations"]
    if len(correlation) != 1 or correlation[0]["strategy"] != "php-range-map":
        raise ValidationError(f"{name}: expected one PHP range-map correlation")
    correlation = correlation[0]
    layer = correlation["layers"][0]
    runtime_record = files_by_id[layer["generatedFileId"]]
    map_record = files_by_id[layer["mapFileId"]]
    source_records = [files_by_id[file_id] for file_id in layer["sourceFileIds"]]
    php_map = json.loads(file_bytes[map_record["id"]])
    php_schema = json.loads(
        (ROOT / "schemas" / "php-haxe-map.schema.json").read_text(encoding="utf-8")
    )
    ClosedSchemaValidator(php_schema).validate(php_map)
    generated = php_map["generated"]
    if generated["path"] != runtime_record["path"]:
        raise ValidationError(f"{name}: map/index generated path mismatch")
    generated_bytes = file_bytes[runtime_record["id"]]
    validate_bound(generated, profile_root / generated["path"], f"{name} map PHP")

    indexed_sources = {
        (
            record["sourceIdentity"]["rootId"],
            record["sourceIdentity"]["path"],
            record["sha256"],
        ): file_bytes[record["id"]]
        for record in source_records
    }
    source_bytes: dict[str, bytes] = {}
    for source in php_map["sources"]:
        key = (source["rootId"], source["path"], source["sha256"])
        if key not in indexed_sources:
            raise ValidationError(f"{name}: map/index source binding mismatch")
        data = indexed_sources[key]
        if source["byteLength"] != len(data) or source["lineCount"] != line_count(data):
            raise ValidationError(f"{name}: map source dimensions mismatch")
        source_bytes[source["id"]] = data

    mappings = php_map["mappings"]
    ordering = [
        (
            mapping["generatedSpan"]["startByte"],
            mapping["generatedSpan"]["endByte"],
            mapping["id"],
        )
        for mapping in mappings
    ]
    if ordering != sorted(ordering):
        raise ValidationError(f"{name}: mapping order is not deterministic")
    mappings_by_id = {}
    for mapping in mappings:
        validate_span(
            mapping["generatedSpan"], generated_bytes, f"{name} {mapping['id']} PHP"
        )
        origin = mapping["origin"]
        if origin["kind"] == "haxe-source":
            validate_span(
                origin["sourceSpan"],
                source_bytes[origin["sourceId"]],
                f"{name} {mapping['id']} Haxe",
            )
        mappings_by_id[mapping["id"]] = mapping

    anchors = php_map["traceAnchors"]
    lines = [anchor["generatedLine"] for anchor in anchors]
    if lines != sorted(set(lines)) or len(lines) != 4:
        raise ValidationError(f"{name}: trace anchors are not four sorted unique lines")
    for anchor in anchors:
        if anchor["mappingId"] not in mappings_by_id:
            raise ValidationError(f"{name}: trace anchor references an unknown mapping")
    return generated_bytes, file_bytes[map_record["id"]], index


def main() -> None:
    development_php, development_map, development_index = validate_profile(
        "development", "companion"
    )
    packaged_php, packaged_map, packaged_index = validate_profile(
        "packaged-evidence", "external"
    )
    production_files = sorted(
        path.relative_to(BUILD_ROOT / "production-plugin").as_posix()
        for path in (BUILD_ROOT / "production-plugin").rglob("*")
        if path.is_file()
    )
    if production_files != [
        "includes/Bootstrap.php",
        "includes/FailureCallbacks.php",
        "includes/autoload.php",
        "includes/register-adapters.php",
        "source-correlation.php",
    ]:
        raise ValidationError(
            f"default production retention changed: {production_files!r}"
        )
    production_php = (
        BUILD_ROOT / "production-plugin" / "includes" / "FailureCallbacks.php"
    ).read_bytes()
    if not development_php == packaged_php == production_php:
        raise ValidationError("development/packaged/production PHP bytes differ")
    if development_map != packaged_map:
        raise ValidationError("development and packaged map bytes differ")
    if packaged_index["retention"]["sourceContentPolicy"] != "omitted":
        raise ValidationError("packaged companion unexpectedly includes source content")
    if development_index["retention"]["profile"] != "development":
        raise ValidationError("development source-index profile changed")
    packaged_paths = {
        path.relative_to(BUILD_ROOT / "packaged-evidence").as_posix()
        for path in (BUILD_ROOT / "packaged-evidence").rglob("*")
        if path.is_file()
    }
    if any(path.endswith(".hx") for path in packaged_paths):
        raise ValidationError("packaged debug companion retained Haxe source content")

    print(
        "SDK-025 source correlation passed: 2 closed indexes, 2 exact maps, "
        "4 anchors/profile, production PHP-only retention"
    )


if __name__ == "__main__":
    main()
