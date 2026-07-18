#!/usr/bin/env python3
"""Validate ADR-014 source-correlation schemas and content-bound fixtures."""

from __future__ import annotations

import copy
import hashlib
import json
import posixpath
import re
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "fixtures" / "source-correlation"
PHP_SCHEMA_PATH = ROOT / "schemas" / "php-haxe-map.schema.json"
INDEX_SCHEMA_PATH = ROOT / "schemas" / "source-correlation-index.schema.json"
PHP_MAP_PATH = (
    FIXTURE_ROOT
    / "artifacts"
    / "plugin"
    / "includes"
    / "failure.php.haxe-map.json"
)
INDEX_PATH = FIXTURE_ROOT / "source-index.valid.json"


class ContractError(ValueError):
    pass


class ClosedSchemaValidator:
    """Small dependency-free validator for the closed schema subset used here."""

    def __init__(self, root_schema: dict[str, object]) -> None:
        self.root_schema = root_schema

    def validate(
        self,
        value: object,
        schema: dict[str, object] | None = None,
        path: str = "$",
    ) -> None:
        current = schema or self.root_schema
        if "$ref" in current:
            current = self.resolve_ref(str(current["$ref"]))

        if "oneOf" in current:
            matches = 0
            failures: list[str] = []
            for candidate in current["oneOf"]:
                try:
                    self.validate(value, candidate, path)
                except ContractError as error:
                    failures.append(str(error))
                    continue
                matches += 1
            if matches != 1:
                details = f"; candidates: {' | '.join(failures)}" if failures else ""
                raise ContractError(
                    f"{path}: expected exactly one schema match, found {matches}{details}"
                )
            return

        if "const" in current and value != current["const"]:
            raise ContractError(f"{path}: expected constant {current['const']!r}")
        if "enum" in current and value not in current["enum"]:
            raise ContractError(
                f"{path}: {value!r} is not one of {current['enum']!r}"
            )

        expected_type = current.get("type")
        if expected_type is not None:
            self.require_type(value, str(expected_type), path)

        if isinstance(value, str):
            if len(value) < int(current.get("minLength", 0)):
                raise ContractError(f"{path}: string is too short")
            if "maxLength" in current and len(value) > int(current["maxLength"]):
                raise ContractError(f"{path}: string is too long")
            pattern = current.get("pattern")
            if pattern is not None and re.fullmatch(str(pattern), value) is None:
                raise ContractError(
                    f"{path}: {value!r} does not match {pattern!r}"
                )

        if isinstance(value, int) and not isinstance(value, bool):
            if "minimum" in current and value < int(current["minimum"]):
                raise ContractError(
                    f"{path}: integer is below minimum {current['minimum']}"
                )
            if "maximum" in current and value > int(current["maximum"]):
                raise ContractError(
                    f"{path}: integer is above maximum {current['maximum']}"
                )

        if isinstance(value, list):
            if len(value) < int(current.get("minItems", 0)):
                raise ContractError(f"{path}: array has too few items")
            if "maxItems" in current and len(value) > int(current["maxItems"]):
                raise ContractError(f"{path}: array has too many items")
            if current.get("uniqueItems") is True:
                serialized = [
                    json.dumps(item, sort_keys=True, separators=(",", ":"))
                    for item in value
                ]
                if len(serialized) != len(set(serialized)):
                    raise ContractError(f"{path}: array items are not unique")
            item_schema = current.get("items")
            if item_schema is not None:
                for index, item in enumerate(value):
                    self.validate(item, item_schema, f"{path}[{index}]")

        if isinstance(value, dict):
            for field in current.get("required", []):
                if field not in value:
                    raise ContractError(f"{path}: missing required field {field}")
            properties = current.get("properties", {})
            if current.get("additionalProperties") is False:
                unknown = sorted(set(value) - set(properties))
                if unknown:
                    raise ContractError(
                        f"{path}: unknown field(s): {', '.join(unknown)}"
                    )
            for field, field_value in value.items():
                if field in properties:
                    self.validate(field_value, properties[field], f"{path}.{field}")

    def resolve_ref(self, reference: str) -> dict[str, object]:
        if not reference.startswith("#/"):
            raise ContractError(f"external schema reference is forbidden: {reference}")
        current: object = self.root_schema
        for component in reference[2:].split("/"):
            if not isinstance(current, dict) or component not in current:
                raise ContractError(f"unresolvable schema reference: {reference}")
            current = current[component]
        if not isinstance(current, dict):
            raise ContractError(f"schema reference is not an object: {reference}")
        return current

    @staticmethod
    def require_type(value: object, expected: str, path: str) -> None:
        matches = {
            "object": isinstance(value, dict),
            "array": isinstance(value, list),
            "string": isinstance(value, str),
            "integer": isinstance(value, int) and not isinstance(value, bool),
            "boolean": isinstance(value, bool),
        }.get(expected)
        if matches is None:
            raise ContractError(
                f"{path}: unsupported validator schema type {expected}"
            )
        if not matches:
            raise ContractError(
                f"{path}: expected {expected}, found {type(value).__name__}"
            )


