#!/usr/bin/env python3
"""Validate ADR-006 semantic-plan and staged-emitter contracts."""

from __future__ import annotations

import copy
import hashlib
import json
import re
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
PLAN_SCHEMA_PATH = ROOT / "schemas" / "semantic-plan.schema.json"
EMISSION_SCHEMA_PATH = ROOT / "schemas" / "semantic-emission.schema.json"
PLAN_PATH = ROOT / "fixtures" / "semantic-plan" / "valid" / "minimal-plugin.json"
EMISSION_PATH = (
    ROOT
    / "fixtures"
    / "semantic-plan"
    / "valid"
    / "minimal-plugin.emission.json"
)
TOOLCHAIN_PATH = ROOT / "manifests" / "toolchain.lock.json"
EXPECTED_ARTIFACTS = {
    "dist/acme-observatory/acme-observatory.php": ROOT
    / "fixtures"
    / "semantic-plan"
    / "expected"
    / "acme-observatory.php.txt"
}
NODE_SCHEMAS = {
    "wordpress-hx.semantic-node.wordpress.module.v1": (
        "wordpress.module",
        ROOT / "schemas" / "semantic-nodes" / "module.schema.json",
    ),
    "wordpress-hx.semantic-node.wordpress.hook.v1": (
        "wordpress.hook",
        ROOT / "schemas" / "semantic-nodes" / "hook.schema.json",
    ),
}


class ContractError(ValueError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_value(value: object, location: str = "$") -> object:
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        raise ContractError(f"{location}: floating-point JSON values are forbidden")
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)
    if isinstance(value, list):
        return [
            normalize_value(item, f"{location}[{index}]")
            for index, item in enumerate(value)
        ]
    if isinstance(value, dict):
        normalized: dict[str, object] = {}
        for key, child in value.items():
            if not isinstance(key, str):
                raise ContractError(f"{location}: JSON object key is not a string")
            normalized_key = unicodedata.normalize("NFC", key)
            if normalized_key in normalized:
                raise ContractError(
                    f"{location}: duplicate key after Unicode normalization: {normalized_key}"
                )
            normalized[normalized_key] = normalize_value(
                child, f"{location}.{normalized_key}"
            )
        return normalized
    raise ContractError(f"{location}: unsupported JSON value {type(value).__name__}")


