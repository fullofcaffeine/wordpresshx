#!/usr/bin/env python3
"""Validate ADR-016 project, effective-input, and CLI event contracts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import stat
import tempfile
import unicodedata
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "fixtures" / "project-cli"
PROJECT_ROOT = FIXTURE_ROOT / "project"
CONFIG_PATH = PROJECT_ROOT / "wordpress-hx.json"
LOCK_PATH = PROJECT_ROOT / ".wphx" / "project.lock.json"
EFFECTIVE_PATH = FIXTURE_ROOT / "valid" / "effective-inputs.json"
DEV_EVENTS_PATH = FIXTURE_ROOT / "valid" / "dev.events.jsonl"
DRY_RUN_EVENTS_PATH = FIXTURE_ROOT / "valid" / "build-dry-run.events.jsonl"
SCHEMAS = {
    "project": ROOT / "schemas" / "project.schema.json",
    "lock": ROOT / "schemas" / "project-lock.schema.json",
    "effective": ROOT / "schemas" / "effective-inputs.schema.json",
    "event": ROOT / "schemas" / "cli-event.schema.json",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PORTABLE_SEGMENT_RE = re.compile(r"^[A-Za-z0-9._@+-]+$")
EXACT_VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$")
WINDOWS_RESERVED = {
    "aux",
    "clock$",
    "con",
    "nul",
    "prn",
    *(f"com{number}" for number in range(1, 10)),
    *(f"lpt{number}" for number in range(1, 10)),
}
REQUIRED_COMPONENTS = {
    "compiler.genes",
    "compiler.haxe",
    "compiler.reflaxe-php",
    "runtime.node",
    "sdk.wordpress-hx",
    "tool.lix",
    "tool.npm",
    "tool.wordpress-scripts",
}
COMPILER_COMPATIBILITY_COMPONENTS = [
    "compiler.genes",
    "compiler.haxe",
    "compiler.reflaxe-php",
    "sdk.wordpress-hx",
    "tool.lix",
]
BUILD_STAGES = [
    "configuration",
    "profile-resolution",
    "haxe-typing-and-plan",
    "php-emission",
    "browser-emission",
    "metadata-emission",
    "format-and-static-check",
    "asset-build",
    "artifact-validation",
    "ownership-publish",
]


class ContractError(ValueError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize(value: object, location: str = "$") -> object:
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        raise ContractError(f"{location}: floating-point JSON values are forbidden")
    if isinstance(value, str):
        normalized = unicodedata.normalize("NFC", value)
        if normalized != value:
            raise ContractError(f"{location}: string is not NFC")
        return value
    if isinstance(value, list):
        return [normalize(child, f"{location}[{index}]") for index, child in enumerate(value)]
    if isinstance(value, dict):
        result: dict[str, object] = {}
        for key, child in value.items():
            if not isinstance(key, str):
                raise ContractError(f"{location}: object key is not a string")
            normalized_key = unicodedata.normalize("NFC", key)
            if normalized_key != key:
                raise ContractError(f"{location}: object key is not NFC")
            if key in result:
                raise ContractError(f"{location}: duplicate object key {key}")
            result[key] = normalize(child, f"{location}.{key}")
        return result
    raise ContractError(f"{location}: unsupported JSON value {type(value).__name__}")


def canonical(value: object, *, newline: bool = False) -> bytes:
    data = json.dumps(
        normalize(value),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return data + (b"\n" if newline else b"")


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
        result = json.loads(
            data,
            object_pairs_hook=pairs,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except UnicodeDecodeError as error:
        raise ContractError(f"{label}: JSON is not UTF-8") from error
    except json.JSONDecodeError as error:
        raise ContractError(f"{label}: malformed JSON: {error}") from error
    return normalize(result, label)


def read_json(path: Path, label: str) -> dict[str, object]:
    value = strict_json_bytes(path.read_bytes(), label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected a JSON object")
    return value


def read_canonical(path: Path, label: str) -> dict[str, object]:
    data = path.read_bytes()
    value = strict_json_bytes(data, label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected a JSON object")
    if data != canonical(value, newline=True):
        raise ContractError(f"{label}: expected canonical JSON plus one LF")
    return value


class ClosedSchemaValidator:
    def __init__(self, schema: dict[str, object]) -> None:
        self.schema = schema

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
            raise ContractError(f"{location}: expected constant {current['const']!r}")
        if "enum" in current and value not in current["enum"]:
            raise ContractError(f"{location}: value {value!r} is outside the enum")

        expected_type = current.get("type")
        if expected_type is not None:
            matches = {
                "object": isinstance(value, dict),
                "array": isinstance(value, list),
                "string": isinstance(value, str),
                "integer": isinstance(value, int) and not isinstance(value, bool),
                "boolean": isinstance(value, bool),
            }.get(str(expected_type))
            if matches is None:
                raise ContractError(f"{location}: unsupported schema type {expected_type}")
            if not matches:
                raise ContractError(f"{location}: expected {expected_type}")

        if isinstance(value, str):
            if len(value) < int(current.get("minLength", 0)):
                raise ContractError(f"{location}: string is too short")
            pattern = current.get("pattern")
            if pattern is not None and re.fullmatch(str(pattern), value) is None:
                raise ContractError(f"{location}: value does not match {pattern!r}")

        if isinstance(value, int) and not isinstance(value, bool):
            minimum = current.get("minimum")
            if minimum is not None and value < int(minimum):
                raise ContractError(f"{location}: integer is below {minimum}")

        if isinstance(value, list):
            if len(value) < int(current.get("minItems", 0)):
                raise ContractError(f"{location}: array has too few items")
            if current.get("uniqueItems") is True:
                encoded = [canonical(child) for child in value]
                if len(encoded) != len(set(encoded)):
                    raise ContractError(f"{location}: array items are not unique")
            item_schema = current.get("items")
            if isinstance(item_schema, dict):
                for index, child in enumerate(value):
                    self.validate(child, item_schema, f"{location}[{index}]")

        if isinstance(value, dict):
            properties = current.get("properties", {})
            if not isinstance(properties, dict):
                raise ContractError(f"{location}: schema properties are malformed")
            for field in current.get("required", []):
                if field not in value:
                    raise ContractError(f"{location}: missing required field {field}")
            unknown = sorted(set(value) - set(properties))
            additional = current.get("additionalProperties")
            if additional is False and unknown:
                raise ContractError(f"{location}: unknown fields: {', '.join(unknown)}")
            for field, child in value.items():
                child_schema = properties.get(field)
                if isinstance(child_schema, dict):
                    self.validate(child, child_schema, f"{location}.{field}")


def require_closed_schema(value: object, location: str = "$schema") -> None:
    if isinstance(value, dict):
        if value.get("type") == "object" and value.get("additionalProperties") is not False:
            raise ContractError(f"{location}: object schema is not closed")
        for key, child in value.items():
            require_closed_schema(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            require_closed_schema(child, f"{location}[{index}]")


def validate_path(value: str, label: str, *, allow_root: bool = False) -> str:
    if value == "." and allow_root:
        return value
    if not value or value != unicodedata.normalize("NFC", value):
        raise ContractError(f"{label}: path is empty or not NFC")
    if value.startswith("/") or "\\" in value or "\x00" in value:
        raise ContractError(f"{label}: absolute, backslash, or NUL path is forbidden")
    parts = value.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise ContractError(f"{label}: empty, dot, or traversal segment is forbidden")
    for part in parts:
        if PORTABLE_SEGMENT_RE.fullmatch(part) is None:
            raise ContractError(f"{label}: non-portable path segment {part!r}")
        if part.endswith((".", " ")):
            raise ContractError(f"{label}: trailing dot or space is forbidden")
        if part.split(".", 1)[0].casefold() in WINDOWS_RESERVED:
            raise ContractError(f"{label}: reserved device segment {part!r}")
    return value


def nested(left: str, right: str) -> bool:
    left_parts = PurePosixPath(left).parts
    right_parts = PurePosixPath(right).parts
    return len(left_parts) < len(right_parts) and right_parts[: len(left_parts)] == left_parts


def require_sorted_unique(values: list[object], label: str, key=lambda child: child) -> None:
    keys = [key(child) for child in values]
    if keys != sorted(keys):
        raise ContractError(f"{label}: values are not sorted")
    if len(keys) != len(set(keys)):
        raise ContractError(f"{label}: duplicate values")


def digest_without(value: dict[str, object], field: str) -> str:
    clone = copy.deepcopy(value)
    clone.pop(field, None)
    return sha256(canonical(clone))


def component_digest(component: dict[str, object]) -> str:
    return digest_without(component, "lockEntrySha256")


def validate_config(
    config: dict[str, object], validator: ClosedSchemaValidator, project_root: Path
) -> None:
    validator.validate(config)
    paths = config["paths"]
    assert isinstance(paths, dict)
    source_roots = paths["sourceRoots"]
    test_roots = paths["testRoots"]
    asset_roots = paths["assetRoots"]
    output_roots = paths["outputRoots"]
    assert isinstance(source_roots, list)
    assert isinstance(test_roots, list)
    assert isinstance(asset_roots, list)
    assert isinstance(output_roots, list)

    for label, roots in (
        ("sourceRoots", source_roots),
        ("testRoots", test_roots),
        ("assetRoots", asset_roots),
    ):
        require_sorted_unique(roots, f"config.{label}")
        for index, root in enumerate(roots):
            validate_path(str(root), f"config.{label}[{index}]")

    require_sorted_unique(output_roots, "config.outputRoots", lambda item: item["id"])
    output_paths: list[str] = []
    for index, output in enumerate(output_roots):
        assert isinstance(output, dict)
        output_path = validate_path(str(output["path"]), f"config.outputRoots[{index}].path")
        output_paths.append(output_path)
    require_sorted_unique(output_paths, "config output paths")
    for index, left in enumerate(output_paths):
        for right in output_paths[index + 1 :]:
            if nested(left, right) or nested(right, left):
                raise ContractError("config output roots may not nest")

    distribution = validate_path(str(paths["distributionRoot"]), "config.distributionRoot")
    state = validate_path(str(paths["stateRoot"]), "config.stateRoot")
    authored_roots = [str(value) for value in source_roots + test_roots + asset_roots]
    generated_roots = output_paths + [distribution, state]
    for authored in authored_roots:
        for generated in generated_roots:
            if authored == generated or nested(authored, generated) or nested(generated, authored):
                raise ContractError("authored and generated/state roots must be disjoint")
    if distribution == state or nested(distribution, state) or nested(state, distribution):
        raise ContractError("distribution and state roots must be disjoint")

    toolchain = config["toolchain"]
    assert isinstance(toolchain, dict)
    lock_path = validate_path(str(toolchain["lock"]), "config.toolchain.lock")
    if not nested(state, lock_path):
        raise ContractError("project lock must live below the state root")
    package_manager = toolchain["packageManager"]
    assert isinstance(package_manager, dict)
    manifest_path = validate_path(str(package_manager["manifest"]), "package manifest")
    lockfile_path = validate_path(str(package_manager["lockfile"]), "package lock")
    if manifest_path == lockfile_path:
        raise ContractError("package manifest and lockfile must differ")

    environment = config["environment"]
    assert isinstance(environment, dict)
    build_environment = environment["build"]
    runtime_environment = environment["runtime"]
    assert isinstance(build_environment, list)
    assert isinstance(runtime_environment, list)
    require_sorted_unique(build_environment, "build environment", lambda item: item["name"])
    require_sorted_unique(runtime_environment, "runtime environment", lambda item: item["name"])
    build_names = {str(item["name"]) for item in build_environment}
    runtime_names = {str(item["name"]) for item in runtime_environment}
    if build_names & runtime_names:
        raise ContractError("build and runtime environment names must be disjoint")
    for item in build_environment:
        assert isinstance(item, dict)
        if item["required"] is True and "default" in item:
            raise ContractError("required build environment input cannot have a default")
    for item in runtime_environment:
        assert isinstance(item, dict)
        require_sorted_unique(item["services"], f"runtime environment {item['name']} services")

    entry_point = str(config["entryPoint"])
    package_parts = entry_point.split(".")
    relative_entry = Path(*package_parts[:-1], package_parts[-1] + ".hx")
    if not any((project_root / str(root) / relative_entry).is_file() for root in source_roots):
        raise ContractError(f"entry point source does not exist: {entry_point}")

    package = read_json(project_root / manifest_path, "consumer npm manifest")
    package_lock = read_json(project_root / lockfile_path, "consumer npm lock")
    if package.get("packageManager") != "npm@10.9.2":
        raise ContractError("consumer package manager must be exactly npm@10.9.2")
    dependencies = package.get("devDependencies")
    if not isinstance(dependencies, dict):
        raise ContractError("consumer package lacks exact CLI devDependency")
    cli_version = dependencies.get("@wordpress-hx/cli")
    if not isinstance(cli_version, str) or EXACT_VERSION_RE.fullmatch(cli_version) is None:
        raise ContractError("@wordpress-hx/cli must use an exact version")
    scripts = package.get("scripts")
    expected_scripts = {
        "build": "wphx build",
        "check": "wphx check",
        "dev": "wphx dev",
        "test": "wphx test",
    }
    if scripts != expected_scripts:
        raise ContractError("consumer scripts must expose the closed wphx aliases")
    if "wphx-sdk" in canonical(package).decode("utf-8"):
        raise ContractError("legacy prototype binary leaked into the consumer fixture")
    if package_lock.get("lockfileVersion") != 3:
        raise ContractError("consumer package lock must use npm lockfile v3")


def validate_lock(
    lock: dict[str, object],
    validator: ClosedSchemaValidator,
    config: dict[str, object],
    project_root: Path,
) -> None:
    validator.validate(lock)
    if lock["lockDigest"] != digest_without(lock, "lockDigest"):
        raise ContractError("project lock self-digest mismatch")
    project = lock["project"]
    profile = lock["profile"]
    assert isinstance(project, dict)
    assert isinstance(profile, dict)
    if project["id"] != config["projectId"]:
        raise ContractError("project lock identity differs from configuration")
    if project["configPath"] != "wordpress-hx.json":
        raise ContractError("project lock must bind wordpress-hx.json")
    if project["configSemanticSha256"] != sha256(canonical(config)):
        raise ContractError("project lock config semantic digest mismatch")
    config_profile = config["profile"]
    assert isinstance(config_profile, dict)
    if profile["id"] != config_profile["id"]:
        raise ContractError("project lock profile differs from configuration")

    components = lock["components"]
    assert isinstance(components, list)
    require_sorted_unique(components, "project lock components", lambda item: item["id"])
    component_ids = {str(component["id"]) for component in components}
    if component_ids != REQUIRED_COMPONENTS:
        raise ContractError("project lock does not contain the exact required component set")
    for component in components:
        assert isinstance(component, dict)
        if component["lockEntrySha256"] != component_digest(component):
            raise ContractError(f"component lock-entry digest mismatch: {component['id']}")
        identity = str(component["identity"])
        if "../" in identity or "file:" in identity or "link:" in identity:
            raise ContractError(f"floating/local component identity is forbidden: {component['id']}")

    package_graph = lock["packageGraph"]
    assert isinstance(package_graph, dict)
    package_manager = config["toolchain"]["packageManager"]
    assert isinstance(package_manager, dict)
    if package_graph["manager"] != package_manager["kind"]:
        raise ContractError("project lock package manager mismatch")
    if package_graph["version"] != "10.9.2":
        raise ContractError("project lock npm version must be exact")
    for field in ("manifest", "lockfile"):
        record = package_graph[field]
        assert isinstance(record, dict)
        path = validate_path(str(record["path"]), f"project lock {field}")
        if record["sha256"] != sha256((project_root / path).read_bytes()):
            raise ContractError(f"project lock {field} digest mismatch")
    if package_graph["lifecycleScriptsAllowed"] is not False:
        raise ContractError("fixture package lifecycle scripts must remain disabled")


def update_lock(config: dict[str, object], lock: dict[str, object], project_root: Path) -> None:
    project = lock["project"]
    package_graph = lock["packageGraph"]
    components = lock["components"]
    toolchain = config["toolchain"]
    assert isinstance(project, dict)
    assert isinstance(package_graph, dict)
    assert isinstance(components, list)
    assert isinstance(toolchain, dict)
    package_manager = toolchain["packageManager"]
    assert isinstance(package_manager, dict)
    project["configSemanticSha256"] = sha256(canonical(config))
    package_graph["manifest"]["path"] = package_manager["manifest"]
    package_graph["lockfile"]["path"] = package_manager["lockfile"]
    for field in ("manifest", "lockfile"):
        record = package_graph[field]
        assert isinstance(record, dict)
        record["sha256"] = sha256((project_root / str(record["path"])).read_bytes())
    for component in components:
        assert isinstance(component, dict)
        component["lockEntrySha256"] = component_digest(component)
    lock["lockDigest"] = digest_without(lock, "lockDigest")
    LOCK_PATH.write_bytes(canonical(lock, newline=True))


def file_record(project_root: Path, path: str, role: str, targets: list[str]) -> dict[str, object]:
    validate_path(path, f"effective file {path}")
    absolute = project_root / path
    try:
        metadata = absolute.lstat()
    except FileNotFoundError as error:
        raise ContractError(f"effective input is missing: {path}") from error
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise ContractError(f"effective input must be a regular non-link file: {path}")
    data = absolute.read_bytes()
    return {
        "path": path,
        "sha256": sha256(data),
        "byteLength": len(data),
        "role": role,
        "targets": sorted(targets),
    }


def discover_regular(project_root: Path, root: str, suffixes: set[str] | None) -> list[str]:
    absolute_root = project_root / root
    if not absolute_root.exists():
        return []
    if absolute_root.is_symlink() or not absolute_root.is_dir():
        raise ContractError(f"discovery root must be a non-link directory: {root}")
    result: list[str] = []
    for candidate in absolute_root.rglob("*"):
        relative = candidate.relative_to(project_root).as_posix()
        metadata = candidate.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            raise ContractError(f"symlink effective input is forbidden: {relative}")
        if stat.S_ISDIR(metadata.st_mode):
            continue
        if not stat.S_ISREG(metadata.st_mode):
            raise ContractError(f"special effective input is forbidden: {relative}")
        if suffixes is None or candidate.suffix in suffixes:
            result.append(relative)
    return sorted(result)


def build_effective(
    project_root: Path,
    config: dict[str, object],
    lock: dict[str, object],
    *,
    build_environment: dict[str, str] | None = None,
    runtime_environment: dict[str, str] | None = None,
) -> dict[str, object]:
    build_environment = build_environment or {}
    runtime_environment = runtime_environment or {}
    environment = config["environment"]
    paths = config["paths"]
    toolchain = config["toolchain"]
    profile = lock["profile"]
    project_lock = lock["project"]
    components = lock["components"]
    assert isinstance(environment, dict)
    assert isinstance(paths, dict)
    assert isinstance(toolchain, dict)
    assert isinstance(profile, dict)
    assert isinstance(project_lock, dict)
    assert isinstance(components, list)

    build_declarations = {str(item["name"]): item for item in environment["build"]}
    runtime_declarations = {str(item["name"]): item for item in environment["runtime"]}
    unknown_build = sorted(set(build_environment) - set(build_declarations))
    unknown_runtime = sorted(set(runtime_environment) - set(runtime_declarations))
    if unknown_build:
        raise ContractError(f"undeclared build environment input: {unknown_build[0]}")
    if unknown_runtime:
        raise ContractError(f"undeclared runtime environment input: {unknown_runtime[0]}")
    if set(build_environment) & set(runtime_declarations):
        raise ContractError("runtime environment value cannot enter the build environment")

    resolved_build: list[dict[str, object]] = []
    for name in sorted(build_declarations):
        declaration = build_declarations[name]
        assert isinstance(declaration, dict)
        if name in build_environment:
            value = build_environment[name]
            source = "process"
        elif "default" in declaration:
            value = str(declaration["default"])
            source = "default"
        elif declaration["required"] is True:
            raise ContractError(f"required build environment input is missing: {name}")
        else:
            value = ""
            source = "default"
        resolved_build.append(
            {"name": name, "source": source, "valueSha256": sha256(value.encode("utf-8"))}
        )

    records: list[dict[str, object]] = []
    explicit = [
        (".haxerc", "haxe-config", ["browser", "metadata", "php", "plan"]),
        (
            ".wphx/bootstrap/project.hxml",
            "hxml",
            ["browser", "metadata", "php", "plan"],
        ),
        (
            str(toolchain["lock"]),
            "project-lock",
            ["assets", "browser", "metadata", "php", "plan", "services", "test"],
        ),
        (
            str(toolchain["packageManager"]["manifest"]),
            "package-manifest",
            ["assets", "browser", "services"],
        ),
        (
            str(toolchain["packageManager"]["lockfile"]),
            "package-lock",
            ["assets", "browser", "services"],
        ),
        (
            "wordpress-hx.json",
            "project-config",
            ["assets", "browser", "metadata", "php", "plan", "services", "test"],
        ),
    ]
    seen: set[str] = set()
    for path, role, targets in explicit:
        if path in seen:
            raise ContractError(f"duplicate effective input: {path}")
        seen.add(path)
        records.append(file_record(project_root, path, role, targets))

    for source_root in paths["sourceRoots"]:
        for path in discover_regular(project_root, str(source_root), {".hx", ".hxx"}):
            if path in seen:
                raise ContractError(f"duplicate effective input: {path}")
            seen.add(path)
            records.append(
                file_record(
                    project_root,
                    path,
                    "haxe-source",
                    ["browser", "metadata", "php", "plan", "services"],
                )
            )
    for test_root in paths["testRoots"]:
        for path in discover_regular(project_root, str(test_root), {".hx", ".hxx"}):
            if path in seen:
                raise ContractError(f"duplicate effective input: {path}")
            seen.add(path)
            records.append(file_record(project_root, path, "haxe-source", ["test"]))
    for asset_root in paths["assetRoots"]:
        for path in discover_regular(project_root, str(asset_root), None):
            if path in seen:
                raise ContractError(f"duplicate effective input: {path}")
            seen.add(path)
            records.append(file_record(project_root, path, "asset", ["assets"]))
    records.sort(key=lambda item: str(item["path"]))

    component_by_id = {str(component["id"]): component for component in components}
    tool_records = [
        {
            "id": component_id,
            "identity": component_by_id[component_id]["identity"],
            "lockEntrySha256": component_by_id[component_id]["lockEntrySha256"],
        }
        for component_id in sorted(component_by_id)
    ]
    compatibility_payload = {
        "projectId": config["projectId"],
        "configSemanticSha256": project_lock["configSemanticSha256"],
        "lockDigest": lock["lockDigest"],
        "components": [
            {
                "id": component_id,
                "identity": component_by_id[component_id]["identity"],
                "lockEntrySha256": component_by_id[component_id]["lockEntrySha256"],
            }
            for component_id in COMPILER_COMPATIBILITY_COMPONENTS
        ],
        "restartFiles": [
            {
                "path": record["path"],
                "role": record["role"],
                "sha256": record["sha256"],
            }
            for record in records
            if record["role"]
            in {
                "haxe-config",
                "hxml",
                "package-lock",
                "package-manifest",
                "project-config",
                "project-lock",
            }
        ],
        "buildEnvironment": resolved_build,
    }
    lock_relative = str(toolchain["lock"])
    lock_bytes = (project_root / lock_relative).read_bytes()
    document: dict[str, object] = {
        "schema": "wordpress-hx.effective-inputs.v1",
        "canonicalization": "wordpress-hx.canonical-json.v1",
        "fingerprintAlgorithm": "sha256-canonical-json-without-fingerprint-v1",
        "fingerprint": "0" * 64,
        "project": {
            "id": config["projectId"],
            "configPath": project_lock["configPath"],
            "configSemanticSha256": project_lock["configSemanticSha256"],
            "lockPath": lock_relative,
            "lockFileSha256": sha256(lock_bytes),
            "lockDigest": lock["lockDigest"],
        },
        "profile": copy.deepcopy(profile),
        "files": records,
        "discoveryRoots": [
            {
                "path": ".",
                "includes": sorted(
                    [
                        ".haxerc",
                        str(toolchain["packageManager"]["lockfile"]),
                        str(toolchain["packageManager"]["manifest"]),
                        "wordpress-hx.json",
                    ]
                ),
                "excludes": [
                    ".git/**",
                    ".wphx/runtime/**",
                    ".wphx/transactions/**",
                    "build/**",
                    "dist/**",
                    "node_modules/**",
                ],
                "targets": ["assets", "browser", "metadata", "php", "plan", "services"],
            },
            {
                "path": ".wphx/bootstrap",
                "includes": ["**/*.hxml"],
                "excludes": [],
                "targets": ["browser", "metadata", "php", "plan"],
            },
            {
                "path": "assets",
                "includes": ["**/*"],
                "excludes": [],
                "targets": ["assets"],
            },
            {
                "path": "src",
                "includes": ["**/*.hx", "**/*.hxx"],
                "excludes": [],
                "targets": ["browser", "metadata", "php", "plan", "services"],
            },
            {
                "path": "test",
                "includes": ["**/*.hx", "**/*.hxx"],
                "excludes": [],
                "targets": ["test"],
            },
        ],
        "watchRoots": [".", ".wphx/bootstrap", "assets", "src", "test"],
        "ignoredRoots": [
            ".git",
            ".wphx/runtime",
            ".wphx/transactions",
            "build",
            "dist",
            "node_modules",
        ],
        "toolchain": tool_records,
        "environment": {
            "build": resolved_build,
            "runtimeExcluded": sorted(runtime_declarations),
        },
        "compileServer": {
            "policy": "project-isolated-compatible-attach-v1",
            "compatibilityDigestAlgorithm": (
                "sha256-project-lock-config-compiler-inputs-and-build-env-v2"
            ),
            "compatibilityDigest": sha256(canonical(compatibility_payload)),
            "compatibilityComponents": COMPILER_COMPATIBILITY_COMPONENTS,
            "restartFileRoles": [
                "haxe-config",
                "hxml",
                "package-lock",
                "package-manifest",
                "project-config",
                "project-lock",
            ],
            "directBuildDefault": True,
        },
    }
    document["fingerprint"] = digest_without(document, "fingerprint")
    return document


def validate_effective(
    document: dict[str, object],
    validator: ClosedSchemaValidator,
    config: dict[str, object],
    lock: dict[str, object],
    project_root: Path,
) -> None:
    validator.validate(document)
    if document["fingerprint"] != digest_without(document, "fingerprint"):
        raise ContractError("effective-input fingerprint mismatch")
    expected = build_effective(project_root, config, lock)
    if document != expected:
        raise ContractError("committed effective-input graph differs from deterministic discovery")
    files = document["files"]
    discovery_roots = document["discoveryRoots"]
    toolchain = document["toolchain"]
    environment = document["environment"]
    assert isinstance(files, list)
    assert isinstance(discovery_roots, list)
    assert isinstance(toolchain, list)
    assert isinstance(environment, dict)
    require_sorted_unique(files, "effective files", lambda item: item["path"])
    require_sorted_unique(discovery_roots, "discovery roots", lambda item: item["path"])
    require_sorted_unique(document["watchRoots"], "watch roots")
    require_sorted_unique(document["ignoredRoots"], "ignored roots")
    require_sorted_unique(toolchain, "toolchain", lambda item: item["id"])
    require_sorted_unique(environment["build"], "effective build environment", lambda item: item["name"])
    require_sorted_unique(environment["runtimeExcluded"], "excluded runtime environment")
    ignored = [str(root) for root in document["ignoredRoots"]]
    for file in files:
        path = str(file["path"])
        validate_path(path, f"effective file {path}")
        if any(path == root or nested(root, path) for root in ignored):
            raise ContractError(f"ignored path entered effective files: {path}")
    paths = config["paths"]
    assert isinstance(paths, dict)
    forbidden = [str(root["path"]) for root in paths["outputRoots"]]
    forbidden.extend([str(paths["distributionRoot"]), "node_modules"])
    for file in files:
        path = str(file["path"])
        if any(path == root or nested(root, path) for root in forbidden):
            raise ContractError(f"output/dependency file entered effective inputs: {path}")


def event(
    run_id: str,
    sequence: int,
    elapsed_ms: int,
    command: str,
    event_name: str,
    stage: str,
    status: str,
    payload: dict[str, object],
) -> dict[str, object]:
    return {
        "schema": "wordpress-hx.cli-event.v1",
        "runId": run_id,
        "sequence": sequence,
        "elapsedMs": elapsed_ms,
        "command": command,
        "event": event_name,
        "stage": stage,
        "status": status,
        "payload": payload,
    }


def build_event_fixtures(effective: dict[str, object]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    fingerprint = str(effective["fingerprint"])
    compile_server = effective["compileServer"]
    assert isinstance(compile_server, dict)
    compatibility = str(compile_server["compatibilityDigest"])
    first_manifest = sha256(b"adr-016-generation-1")
    second_manifest = sha256(b"adr-016-generation-2")
    failed_fingerprint = sha256(canonical({"base": fingerprint, "change": "broken-site-and-brand"}))
    recovered_fingerprint = sha256(canonical({"base": fingerprint, "change": "repaired-site"}))

    dry = [
        event(
            "contract-dry-run-001",
            1,
            0,
            "build",
            "command-started",
            "command",
            "started",
            {"mode": "dry-run", "fingerprint": fingerprint},
        )
    ]
    sequence = 2
    elapsed_ms = 1
    for stage in BUILD_STAGES[:-1]:
        dry.append(
            event(
                "contract-dry-run-001",
                sequence,
                elapsed_ms,
                "build",
                "stage-started",
                stage,
                "running",
                {"mode": "dry-run", "buildId": "dry-run-build-001"},
            )
        )
        sequence += 1
        elapsed_ms += 1
        dry.append(
            event(
                "contract-dry-run-001",
                sequence,
                elapsed_ms,
                "build",
                "stage-completed",
                stage,
                "passed",
                {"mode": "dry-run", "buildId": "dry-run-build-001"},
            )
        )
        sequence += 1
        elapsed_ms += 1
    dry.extend(
        [
            event(
                "contract-dry-run-001",
                sequence,
                elapsed_ms,
                "build",
                "dry-run-planned",
                "artifact-validation",
                "passed",
                {
                    "mode": "dry-run",
                    "buildId": "dry-run-build-001",
                    "fingerprint": fingerprint,
                    "reason": "complete staged action plan validated; live tree unchanged",
                },
            ),
            event(
                "contract-dry-run-001",
                sequence + 1,
                elapsed_ms + 1,
                "build",
                "stage-skipped",
                "ownership-publish",
                "skipped",
                {"mode": "dry-run", "reason": "dry-run has no publication authority"},
            ),
            event(
                "contract-dry-run-001",
                sequence + 2,
                elapsed_ms + 2,
                "build",
                "command-completed",
                "command",
                "passed",
                {"exitCode": 0, "reason": "dry-run plan completed"},
            ),
        ]
    )

    dev = [
        event(
            "contract-dev-run-001",
            1,
            0,
            "dev",
            "command-started",
            "command",
            "started",
            {"mode": "initial", "fingerprint": fingerprint},
        ),
        event(
            "contract-dev-run-001",
            2,
            15,
            "dev",
            "compiler-server-ready",
            "compiler-server",
            "ready",
            {
                "serviceId": "compiler",
                "serviceKind": "compiler",
                "processOwnership": "owned",
                "serverCompatibilityDigest": compatibility,
            },
        ),
        event(
            "contract-dev-run-001",
            3,
            16,
            "dev",
            "stage-started",
            "configuration",
            "running",
            {"mode": "initial", "buildId": "dev-build-001"},
        ),
        event(
            "contract-dev-run-001",
            4,
            150,
            "dev",
            "build-published",
            "ownership-publish",
            "passed",
            {
                "mode": "initial",
                "buildId": "dev-build-001",
                "fingerprint": fingerprint,
                "generation": 1,
                "manifestDigest": first_manifest,
            },
        ),
        event(
            "contract-dev-run-001",
            5,
            151,
            "dev",
            "service-starting",
            "service-start",
            "started",
            {
                "serviceId": "wordpress",
                "serviceKind": "wordpress",
                "processOwnership": "owned",
            },
        ),
        event(
            "contract-dev-run-001",
            6,
            620,
            "dev",
            "service-ready",
            "service-readiness",
            "ready",
            {
                "serviceId": "wordpress",
                "serviceKind": "wordpress",
                "url": "http://127.0.0.1:8888",
                "readiness": "http",
                "timeoutMs": 60000,
            },
        ),
        event(
            "contract-dev-run-001",
            7,
            621,
            "dev",
            "service-starting",
            "service-start",
            "started",
            {
                "serviceId": "nextjs",
                "serviceKind": "nextjs",
                "processOwnership": "owned",
            },
        ),
        event(
            "contract-dev-run-001",
            8,
            900,
            "dev",
            "service-ready",
            "service-readiness",
            "ready",
            {
                "serviceId": "nextjs",
                "serviceKind": "nextjs",
                "url": "http://127.0.0.1:3000",
                "readiness": "http",
                "timeoutMs": 60000,
            },
        ),
        event(
            "contract-dev-run-001",
            9,
            905,
            "dev",
            "watch-ready",
            "watching",
            "ready",
            {"reason": "effective input graph subscribed after initial publish and readiness"},
        ),
        event(
            "contract-dev-run-001",
            10,
            1200,
            "dev",
            "change-detected",
            "watching",
            "running",
            {
                "changedPaths": ["assets/brand.txt", "src/acme/site/Site.hx"],
                "coalescedChanges": 2,
            },
        ),
        event(
            "contract-dev-run-001",
            11,
            1300,
            "dev",
            "rebuild-scheduled",
            "watching",
            "running",
            {
                "mode": "rebuild",
                "buildId": "dev-build-002",
                "fingerprint": failed_fingerprint,
                "changedPaths": ["assets/brand.txt", "src/acme/site/Site.hx"],
                "coalescedChanges": 2,
            },
        ),
        event(
            "contract-dev-run-001",
            12,
            1380,
            "dev",
            "diagnostic",
            "haxe-typing-and-plan",
            "failed",
            {
                "buildId": "dev-build-002",
                "diagnostic": {
                    "code": "WPHX2102",
                    "severity": "error",
                    "message": "Development service readinessPath must begin with a slash.",
                    "profile": "wp70-release",
                    "source": {"path": "src/acme/site/Site.hx", "line": 31, "column": 18},
                    "expected": "an absolute URL path such as /wp-json/",
                    "actual": "wp-json/",
                    "remediations": ["Prefix the readiness path with / and save the Haxe source."],
                    "reference": "ADR-016 typed development services",
                },
            },
        ),
        event(
            "contract-dev-run-001",
            13,
            1381,
            "dev",
            "build-retained",
            "ownership-publish",
            "retained",
            {
                "mode": "rebuild",
                "buildId": "dev-build-002",
                "fingerprint": failed_fingerprint,
                "retainedManifestDigest": first_manifest,
                "reason": "rebuild failed before publication; generation 1 remains live",
            },
        ),
        event(
            "contract-dev-run-001",
            14,
            1700,
            "dev",
            "change-detected",
            "watching",
            "running",
            {"changedPaths": ["src/acme/site/Site.hx"], "coalescedChanges": 1},
        ),
        event(
            "contract-dev-run-001",
            15,
            1800,
            "dev",
            "rebuild-scheduled",
            "watching",
            "running",
            {
                "mode": "rebuild",
                "buildId": "dev-build-003",
                "fingerprint": recovered_fingerprint,
                "changedPaths": ["src/acme/site/Site.hx"],
                "coalescedChanges": 1,
            },
        ),
        event(
            "contract-dev-run-001",
            16,
            1930,
            "dev",
            "build-published",
            "ownership-publish",
            "passed",
            {
                "mode": "rebuild",
                "buildId": "dev-build-003",
                "fingerprint": recovered_fingerprint,
                "generation": 2,
                "manifestDigest": second_manifest,
            },
        ),
        event(
            "contract-dev-run-001",
            17,
            1931,
            "dev",
            "reload-requested",
            "watching",
            "passed",
            {
                "serviceId": "wordpress",
                "manifestDigest": second_manifest,
                "reload": "full-page",
            },
        ),
        event(
            "contract-dev-run-001",
            18,
            1932,
            "dev",
            "reload-requested",
            "watching",
            "passed",
            {
                "serviceId": "nextjs",
                "manifestDigest": second_manifest,
                "reload": "native-hmr",
            },
        ),
        event(
            "contract-dev-run-001",
            19,
            2200,
            "dev",
            "shutdown-started",
            "shutdown",
            "interrupted",
            {"mode": "shutdown", "reason": "SIGINT"},
        ),
        event(
            "contract-dev-run-001",
            20,
            2210,
            "dev",
            "service-stopped",
            "shutdown",
            "stopped",
            {
                "serviceId": "nextjs",
                "serviceKind": "nextjs",
                "processOwnership": "owned",
            },
        ),
        event(
            "contract-dev-run-001",
            21,
            2220,
            "dev",
            "service-stopped",
            "shutdown",
            "stopped",
            {
                "serviceId": "wordpress",
                "serviceKind": "wordpress",
                "processOwnership": "owned",
            },
        ),
        event(
            "contract-dev-run-001",
            22,
            2230,
            "dev",
            "service-stopped",
            "shutdown",
            "stopped",
            {
                "serviceId": "compiler",
                "serviceKind": "compiler",
                "processOwnership": "owned",
            },
        ),
        event(
            "contract-dev-run-001",
            23,
            2231,
            "dev",
            "command-completed",
            "command",
            "interrupted",
            {"exitCode": 130, "reason": "SIGINT handled; all owned services stopped"},
        ),
    ]
    return dry, dev


EVENT_REQUIREMENTS = {
    "command-started": {"mode", "fingerprint"},
    "stage-started": {"mode", "buildId"},
    "stage-completed": {"mode", "buildId"},
    "stage-skipped": {"mode", "reason"},
    "build-published": {"mode", "buildId", "fingerprint", "generation", "manifestDigest"},
    "build-retained": {
        "mode",
        "buildId",
        "fingerprint",
        "retainedManifestDigest",
        "reason",
    },
    "dry-run-planned": {"mode", "buildId", "fingerprint", "reason"},
    "compiler-server-ready": {
        "serviceId",
        "serviceKind",
        "processOwnership",
        "serverCompatibilityDigest",
    },
    "change-detected": {"changedPaths", "coalescedChanges"},
    "rebuild-scheduled": {
        "mode",
        "buildId",
        "fingerprint",
        "changedPaths",
        "coalescedChanges",
    },
    "diagnostic": {"buildId", "diagnostic"},
    "service-starting": {"serviceId", "serviceKind", "processOwnership"},
    "service-ready": {"serviceId", "serviceKind", "url", "readiness", "timeoutMs"},
    "service-stopped": {"serviceId", "serviceKind", "processOwnership"},
    "watch-ready": {"reason"},
    "reload-requested": {"serviceId", "manifestDigest", "reload"},
    "shutdown-started": {"mode", "reason"},
    "command-completed": {"exitCode", "reason"},
}


def read_jsonl(path: Path, label: str) -> list[dict[str, object]]:
    data = path.read_bytes()
    if not data.endswith(b"\n") or data.endswith(b"\n\n"):
        raise ContractError(f"{label}: JSONL must end in exactly one LF")
    result: list[dict[str, object]] = []
    for index, line in enumerate(data.splitlines(), start=1):
        value = strict_json_bytes(line, f"{label} line {index}")
        if not isinstance(value, dict):
            raise ContractError(f"{label} line {index}: expected object")
        if line != canonical(value):
            raise ContractError(f"{label} line {index}: event is not canonical JSON")
        result.append(value)
    return result


def write_jsonl(path: Path, events: list[dict[str, object]]) -> None:
    path.write_bytes(b"".join(canonical(item, newline=True) for item in events))


def validate_events(events: list[dict[str, object]], validator: ClosedSchemaValidator) -> None:
    if not events:
        raise ContractError("event stream is empty")
    for item in events:
        validator.validate(item)
        payload = item["payload"]
        assert isinstance(payload, dict)
        required = EVENT_REQUIREMENTS[str(item["event"])]
        missing = sorted(required - set(payload))
        if missing:
            raise ContractError(f"event {item['event']} lacks payload fields: {missing}")
    run_ids = {str(item["runId"]) for item in events}
    commands = {str(item["command"]) for item in events}
    if len(run_ids) != 1 or len(commands) != 1:
        raise ContractError("event stream mixes runs or commands")
    if [item["sequence"] for item in events] != list(range(1, len(events) + 1)):
        raise ContractError("event sequence is not contiguous")
    elapsed = [int(item["elapsedMs"]) for item in events]
    if elapsed != sorted(elapsed):
        raise ContractError("event elapsed time moved backwards")
    if events[0]["event"] != "command-started" or events[-1]["event"] != "command-completed":
        raise ContractError("event stream lacks command boundaries")

    command = next(iter(commands))
    published_manifest: str | None = None
    published_generation = 0
    pending_failed_build: str | None = None
    owned_start_order: list[str] = []
    stopped_order: list[str] = []
    ready_services: set[str] = set()
    watch_ready = False
    reloads_after_publish = 0
    dry_run_planned = False

    for item in events:
        name = str(item["event"])
        payload = item["payload"]
        assert isinstance(payload, dict)
        if name == "compiler-server-ready":
            if payload["serviceId"] != "compiler" or payload["serviceKind"] != "compiler":
                raise ContractError("compiler-server event has the wrong identity")
            if payload["processOwnership"] == "owned":
                owned_start_order.append("compiler")
            ready_services.add("compiler")
        elif name == "build-published":
            generation = int(payload["generation"])
            if generation != published_generation + 1:
                raise ContractError("published generations are not contiguous")
            published_generation = generation
            published_manifest = str(payload["manifestDigest"])
            pending_failed_build = None
            reloads_after_publish = 0
        elif name == "service-starting":
            service_id = str(payload["serviceId"])
            if published_manifest is None:
                raise ContractError("service started before initial publication")
            if payload["processOwnership"] == "owned":
                owned_start_order.append(service_id)
        elif name == "service-ready":
            service_id = str(payload["serviceId"])
            if service_id not in owned_start_order:
                raise ContractError("service became ready before it started")
            ready_services.add(service_id)
        elif name == "watch-ready":
            if published_manifest is None or not {"wordpress", "nextjs"}.issubset(ready_services):
                raise ContractError("watch became ready before publish/services")
            watch_ready = True
        elif name == "diagnostic" and item["status"] == "failed":
            pending_failed_build = str(payload["buildId"])
        elif name == "build-retained":
            if pending_failed_build != payload["buildId"]:
                raise ContractError("last-good retention is not bound to the failed build")
            if published_manifest != payload["retainedManifestDigest"]:
                raise ContractError("last-good retention digest differs from the live generation")
            pending_failed_build = None
            reloads_after_publish = -1
        elif name == "reload-requested":
            if published_manifest is None or payload["manifestDigest"] != published_manifest:
                raise ContractError("reload is not bound to the complete published generation")
            if not watch_ready or reloads_after_publish < 0:
                raise ContractError("reload followed a failed/unpublished build")
            reloads_after_publish += 1
        elif name == "dry-run-planned":
            dry_run_planned = True
        elif name == "service-stopped":
            service_id = str(payload["serviceId"])
            if payload["processOwnership"] == "owned":
                stopped_order.append(service_id)

    if command == "build":
        if not dry_run_planned:
            raise ContractError("bounded dry-run transcript lacks its plan")
        if published_manifest is not None or owned_start_order:
            raise ContractError("dry-run transcript published or started a service")
        skipped = [item for item in events if item["event"] == "stage-skipped"]
        if not any(item["stage"] == "ownership-publish" for item in skipped):
            raise ContractError("dry-run did not explicitly skip ownership publication")
        observed_stage_events = [
            (str(item["event"]), str(item["stage"]))
            for item in events
            if item["event"] in {"stage-started", "stage-completed", "stage-skipped"}
        ]
        expected_stage_events = [
            stage_event
            for stage in BUILD_STAGES[:-1]
            for stage_event in (("stage-started", stage), ("stage-completed", stage))
        ]
        expected_stage_events.append(("stage-skipped", BUILD_STAGES[-1]))
        if observed_stage_events != expected_stage_events:
            raise ContractError("dry-run stages do not traverse the stable build order")
        if events[-1]["payload"]["exitCode"] != 0:
            raise ContractError("successful dry-run exit code differs from zero")
    elif command == "dev":
        if published_generation != 2:
            raise ContractError("dev transcript does not publish two complete generations")
        if stopped_order != list(reversed(owned_start_order)):
            raise ContractError("owned services did not stop in reverse start order")
        if events[-1]["status"] != "interrupted" or events[-1]["payload"]["exitCode"] != 130:
            raise ContractError("SIGINT transcript must finish with conventional exit 130")
        if reloads_after_publish != 2:
            raise ContractError("successful rebuilt generation did not reload both services")


def clone_and_mutate(value: dict[str, object], mutation) -> dict[str, object]:
    clone = copy.deepcopy(value)
    mutation(clone)
    return clone


def reseal_lock_document(value: dict[str, object]) -> dict[str, object]:
    components = value["components"]
    assert isinstance(components, list)
    for component in components:
        assert isinstance(component, dict)
        component["lockEntrySha256"] = component_digest(component)
    value["lockDigest"] = digest_without(value, "lockDigest")
    return value


def reseal_effective_document(value: dict[str, object]) -> dict[str, object]:
    files = value["files"]
    assert isinstance(files, list)
    files.sort(key=lambda item: str(item["path"]))
    value["fingerprint"] = digest_without(value, "fingerprint")
    return value


def resequence_events(events: list[dict[str, object]]) -> list[dict[str, object]]:
    for sequence, item in enumerate(events, start=1):
        item["sequence"] = sequence
    return events


def expect_error(label: str, action) -> None:
    try:
        action()
    except (ContractError, OSError):
        return
    raise ContractError(f"negative mutation unexpectedly passed: {label}")


def tree_digest(root: Path) -> str:
    records: list[dict[str, object]] = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        metadata = path.lstat()
        if stat.S_ISDIR(metadata.st_mode):
            records.append({"path": relative, "kind": "directory"})
        elif stat.S_ISREG(metadata.st_mode):
            data = path.read_bytes()
            records.append({"path": relative, "kind": "file", "sha256": sha256(data)})
        elif stat.S_ISLNK(metadata.st_mode):
            records.append({"path": relative, "kind": "symlink", "target": os.readlink(path)})
        else:
            records.append({"path": relative, "kind": "special"})
    return sha256(canonical(records))


def run_negative_matrix(
    validators: dict[str, ClosedSchemaValidator],
    config: dict[str, object],
    lock: dict[str, object],
    effective: dict[str, object],
    dry_events: list[dict[str, object]],
    dev_events: list[dict[str, object]],
) -> int:
    checks: list[tuple[str, object]] = []

    def config_check(document: dict[str, object]) -> None:
        validate_config(document, validators["project"], PROJECT_ROOT)

    checks.extend(
        [
            (
                "unknown config field",
                lambda: config_check(clone_and_mutate(config, lambda value: value.update({"extra": True}))),
            ),
            (
                "non-npm manager",
                lambda: config_check(
                    clone_and_mutate(
                        config,
                        lambda value: value["toolchain"]["packageManager"].update({"kind": "pnpm"}),
                    )
                ),
            ),
            (
                "absolute source root",
                lambda: config_check(
                    clone_and_mutate(config, lambda value: value["paths"].update({"sourceRoots": ["/src"]}))
                ),
            ),
            (
                "traversal asset root",
                lambda: config_check(
                    clone_and_mutate(config, lambda value: value["paths"].update({"assetRoots": ["../assets"]}))
                ),
            ),
            (
                "nested output roots",
                lambda: config_check(
                    clone_and_mutate(
                        config,
                        lambda value: value["paths"].update(
                            {
                                "outputRoots": [
                                    {"id": "all", "path": "build"},
                                    {"id": "wordpress", "path": "build/wordpress"},
                                ]
                            }
                        ),
                    )
                ),
            ),
            (
                "secret build input",
                lambda: config_check(
                    clone_and_mutate(
                        config,
                        lambda value: value["environment"]["build"][0].update(
                            {"classification": "secret-runtime"}
                        ),
                    )
                ),
            ),
            (
                "duplicate environment authority",
                lambda: config_check(
                    clone_and_mutate(
                        config,
                        lambda value: value["environment"]["runtime"][0].update(
                            {"name": "SITE_LOCALE"}
                        ),
                    )
                ),
            ),
        ]
    )

    def lock_check(document: dict[str, object]) -> None:
        validate_lock(document, validators["lock"], config, PROJECT_ROOT)

    checks.extend(
        [
            (
                "lock digest tamper",
                lambda: lock_check(clone_and_mutate(lock, lambda value: value.update({"lockDigest": "f" * 64}))),
            ),
            (
                "lock profile mismatch",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock, lambda value: value["profile"].update({"id": "other-profile"})
                        )
                    )
                ),
            ),
            (
                "lock config hash mismatch",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock,
                            lambda value: value["project"].update(
                                {"configSemanticSha256": "f" * 64}
                            ),
                        )
                    )
                ),
            ),
            (
                "missing required component",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock,
                            lambda value: value.update({"components": value["components"][1:]}),
                        )
                    )
                ),
            ),
            (
                "floating component identity",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock,
                            lambda value: value["components"][0].update(
                                {"identity": "file:../genes"}
                            ),
                        )
                    )
                ),
            ),
            (
                "floating component version",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock,
                            lambda value: value["components"][0].update(
                                {"version": "^1.36.3"}
                            ),
                        )
                    )
                ),
            ),
            (
                "package hash mismatch",
                lambda: lock_check(
                    reseal_lock_document(
                        clone_and_mutate(
                            lock,
                            lambda value: value["packageGraph"]["lockfile"].update(
                                {"sha256": "f" * 64}
                            ),
                        )
                    )
                ),
            ),
        ]
    )

    def effective_check(document: dict[str, object]) -> None:
        validate_effective(document, validators["effective"], config, lock, PROJECT_ROOT)

    checks.extend(
        [
            (
                "effective fingerprint tamper",
                lambda: effective_check(
                    clone_and_mutate(effective, lambda value: value.update({"fingerprint": "f" * 64}))
                ),
            ),
            (
                "effective absolute path",
                lambda: effective_check(
                    reseal_effective_document(
                        clone_and_mutate(
                            effective,
                            lambda value: value["files"][0].update({"path": "/tmp/leak"}),
                        )
                    )
                ),
            ),
            (
                "runtime secret value in graph",
                lambda: effective_check(
                    clone_and_mutate(
                        effective,
                        lambda value: value["environment"].update({"WP_DB_PASSWORD": "do-not-record"}),
                    )
                ),
            ),
            (
                "output path in effective files",
                lambda: effective_check(
                    reseal_effective_document(
                        clone_and_mutate(
                            effective,
                            lambda value: value["files"].append(
                                {
                                    "path": "build/wordpress/generated.php",
                                    "sha256": "f" * 64,
                                    "byteLength": 1,
                                    "role": "asset",
                                    "targets": ["assets"],
                                }
                            ),
                        )
                    )
                ),
            ),
        ]
    )

    checks.extend(
        [
            (
                "dry-run stage order drift",
                lambda: validate_events(
                    [
                        clone_and_mutate(
                            item,
                            lambda value: value.update({"stage": "profile-resolution"})
                            if value["event"] == "stage-completed"
                            and value["stage"] == "configuration"
                            else None,
                        )
                        for item in dry_events
                    ],
                    validators["event"],
                ),
            ),
            (
                "event sequence gap",
                lambda: validate_events(
                    [
                        clone_and_mutate(item, lambda value: None)
                        for item in dev_events[:1]
                    ]
                    + [
                        clone_and_mutate(item, lambda value: value.update({"sequence": 99}))
                        for item in dev_events[1:]
                    ],
                    validators["event"],
                ),
            ),
            (
                "reload wrong generation",
                lambda: validate_events(
                    [
                        clone_and_mutate(
                            item,
                            lambda value: value["payload"].update({"manifestDigest": "f" * 64})
                            if value["event"] == "reload-requested"
                            else None,
                        )
                        for item in dev_events
                    ],
                    validators["event"],
                ),
            ),
            (
                "owned service leak",
                lambda: validate_events(
                    resequence_events(
                        [
                            item
                            for item in copy.deepcopy(dev_events)
                            if not (
                                item["event"] == "service-stopped"
                                and item["payload"]["serviceId"] == "wordpress"
                            )
                        ]
                    ),
                    validators["event"],
                ),
            ),
            (
                "absolute diagnostic path",
                lambda: validate_events(
                    [
                        clone_and_mutate(
                            item,
                            lambda value: value["payload"]["diagnostic"]["source"].update(
                                {"path": "/tmp/Site.hx"}
                            )
                            if value["event"] == "diagnostic"
                            else None,
                        )
                        for item in dev_events
                    ],
                    validators["event"],
                ),
            ),
            (
                "credential-bearing non-loopback service URL",
                lambda: validate_events(
                    [
                        clone_and_mutate(
                            item,
                            lambda value: value["payload"].update(
                                {"url": "https://user:secret@example.com"}
                            )
                            if value["event"] == "service-ready"
                            and value["payload"]["serviceId"] == "wordpress"
                            else None,
                        )
                        for item in dev_events
                    ],
                    validators["event"],
                ),
            ),
        ]
    )

    for label, action in checks:
        expect_error(label, action)
    return len(checks)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update", action="store_true", help="regenerate canonical contract fixtures")
    options = parser.parse_args()

    schemas = {name: read_json(path, f"{name} schema") for name, path in SCHEMAS.items()}
    for name, schema in schemas.items():
        require_closed_schema(schema, f"{name} schema")
    validators = {name: ClosedSchemaValidator(schema) for name, schema in schemas.items()}

    config = read_json(CONFIG_PATH, "project configuration")
    lock = read_json(LOCK_PATH, "project lock")
    if options.update:
        update_lock(config, lock, PROJECT_ROOT)
        lock = read_canonical(LOCK_PATH, "project lock")
        effective = build_effective(PROJECT_ROOT, config, lock)
        EFFECTIVE_PATH.write_bytes(canonical(effective, newline=True))
        dry_events, dev_events = build_event_fixtures(effective)
        write_jsonl(DRY_RUN_EVENTS_PATH, dry_events)
        write_jsonl(DEV_EVENTS_PATH, dev_events)

    lock = read_canonical(LOCK_PATH, "project lock")
    effective = read_canonical(EFFECTIVE_PATH, "effective inputs")
    dry_events = read_jsonl(DRY_RUN_EVENTS_PATH, "dry-run events")
    dev_events = read_jsonl(DEV_EVENTS_PATH, "dev events")

    validate_config(config, validators["project"], PROJECT_ROOT)
    validate_lock(lock, validators["lock"], config, PROJECT_ROOT)
    validate_effective(effective, validators["effective"], config, lock, PROJECT_ROOT)
    validate_events(dry_events, validators["event"])
    validate_events(dev_events, validators["event"])

    baseline = build_effective(PROJECT_ROOT, config, lock)
    replay = build_effective(PROJECT_ROOT, config, lock)
    if baseline != replay:
        raise ContractError("effective-input discovery is not deterministic")
    runtime_a = build_effective(
        PROJECT_ROOT, config, lock, runtime_environment={"WP_DB_PASSWORD": "first-local-value"}
    )
    runtime_b = build_effective(
        PROJECT_ROOT, config, lock, runtime_environment={"WP_DB_PASSWORD": "second-local-value"}
    )
    if runtime_a != runtime_b or runtime_a != baseline:
        raise ContractError("runtime-only environment changed the build fingerprint")
    build_override = build_effective(
        PROJECT_ROOT, config, lock, build_environment={"SITE_LOCALE": "es_MX"}
    )
    if build_override["fingerprint"] == baseline["fingerprint"]:
        raise ContractError("declared public build environment did not change the fingerprint")
    if build_override["compileServer"]["compatibilityDigest"] == baseline["compileServer"]["compatibilityDigest"]:
        raise ContractError("build environment did not invalidate compiler-server compatibility")
    expect_error(
        "runtime secret admitted as build input",
        lambda: build_effective(
            PROJECT_ROOT, config, lock, build_environment={"WP_DB_PASSWORD": "forbidden"}
        ),
    )
    expect_error(
        "undeclared build environment admitted",
        lambda: build_effective(PROJECT_ROOT, config, lock, build_environment={"UNDECLARED": "x"}),
    )

    with tempfile.TemporaryDirectory(prefix="wordpresshx-adr016-") as temporary:
        temporary_project = Path(temporary) / "project"
        shutil.copytree(PROJECT_ROOT, temporary_project)
        before_dry_run = tree_digest(temporary_project)
        _ = build_effective(temporary_project, config, lock)
        after_dry_run = tree_digest(temporary_project)
        if before_dry_run != after_dry_run:
            raise ContractError("dry-run discovery mutated the consumer project")

        added = temporary_project / "src" / "acme" / "site" / "Added.hx"
        added.write_text("package acme.site;\nclass Added {}\n", encoding="utf-8")
        added_graph = build_effective(temporary_project, config, lock)
        if added_graph["fingerprint"] == baseline["fingerprint"]:
            raise ContractError("new source discovered under a watch root did not change fingerprint")
        added.unlink()

        hxml = temporary_project / ".wphx" / "bootstrap" / "project.hxml"
        original_hxml = hxml.read_bytes()
        hxml.write_bytes(original_hxml + b"\n")
        hxml_graph = build_effective(temporary_project, config, lock)
        if (
            hxml_graph["compileServer"]["compatibilityDigest"]
            == baseline["compileServer"]["compatibilityDigest"]
        ):
            raise ContractError("HXML change did not invalidate compiler-server compatibility")
        hxml.write_bytes(original_hxml)

        output = temporary_project / "build" / "wordpress" / "ignored.php"
        output.parent.mkdir(parents=True)
        output.write_text("<?php // generated output\n", encoding="utf-8")
        output_graph = build_effective(temporary_project, config, lock)
        if output_graph != baseline:
            raise ContractError("generated output entered the effective-input graph")
        output.unlink()

        symlink = temporary_project / "src" / "acme" / "site" / "Linked.hx"
        symlink.symlink_to(temporary_project / "src" / "acme" / "site" / "Site.hx")
        expect_error(
            "symlink source admitted",
            lambda: build_effective(temporary_project, config, lock),
        )
        symlink.unlink()

        fifo = temporary_project / "assets" / "special-input"
        os.mkfifo(fifo)
        expect_error(
            "special asset input admitted",
            lambda: build_effective(temporary_project, config, lock),
        )
        fifo.unlink()

    negative_count = run_negative_matrix(
        validators, config, lock, effective, dry_events, dev_events
    )
    summary = {
        "schemaCount": len(schemas),
        "effectiveFileCount": len(effective["files"]),
        "discoveryRootCount": len(effective["discoveryRoots"]),
        "toolchainComponentCount": len(effective["toolchain"]),
        "dryRunEventCount": len(dry_events),
        "devEventCount": len(dev_events),
        "negativeMutationCount": negative_count + 4,
        "fingerprint": effective["fingerprint"],
        "compileServerCompatibilityDigest": effective["compileServer"]["compatibilityDigest"],
        "outcome": "passed",
    }
    print("PROJECT_CLI_CONTRACT_SUMMARY=" + canonical(summary).decode("utf-8"))


if __name__ == "__main__":
    main()