def assert_closed_objects(schema: object, path: str = "$schema") -> None:
    if isinstance(schema, dict):
        if schema.get("type") == "object" and schema.get(
            "additionalProperties"
        ) is not False:
            raise ContractError(f"{path}: object schema is not closed")
        for key, value in schema.items():
            assert_closed_objects(value, f"{path}.{key}")
    elif isinstance(schema, list):
        for index, value in enumerate(schema):
            assert_closed_objects(value, f"{path}[{index}]")


def load_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ContractError(f"{path.relative_to(ROOT)}: root must be an object")
    return value


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def line_count(data: bytes) -> int:
    if not data:
        return 0
    return data.count(b"\n") + (0 if data.endswith(b"\n") else 1)


def require_safe_relative_path(value: str, label: str) -> None:
    if not value or value.startswith("/") or re.match(r"^[A-Za-z]:", value):
        raise ContractError(f"{label}: path must be relative")
    if "\\" in value or ":" in value or any(ord(char) < 32 for char in value):
        raise ContractError(f"{label}: path contains a forbidden character")
    parts = value.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise ContractError(f"{label}: path contains an unsafe segment")


def position_at(data: bytes, offset: int) -> dict[str, int]:
    if offset < 0 or offset > len(data):
        raise ContractError("position offset exceeds authenticated bytes")
    try:
        data[:offset].decode("utf-8")
    except UnicodeDecodeError as error:
        raise ContractError("position offset splits a UTF-8 sequence") from error
    previous_newline = data.rfind(b"\n", 0, offset)
    return {
        "line": data[:offset].count(b"\n") + 1,
        "columnUtf8": offset if previous_newline < 0 else offset - previous_newline - 1,
    }


def validate_span(span: dict[str, object], data: bytes, label: str) -> None:
    start = int(span["startByte"])
    end = int(span["endByte"])
    if not 0 <= start < end <= len(data):
        raise ContractError(f"{label}: byte range is not non-empty and in bounds")
    if span["start"] != position_at(data, start):
        raise ContractError(f"{label}: start coordinate contradicts exact bytes")
    if span["end"] != position_at(data, end):
        raise ContractError(f"{label}: end coordinate contradicts exact bytes")


def validate_bound_file(record: dict[str, object], path: Path, label: str) -> bytes:
    data = path.read_bytes()
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ContractError(f"{label}: content is not UTF-8") from error
    if b"\r" in data:
        raise ContractError(f"{label}: content does not use normalized LF endings")
    if record["sha256"] != digest(data):
        raise ContractError(f"{label}: content SHA-256 mismatch")
    if record["byteLength"] != len(data):
        raise ContractError(f"{label}: byte length mismatch")
    if "lineCount" in record and record["lineCount"] != line_count(data):
        raise ContractError(f"{label}: line count mismatch")
    return data


def fixture_path(relative: str) -> Path:
    require_safe_relative_path(relative, "fixture file")
    path = (FIXTURE_ROOT / relative).resolve()
    try:
        path.relative_to(FIXTURE_ROOT.resolve())
    except ValueError as error:
        raise ContractError("fixture file escapes fixture root") from error
    if not path.is_file():
        raise ContractError(f"fixture file is missing: {relative}")
    return path