def canonical(value: object, *, newline: bool = False) -> bytes:
    normalized = normalize_value(value)
    encoded = json.dumps(
        normalized,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return encoded + (b"\n" if newline else b"")


def strict_json_bytes(data: bytes, label: str) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ContractError(f"{label}: duplicate JSON key {key}")
            result[key] = value
        return result

    def reject_float(value: str) -> object:
        raise ContractError(f"{label}: floating-point JSON value {value} is forbidden")

    def reject_constant(value: str) -> object:
        raise ContractError(f"{label}: non-finite JSON value {value} is forbidden")

    try:
        return json.loads(
            data,
            object_pairs_hook=pairs,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except UnicodeDecodeError as error:
        raise ContractError(f"{label}: JSON is not UTF-8") from error
    except json.JSONDecodeError as error:
        raise ContractError(f"{label}: malformed JSON: {error}") from error


def read_json(relative_or_absolute: Path, label: str) -> object:
    return strict_json_bytes(relative_or_absolute.read_bytes(), label)


def read_canonical(path: Path, label: str) -> dict[str, object]:
    data = path.read_bytes()
    value = strict_json_bytes(data, label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected JSON object")
    if data != canonical(value, newline=True):
        raise ContractError(f"{label}: file is not canonical JSON plus one LF")
    return value


class ClosedSchemaValidator:
    def __init__(self, schema: dict[str, object]) -> None:
        self.schema = schema

    def validate(
        self,
        value: object,
        schema: dict[str, object] | None = None,
        location: str = "$",
    ) -> None:
        current = schema or self.schema
        reference = current.get("$ref")
        if reference is not None:
            current = self.resolve(str(reference))

        if "const" in current and value != current["const"]:
            raise ContractError(
                f"{location}: expected constant {current['const']!r}, found {value!r}"
            )
        if "enum" in current and value not in current["enum"]:
            raise ContractError(
                f"{location}: {value!r} is not one of {current['enum']!r}"
            )

        expected_type = current.get("type")
        if expected_type is not None:
            self.require_type(value, str(expected_type), location)

        if isinstance(value, str):
            if len(value) < int(current.get("minLength", 0)):
                raise ContractError(f"{location}: string is too short")
            pattern = current.get("pattern")
            if pattern is not None and re.fullmatch(str(pattern), value) is None:
                raise ContractError(
                    f"{location}: {value!r} does not match {pattern!r}"
                )

        if isinstance(value, int) and not isinstance(value, bool):
            minimum = current.get("minimum")
            if minimum is not None and value < int(minimum):
                raise ContractError(
                    f"{location}: integer is below minimum {minimum}"
                )

        if isinstance(value, list):
            if len(value) < int(current.get("minItems", 0)):
                raise ContractError(f"{location}: array has too few items")
            if current.get("uniqueItems") is True:
                encoded = [canonical(item) for item in value]
                if len(encoded) != len(set(encoded)):
                    raise ContractError(f"{location}: array items are not unique")
            item_schema = current.get("items")
            if isinstance(item_schema, dict):
                for index, item in enumerate(value):
                    self.validate(item, item_schema, f"{location}[{index}]")

        if isinstance(value, dict):
            required = current.get("required", [])
            for field in required:
                if field not in value:
                    raise ContractError(
                        f"{location}: missing required field {field}"
                    )
            properties = current.get("properties", {})
            additional = current.get("additionalProperties")
            unknown = sorted(set(value) - set(properties))
            if additional is False and unknown:
                raise ContractError(
                    f"{location}: unknown field(s): {', '.join(unknown)}"
                )
            if isinstance(additional, dict):
                for field in unknown:
                    self.validate(value[field], additional, f"{location}.{field}")
            for field, child in value.items():
                field_schema = properties.get(field)
                if isinstance(field_schema, dict):
                    self.validate(child, field_schema, f"{location}.{field}")

    def resolve(self, reference: str) -> dict[str, object]:
        if not reference.startswith("#/"):
            raise ContractError(f"external schema reference is forbidden: {reference}")
        current: object = self.schema
        for component in reference[2:].split("/"):
            if not isinstance(current, dict) or component not in current:
                raise ContractError(f"unresolvable schema reference: {reference}")
            current = current[component]
        if not isinstance(current, dict):
            raise ContractError(f"schema reference is not an object: {reference}")
        return current

    @staticmethod
    def require_type(value: object, expected: str, location: str) -> None:
        matches = {
            "object": isinstance(value, dict),
            "array": isinstance(value, list),
            "string": isinstance(value, str),
            "integer": isinstance(value, int) and not isinstance(value, bool),
            "boolean": isinstance(value, bool),
        }.get(expected)
        if matches is None:
            raise ContractError(
                f"{location}: validator does not support schema type {expected}"
            )
        if not matches:
            raise ContractError(
                f"{location}: expected {expected}, found {type(value).__name__}"
            )


def require_closed_schema(
    value: object, location: str = "$schema", *, allow_open_payload: bool = False
) -> None:
    if isinstance(value, dict):
        if value.get("type") == "object" and value.get("additionalProperties") is not False:
            if not (
                allow_open_payload
                and location == "$schema.$defs.node.properties.payload"
                and value.get("additionalProperties") is True
            ):
                raise ContractError(f"{location}: object schema is not closed")
        for key, child in value.items():
            require_closed_schema(
                child,
                f"{location}.{key}",
                allow_open_payload=allow_open_payload,
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            require_closed_schema(
                child,
                f"{location}[{index}]",
                allow_open_payload=allow_open_payload,
            )


def require_safe_relative(value: str, label: str) -> None:
    pure = PurePosixPath(value)
    if (
        not value
        or value.startswith("/")
        or "\\" in value
        or pure.is_absolute()
        or any(part in ("", ".", "..") for part in pure.parts)
        or pure.as_posix() != value
    ):
        raise ContractError(f"{label}: path is not normalized project-relative POSIX")


def require_sorted_unique(values: list[object], key: Callable[[object], object], label: str) -> None:
    keys = [key(value) for value in values]
    if keys != sorted(keys):
        raise ContractError(f"{label}: values are not in canonical order")
    if len(keys) != len(set(keys)):
        raise ContractError(f"{label}: duplicate value")


def normalize_plan(value: dict[str, object]) -> dict[str, object]:
    result = copy.deepcopy(value)
    result["nodeSchemas"] = sorted(
        result["nodeSchemas"], key=lambda item: item["schemaId"]
    )
    for registry in result["nodeSchemas"]:
        registry["consumerEmitters"] = sorted(registry["consumerEmitters"])
    result["nodes"] = sorted(result["nodes"], key=lambda item: item["id"])
    for node in result["nodes"]:
        node["relatedSources"] = sorted(
            node["relatedSources"],
            key=lambda span: (
                span["path"],
                span["start"]["offset"],
                span["end"]["offset"],
                span["symbol"],
            ),
        )
        node["dependsOn"] = sorted(node["dependsOn"])
        node["profileCapabilities"] = sorted(node["profileCapabilities"])
        node["projections"] = sorted(
            node["projections"], key=lambda item: item["projectionId"]
        )
    return normalize_value(result)  # type: ignore[return-value]


def normalize_emission(value: dict[str, object]) -> dict[str, object]:
    result = copy.deepcopy(value)
    coverage = result["coverage"]
    coverage["requestedProjectionIds"] = sorted(coverage["requestedProjectionIds"])
    coverage["emittedProjectionIds"] = sorted(coverage["emittedProjectionIds"])
    result["artifacts"] = sorted(result["artifacts"], key=lambda item: item["path"])
    for artifact in result["artifacts"]:
        artifact["sourceNodeIds"] = sorted(artifact["sourceNodeIds"])
        artifact["sourceSpans"] = sorted(
            artifact["sourceSpans"],
            key=lambda span: (
                span["path"],
                span["start"]["offset"],
                span["end"]["offset"],
                span["symbol"],
            ),
        )
        artifact["validators"] = sorted(artifact["validators"])
    result["diagnostics"] = sorted(
        result["diagnostics"],
        key=lambda item: (
            item["severity"],
            item["code"],
            item["nodeId"],
            item["source"]["path"],
            item["source"]["start"]["offset"],
        ),
    )
    return normalize_value(result)  # type: ignore[return-value]


def digest_without(value: dict[str, object], field: str, normalizer: Callable[[dict[str, object]], dict[str, object]]) -> str:
    material = normalizer(value)
    material.pop(field, None)
    return sha256(canonical(material))


def redigest_plan(value: dict[str, object]) -> dict[str, object]:
    result = normalize_plan(value)
    result["planDigest"] = digest_without(result, "planDigest", normalize_plan)
    return result


def redigest_emission(value: dict[str, object]) -> dict[str, object]:
    result = normalize_emission(value)
    result["resultDigest"] = digest_without(
        result, "resultDigest", normalize_emission
    )
    return result


def reject_placeholder_digests(value: object, location: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            reject_placeholder_digests(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_placeholder_digests(child, f"{location}[{index}]")
    elif isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value):
        if len(set(value)) == 1:
            raise ContractError(f"{location}: placeholder digest is forbidden")


def point_for(data: bytes, offset: int) -> dict[str, int]:
    before = data[:offset]
    return {
        "offset": offset,
        "line": before.count(b"\n") + 1,
        "column": len(before.rsplit(b"\n", 1)[-1]),
    }


def validate_source_span(span: dict[str, object], label: str) -> None:
    relative = str(span["path"])
    require_safe_relative(relative, f"{label}.path")
    source_path = ROOT / relative
    if not source_path.is_file():
        raise ContractError(f"{label}.path: source file does not exist")
    data = source_path.read_bytes()
    if sha256(data) != span["sourceSha256"]:
        raise ContractError(f"{label}.sourceSha256: source digest mismatch")
    start = span["start"]
    end = span["end"]
    if start["offset"] >= end["offset"] or end["offset"] > len(data):
        raise ContractError(f"{label}: source span is empty, reversed, or out of range")
    if point_for(data, start["offset"]) != start:
        raise ContractError(f"{label}.start: line/column do not match UTF-8 bytes")
    if point_for(data, end["offset"]) != end:
        raise ContractError(f"{label}.end: line/column do not match UTF-8 bytes")


def detect_cycles(nodes: dict[str, dict[str, object]]) -> None:
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node_id: str) -> None:
        if node_id in visiting:
            raise ContractError(f"$.nodes: dependency cycle reaches {node_id}")
        if node_id in visited:
            return
        visiting.add(node_id)
        for dependency in nodes[node_id]["dependsOn"]:
            visit(str(dependency))
        visiting.remove(node_id)
        visited.add(node_id)

    for node_id in nodes:
        visit(node_id)


def validate_plan(
    plan: dict[str, object],
    schema: dict[str, object],
    *,
    canonical_file: bytes | None = None,
) -> None:
    ClosedSchemaValidator(schema).validate(plan)
    reject_placeholder_digests(plan)
    if canonical_file is not None and canonical_file != canonical(plan, newline=True):
        raise ContractError("semantic plan file is not canonical JSON plus one LF")
    if canonical(plan) != canonical(normalize_plan(plan)):
        raise ContractError("semantic plan set fields are not in canonical order")
    expected_digest = digest_without(plan, "planDigest", normalize_plan)
    if plan["planDigest"] != expected_digest:
        raise ContractError("$.planDigest: canonical digest mismatch")
    if plan["generator"]["collectorSourceSha256"] != sha256(
        Path(__file__).read_bytes()
    ):
        raise ContractError(
            "$.generator.collectorSourceSha256: contract collector digest mismatch"
        )
    if plan["generator"]["toolchainSha256"] != sha256(TOOLCHAIN_PATH.read_bytes()):
        raise ContractError("$.generator.toolchainSha256: toolchain lock mismatch")

    profile = plan["profile"]
    if not str(profile["catalogRevision"]).startswith(f"{profile['profileId']}/"):
        raise ContractError("$.profile.catalogRevision: profile identity mismatch")
    catalog_path = (
        ROOT
        / "generated"
        / str(profile["profileId"])
        / str(profile["catalogRevision"]).split("/", 1)[1]
        / "catalog.json"
    )
    catalog = read_json(catalog_path, "exact profile catalog")
    if profile["catalogSha256"] != catalog["catalogDigest"]:
        raise ContractError("$.profile.catalogSha256: exact catalog digest mismatch")
    capabilities = {
        capability["capabilityId"] for capability in catalog["catalog"]["capabilities"]
    }

    registry_items = plan["nodeSchemas"]
    require_sorted_unique(registry_items, lambda item: item["schemaId"], "$.nodeSchemas")
    registry = {item["schemaId"]: item for item in registry_items}
    for index, item in enumerate(registry_items):
        emitters = item["consumerEmitters"]
        require_sorted_unique(emitters, lambda emitter: emitter, f"$.nodeSchemas[{index}].consumerEmitters")
        if item["authority"] == "core" and "extensionId" in item:
            raise ContractError(f"$.nodeSchemas[{index}]: core schema has extensionId")
        if item["authority"] == "extension" and "extensionId" not in item:
            raise ContractError(f"$.nodeSchemas[{index}]: extension schema lacks extensionId")
        schema_id = str(item["schemaId"])
        if schema_id not in NODE_SCHEMAS:
            raise ContractError(f"$.nodeSchemas[{index}]: unregistered schema {schema_id}")
        expected_kind, schema_path = NODE_SCHEMAS[schema_id]
        if item["kind"] != expected_kind:
            raise ContractError(f"$.nodeSchemas[{index}]: schema kind mismatch")
        if not schema_id.endswith(f".v{item['version']}"):
            raise ContractError(f"$.nodeSchemas[{index}]: schema version mismatch")
        if item["schemaSha256"] != sha256(schema_path.read_bytes()):
            raise ContractError(f"$.nodeSchemas[{index}]: schema digest mismatch")

    node_items = plan["nodes"]
    require_sorted_unique(node_items, lambda item: item["id"], "$.nodes")
    nodes = {item["id"]: item for item in node_items}
    source_files: dict[str, str] = {}
    projection_ids: set[str] = set()
    for index, node in enumerate(node_items):
        node_label = f"$.nodes[{index}]"
        schema_id = str(node["schemaId"])
        if schema_id not in registry:
            raise ContractError(f"{node_label}.schemaId: schema is not declared")
        registration = registry[schema_id]
        if node["kind"] != registration["kind"]:
            raise ContractError(f"{node_label}.kind: registration mismatch")
        _, schema_path = NODE_SCHEMAS[schema_id]
        payload_schema = read_json(schema_path, f"node schema {schema_id}")
        ClosedSchemaValidator(payload_schema).validate(
            node["payload"], location=f"{node_label}.payload"
        )
        for source_index, span in enumerate([node["source"], *node["relatedSources"]]):
            span_label = f"{node_label}.sources[{source_index}]"
            validate_source_span(span, span_label)
            previous = source_files.setdefault(span["path"], span["sourceSha256"])
            if previous != span["sourceSha256"]:
                raise ContractError(f"{span_label}: conflicting source digest")
        require_sorted_unique(
            node["relatedSources"],
            lambda span: (
                span["path"],
                span["start"]["offset"],
                span["end"]["offset"],
                span["symbol"],
            ),
            f"{node_label}.relatedSources",
        )
        require_sorted_unique(node["dependsOn"], lambda item: item, f"{node_label}.dependsOn")
        for dependency in node["dependsOn"]:
            if dependency not in nodes:
                raise ContractError(f"{node_label}.dependsOn: unknown node {dependency}")
            if dependency == node["id"]:
                raise ContractError(f"{node_label}.dependsOn: self dependency")
        require_sorted_unique(
            node["profileCapabilities"],
            lambda item: item,
            f"{node_label}.profileCapabilities",
        )
        unknown_capabilities = sorted(set(node["profileCapabilities"]) - capabilities)
        if unknown_capabilities:
            raise ContractError(
                f"{node_label}.profileCapabilities: unknown exact-profile capability {unknown_capabilities[0]}"
            )
        require_sorted_unique(
            node["projections"],
            lambda item: item["projectionId"],
            f"{node_label}.projections",
        )
        for projection in node["projections"]:
            if projection["projectionId"] in projection_ids:
                raise ContractError(
                    f"{node_label}.projections: duplicate global projectionId {projection['projectionId']}"
                )
            projection_ids.add(projection["projectionId"])
            if projection["emitterId"] not in registration["consumerEmitters"]:
                raise ContractError(
                    f"{node_label}.projections: emitter is not registered for node schema"
                )
    detect_cycles(nodes)

    source_material = [
        {"path": relative, "sha256": source_files[relative]}
        for relative in sorted(source_files)
    ]
    if plan["project"]["sourceTreeSha256"] != sha256(canonical(source_material)):
        raise ContractError("$.project.sourceTreeSha256: effective source tree mismatch")


def validate_emission(
    emission: dict[str, object],
    schema: dict[str, object],
    plan: dict[str, object],
    *,
    canonical_file: bytes | None = None,
) -> None:
    ClosedSchemaValidator(schema).validate(emission)
    reject_placeholder_digests(emission)
    if canonical_file is not None and canonical_file != canonical(emission, newline=True):
        raise ContractError("emission result file is not canonical JSON plus one LF")
    if canonical(emission) != canonical(normalize_emission(emission)):
        raise ContractError("emission result set fields are not in canonical order")
    expected_digest = digest_without(
        emission, "resultDigest", normalize_emission
    )
    if emission["resultDigest"] != expected_digest:
        raise ContractError("$.resultDigest: canonical digest mismatch")
    if emission["planDigest"] != plan["planDigest"]:
        raise ContractError("$.planDigest: result does not bind the plan")

    emitter_id = emission["emitter"]["emitterId"]
    requested = sorted(
        projection["projectionId"]
        for node in plan["nodes"]
        for projection in node["projections"]
        if projection["emitterId"] == emitter_id
    )
    coverage = emission["coverage"]
    if coverage["requestedProjectionIds"] != requested:
        raise ContractError("$.coverage.requestedProjectionIds: plan coverage mismatch")
    if coverage["emittedProjectionIds"] != requested:
        raise ContractError("$.coverage.emittedProjectionIds: incomplete emitter coverage")

    nodes = {node["id"]: node for node in plan["nodes"]}
    projection_owner = {
        projection["projectionId"]: node["id"]
        for node in plan["nodes"]
        for projection in node["projections"]
        if projection["emitterId"] == emitter_id
    }
    traced_nodes: set[str] = set()
    seen_paths: set[str] = set()
    seen_folded_paths: set[str] = set()
    for index, artifact in enumerate(emission["artifacts"]):
        artifact_label = f"$.artifacts[{index}]"
        relative = str(artifact["path"])
        require_safe_relative(relative, f"{artifact_label}.path")
        if relative in seen_paths or relative.casefold() in seen_folded_paths:
            raise ContractError(f"{artifact_label}.path: duplicate or case-fold collision")
        seen_paths.add(relative)
        seen_folded_paths.add(relative.casefold())
        expected_path = EXPECTED_ARTIFACTS.get(relative)
        if expected_path is None:
            raise ContractError(f"{artifact_label}.path: no staged contract fixture")
        content = expected_path.read_bytes()
        if artifact["contentSha256"] != sha256(content):
            raise ContractError(f"{artifact_label}.contentSha256: content digest mismatch")
        if artifact["sizeBytes"] != len(content):
            raise ContractError(f"{artifact_label}.sizeBytes: content size mismatch")
        if artifact["ownerNodeId"] not in nodes:
            raise ContractError(f"{artifact_label}.ownerNodeId: unknown node")
        require_sorted_unique(
            artifact["sourceNodeIds"], lambda item: item, f"{artifact_label}.sourceNodeIds"
        )
        for source_node_id in artifact["sourceNodeIds"]:
            if source_node_id not in nodes:
                raise ContractError(f"{artifact_label}.sourceNodeIds: unknown node")
            traced_nodes.add(source_node_id)
        allowed_spans = {
            canonical(span)
            for source_node_id in artifact["sourceNodeIds"]
            for span in [
                nodes[source_node_id]["source"],
                *nodes[source_node_id]["relatedSources"],
            ]
        }
        require_sorted_unique(
            artifact["sourceSpans"],
            lambda span: (
                span["path"],
                span["start"]["offset"],
                span["end"]["offset"],
                span["symbol"],
            ),
            f"{artifact_label}.sourceSpans",
        )
        for span in artifact["sourceSpans"]:
            validate_source_span(span, f"{artifact_label}.sourceSpans")
            if canonical(span) not in allowed_spans:
                raise ContractError(f"{artifact_label}.sourceSpans: unbound source span")
        require_sorted_unique(
            artifact["validators"], lambda item: item, f"{artifact_label}.validators"
        )

    missing_trace = sorted(set(projection_owner.values()) - traced_nodes)
    if missing_trace:
        raise ContractError(
            f"$.artifacts: projection owner lacks artifact trace: {missing_trace[0]}"
        )


def expect_failure(label: str, action: Callable[[], None], expected: str) -> None:
    try:
        action()
    except ContractError as error:
        if expected not in str(error):
            raise AssertionError(
                f"{label}: expected {expected!r}, found {str(error)!r}"
            ) from error
        return
    raise AssertionError(f"{label}: mutation unexpectedly passed")


def main() -> None:
    plan_schema = read_json(PLAN_SCHEMA_PATH, "semantic-plan schema")
    emission_schema = read_json(EMISSION_SCHEMA_PATH, "semantic-emission schema")
    require_closed_schema(plan_schema, allow_open_payload=True)
    require_closed_schema(emission_schema)
    for schema_id, (_, schema_path) in NODE_SCHEMAS.items():
        node_schema = read_json(schema_path, f"node schema {schema_id}")
        require_closed_schema(node_schema)
        if node_schema["$id"] != schema_id:
            raise ContractError(f"node schema identity mismatch: {schema_id}")

    plan_bytes = PLAN_PATH.read_bytes()
    plan = read_canonical(PLAN_PATH, "semantic plan")
    validate_plan(plan, plan_schema, canonical_file=plan_bytes)
    emission_bytes = EMISSION_PATH.read_bytes()
    emission = read_canonical(EMISSION_PATH, "emission result")
    validate_emission(
        emission,
        emission_schema,
        plan,
        canonical_file=emission_bytes,
    )

    canonical_vectors = 0
    permuted = copy.deepcopy(plan)
    permuted["nodeSchemas"].reverse()
    permuted["nodes"].reverse()
    for node in permuted["nodes"]:
        node["dependsOn"].reverse()
        node["profileCapabilities"].reverse()
        node["projections"].reverse()
    if canonical(redigest_plan(permuted), newline=True) != plan_bytes:
        raise AssertionError("declared set permutations did not normalize identically")
    canonical_vectors += 1
    if canonical({"b": 2, "a": 1}) != canonical({"a": 1, "b": 2}):
        raise AssertionError("object insertion order changed canonical bytes")
    canonical_vectors += 1
    if canonical("Cafe\u0301") != canonical("Café"):
        raise AssertionError("Unicode NFC normalization changed canonical identity")
    canonical_vectors += 1
    if canonical({"sequence": [2, 1]}) == canonical({"sequence": [1, 2]}):
        raise AssertionError("canonical JSON reordered a semantic sequence")
    canonical_vectors += 1
    expect_failure(
        "duplicate JSON key",
        lambda: strict_json_bytes(b'{"a":1,"a":2}', "duplicate vector"),
        "duplicate JSON key",
    )
    canonical_vectors += 1
    expect_failure(
        "floating JSON value",
        lambda: strict_json_bytes(b'{"value":1.5}', "float vector"),
        "floating-point JSON value",
    )
    canonical_vectors += 1

    negative_count = 0

    def plan_negative(
        label: str,
        mutation: Callable[[dict[str, object]], None],
        expected: str,
        *,
        redigest: bool = True,
    ) -> None:
        nonlocal negative_count
        value = copy.deepcopy(plan)
        mutation(value)
        if redigest:
            value = redigest_plan(value)
        expect_failure(
            label,
            lambda: validate_plan(value, plan_schema),
            expected,
        )
        negative_count += 1

    plan_negative(
        "unknown envelope field",
        lambda value: value.update({"surprise": True}),
        "unknown field",
        redigest=False,
    )
    plan_negative(
        "absolute source path",
        lambda value: value["nodes"][0]["source"].update({"path": "/tmp/source.hx"}),
        "does not match",
    )
    plan_negative(
        "traversal source path",
        lambda value: value["nodes"][0]["source"].update({"path": "../source.hx"}),
        "not normalized project-relative",
    )
    plan_negative(
        "backslash source path",
        lambda value: value["nodes"][0]["source"].update({"path": "src\\source.hx"}),
        "does not match",
    )
    plan_negative(
        "duplicate node id",
        lambda value: value["nodes"].append(copy.deepcopy(value["nodes"][0])),
        "duplicate value",
    )
    plan_negative(
        "missing dependency",
        lambda value: value["nodes"][1].update({"dependsOn": ["module/missing"]}),
        "unknown node",
    )

    def add_cycle(value: dict[str, object]) -> None:
        value["nodes"][0]["dependsOn"] = [value["nodes"][1]["id"]]
        value["nodes"][1]["dependsOn"] = [value["nodes"][0]["id"]]

    plan_negative("dependency cycle", add_cycle, "dependency cycle")
    plan_negative(
        "unknown node schema",
        lambda value: value["nodes"][0].update(
            {"schemaId": "wordpress-hx.semantic-node.wordpress.missing.v1"}
        ),
        "schema is not declared",
    )

    def corrupt_schema_digest(value: dict[str, object]) -> None:
        digest = value["nodeSchemas"][0]["schemaSha256"]
        value["nodeSchemas"][0]["schemaSha256"] = (
            ("0" if digest[0] != "0" else "1") + digest[1:]
        )

    plan_negative("schema digest mismatch", corrupt_schema_digest, "schema digest mismatch")
    plan_negative(
        "payload broadening",
        lambda value: value["nodes"][0]["payload"].update({"dynamic": True}),
        "unknown field",
    )
    plan_negative(
        "unknown profile capability",
        lambda value: value["nodes"][0].update(
            {"profileCapabilities": ["wordpress.php.function.missing"]}
        ),
        "unknown exact-profile capability",
    )
    plan_negative(
        "unregistered emitter",
        lambda value: value["nodes"][0]["projections"][0].update(
            {"emitterId": "wordpress.unknown"}
        ),
        "emitter is not registered",
    )

    def duplicate_projection(value: dict[str, object]) -> None:
        value["nodes"][1]["projections"][0]["projectionId"] = value["nodes"][0][
            "projections"
        ][0]["projectionId"]

    plan_negative("duplicate projection", duplicate_projection, "duplicate global projectionId")

    def corrupt_source_digest(value: dict[str, object]) -> None:
        digest = value["nodes"][0]["source"]["sourceSha256"]
        value["nodes"][0]["source"]["sourceSha256"] = (
            ("0" if digest[0] != "0" else "1") + digest[1:]
        )

    plan_negative("source digest mismatch", corrupt_source_digest, "source digest mismatch")
    plan_negative(
        "source coordinate mismatch",
        lambda value: value["nodes"][0]["source"]["start"].update({"line": 99}),
        "line/column do not match",
    )
    plan_negative(
        "plan digest tamper",
        lambda value: value.update({"planDigest": "1" + value["planDigest"][1:]}),
        "canonical digest mismatch",
        redigest=False,
    )

    def emission_negative(
        label: str,
        mutation: Callable[[dict[str, object]], None],
        expected: str,
        *,
        redigest: bool = True,
    ) -> None:
        nonlocal negative_count
        value = copy.deepcopy(emission)
        mutation(value)
        if redigest:
            value = redigest_emission(value)
        expect_failure(
            label,
            lambda: validate_emission(value, emission_schema, plan),
            expected,
        )
        negative_count += 1

    emission_negative(
        "missing projection coverage",
        lambda value: value["coverage"].update(
            {"emittedProjectionIds": value["coverage"]["emittedProjectionIds"][:-1]}
        ),
        "incomplete emitter coverage",
    )
    emission_negative(
        "artifact traversal",
        lambda value: value["artifacts"][0].update({"path": "../artifact.php"}),
        "not normalized project-relative",
    )

    def corrupt_artifact_digest(value: dict[str, object]) -> None:
        digest = value["artifacts"][0]["contentSha256"]
        value["artifacts"][0]["contentSha256"] = (
            ("0" if digest[0] != "0" else "1") + digest[1:]
        )

    emission_negative("artifact digest mismatch", corrupt_artifact_digest, "content digest mismatch")
    emission_negative(
        "unknown trace node",
        lambda value: value["artifacts"][0].update(
            {"sourceNodeIds": ["module/missing"]}
        ),
        "unknown node",
    )
    emission_negative(
        "result digest tamper",
        lambda value: value.update(
            {"resultDigest": "1" + value["resultDigest"][1:]}
        ),
        "canonical digest mismatch",
        redigest=False,
    )

    summary = {
        "artifactCount": len(emission["artifacts"]),
        "canonicalVectorCount": canonical_vectors,
        "emitterCount": 1,
        "negativeMutationCount": negative_count,
        "nodeCount": len(plan["nodes"]),
        "nodeSchemaCount": len(plan["nodeSchemas"]),
        "planDigest": plan["planDigest"],
        "projectionCount": len(emission["coverage"]["requestedProjectionIds"]),
        "resultDigest": emission["resultDigest"],
    }
    print("SEMANTIC_PLAN_SUMMARY=" + canonical(summary).decode("utf-8"))


if __name__ == "__main__":
    main()