def validate_php_map(
    document: dict[str, object], validator: ClosedSchemaValidator
) -> None:
    validator.validate(document)
    generated_record = document["generated"]
    require_safe_relative_path(generated_record["path"], "generated PHP")
    generated = validate_bound_file(
        generated_record,
        fixture_path(generated_record["path"]),
        "generated PHP",
    )

    source_prefixes = {"project": "source/project"}
    sources = document["sources"]
    source_ids = [source["id"] for source in sources]
    if source_ids != sorted(set(source_ids)):
        raise ContractError("PHP map sources must have sorted unique IDs")
    source_bytes: dict[str, bytes] = {}
    for source in sources:
        require_safe_relative_path(source["path"], f"source {source['id']}")
        prefix = source_prefixes.get(source["rootId"])
        if prefix is None:
            raise ContractError(f"source {source['id']}: unknown logical root")
        source_bytes[source["id"]] = validate_bound_file(
            source,
            fixture_path(f"{prefix}/{source['path']}"),
            f"source {source['id']}",
        )

    mappings = document["mappings"]
    mapping_ids = [mapping["id"] for mapping in mappings]
    if len(mapping_ids) != len(set(mapping_ids)):
        raise ContractError("PHP map mapping IDs must be unique")
    ordering = [
        (
            mapping["generatedSpan"]["startByte"],
            mapping["generatedSpan"]["endByte"],
            mapping["id"],
        )
        for mapping in mappings
    ]
    if ordering != sorted(ordering):
        raise ContractError("PHP mappings must use deterministic generated-span order")
    for mapping in mappings:
        validate_span(
            mapping["generatedSpan"], generated, f"mapping {mapping['id']} generated"
        )
        origin = mapping["origin"]
        if origin["kind"] in {"haxe-source", "native-source"}:
            source_id = origin["sourceId"]
            if source_id not in source_bytes:
                raise ContractError(f"mapping {mapping['id']}: unknown source ID")
            expected_kind = "haxe" if origin["kind"] == "haxe-source" else "native"
            actual_source = next(source for source in sources if source["id"] == source_id)
            if actual_source["kind"] != expected_kind:
                raise ContractError(f"mapping {mapping['id']}: source kind mismatch")
            validate_span(
                origin["sourceSpan"],
                source_bytes[source_id],
                f"mapping {mapping['id']} source",
            )
        elif mapping["nodeKind"] != "compiler-generated":
            raise ContractError(
                f"mapping {mapping['id']}: compiler origin requires compiler-generated node kind"
            )

    for left_index, left in enumerate(mappings):
        left_span = left["generatedSpan"]
        for right in mappings[left_index + 1 :]:
            right_span = right["generatedSpan"]
            overlaps = (
                left_span["startByte"] < right_span["endByte"]
                and right_span["startByte"] < left_span["endByte"]
            )
            if not overlaps:
                continue
            left_contains = (
                left_span["startByte"] <= right_span["startByte"]
                and left_span["endByte"] >= right_span["endByte"]
            )
            right_contains = (
                right_span["startByte"] <= left_span["startByte"]
                and right_span["endByte"] >= left_span["endByte"]
            )
            if not (left_contains or right_contains):
                raise ContractError("PHP mappings contain a crossing overlap")
            if left_span == right_span and left["structuralDepth"] == right["structuralDepth"]:
                raise ContractError("PHP mappings contain an ambiguous equal-span tie")

    anchors = document["traceAnchors"]
    anchor_lines = [anchor["generatedLine"] for anchor in anchors]
    if anchor_lines != sorted(set(anchor_lines)):
        raise ContractError("PHP trace anchors must have sorted unique lines")
    mappings_by_id = {mapping["id"]: mapping for mapping in mappings}
    generated_lines = generated.splitlines(keepends=True)
    line_offset = 0
    line_intervals: dict[int, tuple[int, int]] = {}
    for line_number, line in enumerate(generated_lines, start=1):
        line_intervals[line_number] = (line_offset, line_offset + len(line))
        line_offset += len(line)
    for anchor in anchors:
        mapping = mappings_by_id.get(anchor["mappingId"])
        if mapping is None:
            raise ContractError("PHP trace anchor references an unknown mapping")
        interval = line_intervals.get(anchor["generatedLine"])
        if interval is None:
            raise ContractError("PHP trace anchor line is out of bounds")
        span = mapping["generatedSpan"]
        if not (span["startByte"] < interval[1] and interval[0] < span["endByte"]):
            raise ContractError("PHP trace anchor does not intersect its mapping")


def exact_php_lookup(document: dict[str, object], byte_offset: int) -> str | None:
    candidates = [
        mapping
        for mapping in document["mappings"]
        if mapping["generatedSpan"]["startByte"]
        <= byte_offset
        < mapping["generatedSpan"]["endByte"]
    ]
    if not candidates:
        return None
    candidates.sort(
        key=lambda mapping: (
            mapping["generatedSpan"]["endByte"]
            - mapping["generatedSpan"]["startByte"],
            -mapping["structuralDepth"],
            mapping["id"],
        )
    )
    first = candidates[0]
    first_key = (
        first["generatedSpan"]["endByte"] - first["generatedSpan"]["startByte"],
        first["structuralDepth"],
    )
    ties = [
        candidate
        for candidate in candidates
        if (
            candidate["generatedSpan"]["endByte"]
            - candidate["generatedSpan"]["startByte"],
            candidate["structuralDepth"],
        )
        == first_key
    ]
    if len(ties) != 1:
        raise ContractError("exact PHP lookup is ambiguous")
    return first["id"]


def php_line_lookup(document: dict[str, object], line: int) -> str | None:
    matches = [
        anchor for anchor in document["traceAnchors"] if anchor["generatedLine"] == line
    ]
    if len(matches) > 1:
        raise ContractError("PHP line lookup is ambiguous")
    return matches[0]["mappingId"] if matches else None


def resolve_v3_source(map_path: str, source: str) -> str:
    if (
        not source
        or source.startswith("/")
        or re.match(r"^[A-Za-z]:", source)
        or "\\" in source
        or "://" in source
        or any(ord(char) < 32 for char in source)
    ):
        raise ContractError("Source Map v3 source is absolute or unsafe")
    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(map_path), source))
    require_safe_relative_path(resolved, "resolved Source Map v3 source")
    return resolved


def validate_source_map_v3(
    map_record: dict[str, object],
    generated_record: dict[str, object],
    source_records: list[dict[str, object]],
    source_content_policy: str,
) -> None:
    document = load_json(fixture_path(map_record["path"]))
    allowed = {"version", "file", "sourceRoot", "sources", "sourcesContent", "names", "mappings"}
    unknown = set(document) - allowed
    if unknown:
        raise ContractError(f"Source Map v3 has unsupported fields: {sorted(unknown)}")
    if document.get("version") != 3:
        raise ContractError("browser map is not Source Map v3")
    if document.get("file") != posixpath.basename(generated_record["path"]):
        raise ContractError("browser map file does not match exact generated file")
    if not isinstance(document.get("mappings"), str) or not document["mappings"]:
        raise ContractError("browser map has no mappings")
    sources = document.get("sources")
    if not isinstance(sources, list) or not sources:
        raise ContractError("browser map has no sources")
    if "sourcesContent" in document:
        if source_content_policy != "allowlisted-debug-only":
            raise ContractError("browser map embeds source content against policy")
        if len(document["sourcesContent"]) != len(sources):
            raise ContractError("browser map sourcesContent length mismatch")
    source_root = document.get("sourceRoot", "")
    if source_root:
        if not isinstance(source_root, str):
            raise ContractError("browser map sourceRoot must be a string")
        sources = [posixpath.join(source_root, source) for source in sources]
    resolved = [resolve_v3_source(map_record["path"], source) for source in sources]
    expected = [record["path"] for record in source_records]
    if resolved != expected:
        raise ContractError(
            f"browser map source bindings disagree with index: {resolved!r} != {expected!r}"
        )
    generated_text = fixture_path(generated_record["path"]).read_text(encoding="utf-8")
    marker = f"sourceMappingURL={posixpath.basename(map_record['path'])}"
    if marker not in generated_text or "sourceMappingURL=data:" in generated_text:
        raise ContractError("generated browser file lacks an external relative map reference")


def canonical_artifact_set(files: list[dict[str, object]]) -> str:
    material = json.dumps(
        files, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode()
    return digest(material)


def validate_index(
    document: dict[str, object],
    validator: ClosedSchemaValidator,
    php_validator: ClosedSchemaValidator,
) -> None:
    validator.validate(document)
    files = document["files"]
    file_ids = [record["id"] for record in files]
    if file_ids != sorted(set(file_ids)):
        raise ContractError("source-index files must have sorted unique IDs")
    paths = [record["path"] for record in files]
    if len(paths) != len(set(paths)):
        raise ContractError("source-index file paths must be unique")
    files_by_id = {record["id"]: record for record in files}
    for record in files:
        require_safe_relative_path(record["path"], f"index file {record['id']}")
        validate_bound_file(
            record, fixture_path(record["path"]), f"index file {record['id']}"
        )
    if document["artifactSetSha256"] != canonical_artifact_set(files):
        raise ContractError("source-index artifact-set digest mismatch")

    roots = document["sourceRoots"]
    root_ids = [root["id"] for root in roots]
    if root_ids != sorted(set(root_ids)):
        raise ContractError("source roots must have sorted unique IDs")
    roots_by_id = {root["id"]: root for root in roots}
    for record in files:
        identity = record.get("sourceIdentity")
        if identity is None:
            continue
        root = roots_by_id.get(identity["rootId"])
        if root is None:
            raise ContractError(f"index file {record['id']}: unknown source root")
        if root["resolution"] == "debug-companion-relative":
            expected_path = posixpath.join(root["packagePath"], identity["path"])
            if record["path"] != expected_path:
                raise ContractError(
                    f"index file {record['id']}: source-root path mismatch"
                )

    retention = document["retention"]
    if not retention["mapsInProduction"]:
        if any(
            record["role"] == "source-map"
            and record["distribution"] == "production"
            for record in files
        ):
            raise ContractError("source map is marked for production distribution")
    if retention["sourceContentPolicy"] == "omitted":
        if any(
            record["role"] == "source"
            and record["distribution"] == "debug-companion"
            for record in files
        ):
            raise ContractError("source content is included against omitted policy")

    correlations = document["correlations"]
    correlation_ids = [correlation["id"] for correlation in correlations]
    if correlation_ids != sorted(set(correlation_ids)):
        raise ContractError("correlations must have sorted unique IDs")
    for correlation in correlations:
        entry = files_by_id.get(correlation["entryFileId"])
        if entry is None or entry["role"] != "runtime":
            raise ContractError(f"correlation {correlation['id']}: invalid exact entry ID")
        if correlation["strategy"] == "unavailable":
            continue
        layers = correlation["layers"]
        if [layer["order"] for layer in layers] != list(range(len(layers))):
            raise ContractError(f"correlation {correlation['id']}: non-contiguous layers")
        if layers[0]["generatedFileId"] != correlation["entryFileId"]:
            raise ContractError(f"correlation {correlation['id']}: first layer entry mismatch")
        for index, layer in enumerate(layers):
            map_record = files_by_id.get(layer["mapFileId"])
            generated_record = files_by_id.get(layer["generatedFileId"])
            source_records = [
                files_by_id.get(source_file_id)
                for source_file_id in layer["sourceFileIds"]
            ]
            if (
                map_record is None
                or map_record["role"] != "source-map"
                or generated_record is None
                or any(source is None for source in source_records)
            ):
                raise ContractError(f"correlation {correlation['id']}: unknown layer file ID")
            if generated_record["language"] != layer["generatedLanguage"]:
                raise ContractError(f"correlation {correlation['id']}: generated language mismatch")
            expected_source_languages = (
                {"typescript", "tsx"}
                if layer["sourceLanguage"] in {"typescript", "tsx"}
                else {"haxe"}
            )
            if any(
                source["language"] not in expected_source_languages
                for source in source_records
            ):
                raise ContractError(f"correlation {correlation['id']}: source language mismatch")

            if layer["format"] == "wordpresshx.php-haxe-range-map.v1":
                php_map = load_json(fixture_path(map_record["path"]))
                validate_php_map(php_map, php_validator)
                if php_map["generated"]["sha256"] != generated_record["sha256"]:
                    raise ContractError("PHP map/index generated-content binding mismatch")
                mapped_source_ids = {
                    (source["rootId"], source["path"], source["sha256"])
                    for source in php_map["sources"]
                }
                indexed_source_ids = {
                    (
                        source["sourceIdentity"]["rootId"],
                        source["sourceIdentity"]["path"],
                        source["sha256"],
                    )
                    for source in source_records
                }
                if mapped_source_ids != indexed_source_ids:
                    raise ContractError("PHP map/index source binding mismatch")
            elif layer["format"] == "source-map-v3":
                validate_source_map_v3(
                    map_record,
                    generated_record,
                    source_records,
                    retention["sourceContentPolicy"],
                )
            else:
                raise ContractError(f"correlation {correlation['id']}: unknown map format")

            if index + 1 < len(layers):
                next_generated = layers[index + 1]["generatedFileId"]
                if layer["sourceFileIds"] != [next_generated]:
                    raise ContractError(
                        f"correlation {correlation['id']}: layer continuity is ambiguous"
                    )

        expected_shape = {
            "php-range-map": ("php", 1, "php", "haxe"),
            "browser-composed-v3": ("browser", 1, "javascript", "haxe"),
            "browser-two-stage-v3": ("browser", 2, "javascript", "haxe"),
        }[correlation["strategy"]]
        if (
            correlation["target"],
            len(layers),
            layers[0]["generatedLanguage"],
            layers[-1]["sourceLanguage"],
        ) != expected_shape:
            raise ContractError(f"correlation {correlation['id']}: strategy shape mismatch")


def expect_invalid(
    label: str,
    validate: Callable[[dict[str, object]], None],
    base: dict[str, object],
    mutate: Callable[[dict[str, object]], None],
) -> None:
    candidate = copy.deepcopy(base)
    mutate(candidate)
    try:
        validate(candidate)
    except (ContractError, KeyError, OSError, UnicodeError, json.JSONDecodeError):
        return
    raise AssertionError(f"negative source-correlation contract did not fail: {label}")


def refresh_artifact_set(document: dict[str, object]) -> None:
    document["artifactSetSha256"] = canonical_artifact_set(document["files"])


def main() -> None:
    php_schema = load_json(PHP_SCHEMA_PATH)
    index_schema = load_json(INDEX_SCHEMA_PATH)
    for schema in (php_schema, index_schema):
        if schema["$schema"] != "https://json-schema.org/draft/2020-12/schema":
            raise ContractError("source-correlation schema draft changed")
        assert_closed_objects(schema)
    php_validator = ClosedSchemaValidator(php_schema)
    index_validator = ClosedSchemaValidator(index_schema)

    php_map = load_json(PHP_MAP_PATH)
    index = load_json(INDEX_PATH)
    validate_php_map(php_map, php_validator)
    validate_index(index, index_validator, php_validator)

    if exact_php_lookup(php_map, 80) != "mapping:fixture.failure.fail.throw":
        raise ContractError("exact PHP lookup did not select the smallest nested range")
    if php_line_lookup(php_map, 7) != "mapping:fixture.failure.fail.throw":
        raise ContractError("PHP line lookup did not use the explicit trace anchor")
    if php_line_lookup(php_map, 6) is not None:
        raise ContractError("PHP line lookup guessed without a trace anchor")

    validate_map = lambda value: validate_php_map(value, php_validator)
    validate_source_index = lambda value: validate_index(
        value, index_validator, php_validator
    )
    expect_invalid(
        "unknown PHP-map field",
        validate_map,
        php_map,
        lambda value: value.update({"absoluteRoot": "/tmp/project"}),
    )
    expect_invalid(
        "absolute generated path",
        validate_map,
        php_map,
        lambda value: value["generated"].update({"path": "/tmp/failure.php"}),
    )
    expect_invalid(
        "stale generated content hash",
        validate_map,
        php_map,
        lambda value: value["generated"].update({"sha256": "0" * 64}),
    )
    expect_invalid(
        "dishonest UTF-8 coordinate",
        validate_map,
        php_map,
        lambda value: value["mappings"][1]["generatedSpan"]["start"].update(
            {"columnUtf8": 2}
        ),
    )
    expect_invalid(
        "ambiguous trace line",
        validate_map,
        php_map,
        lambda value: value["traceAnchors"].append(
            {
                "generatedLine": 7,
                "mappingId": "mapping:fixture.failure.fail.declaration",
                "selection": "emitter-runtime-line",
            }
        ),
    )
    expect_invalid(
        "unknown index field",
        validate_source_index,
        index,
        lambda value: value.update({"lookupByBasename": True}),
    )
    expect_invalid(
        "basename-only entry lookup",
        validate_source_index,
        index,
        lambda value: value["correlations"][0].update(
            {"entryFileId": "composed.js"}
        ),
    )

    def break_chain(value: dict[str, object]) -> None:
        value["correlations"][1]["layers"][0]["sourceFileIds"] = [
            "file:haxe.fixture.failure"
        ]

    expect_invalid(
        "discontinuous browser chain", validate_source_index, index, break_chain
    )

    def ship_map_in_production(value: dict[str, object]) -> None:
        value["files"][1]["distribution"] = "production"
        refresh_artifact_set(value)

    expect_invalid(
        "production source-map retention",
        validate_source_index,
        index,
        ship_map_in_production,
    )

    def omit_included_source(value: dict[str, object]) -> None:
        value["retention"]["sourceContentPolicy"] = "omitted"

    expect_invalid(
        "source content included under omitted policy",
        validate_source_index,
        index,
        omit_included_source,
    )

    print(
        "source-correlation contracts passed: 2 closed schemas, "
        "3 correlation strategies, 10 fail-closed mutations"
    )


if __name__ == "__main__":
    main()
