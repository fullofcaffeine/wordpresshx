#!/usr/bin/env python3
"""Validate SDK-040 macro-generated semantic plan and effective inputs."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
SEMANTIC_PLAN_MODULE_PATH = ROOT / "scripts" / "semantic-plan" / "test-contract.py"


def load_semantic_plan_contract():
    spec = importlib.util.spec_from_file_location(
        "wordpresshx_semantic_plan_contract", SEMANTIC_PLAN_MODULE_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load semantic-plan contract validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CONTRACT = load_semantic_plan_contract()
ContractError = CONTRACT.ContractError
NODE_SCHEMAS = {
    **CONTRACT.NODE_SCHEMAS,
    "wordpress-hx.semantic-node.development.service.v1": (
        "development.service",
        ROOT / "schemas" / "semantic-nodes" / "development-service.schema.json",
    ),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_canonical(path: Path, label: str) -> dict[str, object]:
    value = CONTRACT.read_canonical(path, label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected an object")
    return value


def safe_relative(value: str, label: str) -> None:
    pure = PurePosixPath(value)
    if (
        not value
        or value.startswith("/")
        or "\\" in value
        or pure.is_absolute()
        or any(part in ("", ".", "..") for part in pure.parts)
        or pure.as_posix() != value
    ):
        raise ContractError(f"{label}: unsafe logical path")


def resolve_input(path: str) -> Path:
    safe_relative(path, "effective input path")
    prefix = "@wordpress-hx/build/"
    if path.startswith(prefix):
        return ROOT / "packages" / "build" / "src" / path.removeprefix(prefix)
    return ROOT / path


def require_sorted_unique(
    values: list[object], key, label: str
) -> None:
    keys = [key(value) for value in values]
    if keys != sorted(keys):
        raise ContractError(f"{label}: not sorted")
    if len(keys) != len(set(keys)):
        raise ContractError(f"{label}: duplicate")


def validate_inputs(inputs: dict[str, object], plan: dict[str, object]) -> None:
    schema = CONTRACT.read_json(
        ROOT / "schemas" / "semantic-collector-inputs.schema.json",
        "semantic collector inputs schema",
    )
    CONTRACT.require_closed_schema(schema)
    CONTRACT.ClosedSchemaValidator(schema).validate(inputs)

    material = copy.deepcopy(inputs)
    material.pop("fingerprint", None)
    material.pop("planDigest", None)
    expected_fingerprint = sha256(CONTRACT.canonical(material))
    if inputs["fingerprint"] != expected_fingerprint:
        raise ContractError("$.fingerprint: canonical input fingerprint mismatch")
    if inputs["planDigest"] != plan["planDigest"]:
        raise ContractError("$.planDigest: input report does not bind semantic plan")
    if plan["project"]["sourceTreeSha256"] != inputs["fingerprint"]:
        raise ContractError("$.project.sourceTreeSha256: plan does not bind inputs")

    files = inputs["files"]
    require_sorted_unique(files, lambda item: item["path"], "$.files")
    roles: dict[str, list[dict[str, object]]] = {}
    for index, record in enumerate(files):
        path = str(record["path"])
        physical = resolve_input(path)
        if not physical.is_file() or physical.is_symlink():
            raise ContractError(f"$.files[{index}]: not a regular non-symlink file")
        data = physical.read_bytes()
        if record["sha256"] != sha256(data):
            raise ContractError(f"$.files[{index}].sha256: content mismatch")
        if record["byteLength"] != len(data):
            raise ContractError(f"$.files[{index}].byteLength: content mismatch")
        roles.setdefault(str(record["role"]), []).append(record)

    expected_role_counts = {
        "collector-config": 1,
        "collector-source": 24,
        "node-schema": 3,
        "profile-catalog": 1,
        "resource": 1,
        "source": 1,
        "toolchain-lock": 1,
    }
    actual_role_counts = {role: len(records) for role, records in roles.items()}
    if actual_role_counts != expected_role_counts:
        raise ContractError(
            f"$.files: unexpected role inventory {actual_role_counts!r}"
        )

    collector_material = [
        {"path": item["path"], "sha256": item["sha256"]}
        for item in roles["collector-source"]
    ]
    expected_collector_digest = sha256(CONTRACT.canonical(collector_material))
    if plan["generator"]["collectorSourceSha256"] != expected_collector_digest:
        raise ContractError(
            "$.generator.collectorSourceSha256: collector source inventory mismatch"
        )
    if (
        plan["generator"]["toolchainSha256"]
        != roles["toolchain-lock"][0]["sha256"]
    ):
        raise ContractError("$.generator.toolchainSha256: lock file mismatch")

    resources = inputs["resources"]
    require_sorted_unique(resources, lambda item: item["id"], "$.resources")
    resource_paths = {item["path"] for item in roles["resource"]}
    if {item["path"] for item in resources} != resource_paths:
        raise ContractError("$.resources: declared resources and file inputs differ")

    environment = inputs["environment"]
    require_sorted_unique(environment, lambda item: item["name"], "$.environment")
    if len(environment) != 1 or environment[0]["name"] != "SITE_LOCALE":
        raise ContractError("$.environment: unexpected public build input inventory")
    if environment[0]["valueSha256"] != sha256(b"en_US"):
        raise ContractError("$.environment: SITE_LOCALE value digest mismatch")
    serialized = CONTRACT.canonical(inputs)
    if b'en_US' in serialized or b'REQUIRED_PUBLIC_VALUE' in serialized:
        raise ContractError("$.environment: raw or undeclared environment value leaked")

    tools = inputs["tools"]
    require_sorted_unique(tools, lambda item: item["id"], "$.tools")
    lock = json.loads(resolve_input(str(roles["toolchain-lock"][0]["path"])).read_text())
    expected_tools = sorted(
        [
            {
                "id": item["id"],
                "version": item["version"],
                "identity": item["identity"],
                "lockEntrySha256": item["lockEntrySha256"],
            }
            for item in lock["components"]
        ],
        key=lambda item: item["id"],
    )
    if tools != expected_tools:
        raise ContractError("$.tools: generated project-lock identities differ")


def validate_plan(plan: dict[str, object], inputs: dict[str, object]) -> None:
    schema = CONTRACT.read_json(
        ROOT / "schemas" / "semantic-plan.schema.json", "semantic plan schema"
    )
    CONTRACT.require_closed_schema(schema, allow_open_payload=True)
    CONTRACT.ClosedSchemaValidator(schema).validate(plan)
    if CONTRACT.canonical(plan) != CONTRACT.canonical(CONTRACT.normalize_plan(plan)):
        raise ContractError("semantic plan set fields are not canonical")
    if plan["planDigest"] != CONTRACT.digest_without(
        plan, "planDigest", CONTRACT.normalize_plan
    ):
        raise ContractError("$.planDigest: canonical digest mismatch")

    profile = plan["profile"]
    catalog = json.loads(
        (
            ROOT
            / "generated"
            / str(profile["profileId"])
            / str(profile["catalogRevision"]).split("/", 1)[1]
            / "catalog.json"
        ).read_text()
    )
    if profile["catalogSha256"] != catalog["catalogDigest"]:
        raise ContractError("$.profile.catalogSha256: catalog mismatch")
    capabilities = {
        item["capabilityId"] for item in catalog["catalog"]["capabilities"]
    }

    registrations = plan["nodeSchemas"]
    require_sorted_unique(
        registrations, lambda item: item["schemaId"], "$.nodeSchemas"
    )
    registry = {item["schemaId"]: item for item in registrations}
    for item in registrations:
        schema_id = item["schemaId"]
        if schema_id not in NODE_SCHEMAS:
            raise ContractError(f"$.nodeSchemas: unregistered schema {schema_id}")
        expected_kind, schema_path = NODE_SCHEMAS[schema_id]
        if item["kind"] != expected_kind:
            raise ContractError("$.nodeSchemas: kind mismatch")
        if item["schemaSha256"] != sha256(schema_path.read_bytes()):
            raise ContractError("$.nodeSchemas: schema digest mismatch")

    nodes = plan["nodes"]
    require_sorted_unique(nodes, lambda item: item["id"], "$.nodes")
    by_id = {item["id"]: item for item in nodes}
    projection_ids: set[str] = set()
    for index, node in enumerate(nodes):
        label = f"$.nodes[{index}]"
        schema_id = node["schemaId"]
        if schema_id not in registry or schema_id not in NODE_SCHEMAS:
            raise ContractError(f"{label}.schemaId: schema is not registered")
        registration = registry[schema_id]
        if registration["kind"] != node["kind"]:
            raise ContractError(f"{label}.kind: registration mismatch")
        _, schema_path = NODE_SCHEMAS[schema_id]
        node_schema = CONTRACT.read_json(schema_path, "semantic node schema")
        CONTRACT.ClosedSchemaValidator(node_schema).validate(
            node["payload"], location=f"{label}.payload"
        )
        CONTRACT.validate_source_span(node["source"], f"{label}.source")
        require_sorted_unique(
            node["dependsOn"], lambda item: item, f"{label}.dependsOn"
        )
        for dependency in node["dependsOn"]:
            if dependency not in by_id:
                raise ContractError(f"{label}.dependsOn: unknown dependency")
        require_sorted_unique(
            node["profileCapabilities"],
            lambda item: item,
            f"{label}.profileCapabilities",
        )
        if set(node["profileCapabilities"]) - capabilities:
            raise ContractError(f"{label}.profileCapabilities: profile mismatch")
        require_sorted_unique(
            node["projections"],
            lambda item: item["projectionId"],
            f"{label}.projections",
        )
        for projection in node["projections"]:
            if projection["projectionId"] in projection_ids:
                raise ContractError(f"{label}.projections: duplicate")
            projection_ids.add(projection["projectionId"])
            if projection["emitterId"] not in registration["consumerEmitters"]:
                raise ContractError(f"{label}.projections: unregistered emitter")
    CONTRACT.detect_cycles(by_id)

    if len(nodes) != 3 or len(registrations) != 3:
        raise ContractError("semantic collector fixture breadth changed")

    service = by_id.get("service/wordpress")
    if service is None:
        raise ContractError("semantic collector fixture lacks inferred WordPress service")
    expected_service = {
        "serviceId": "wordpress",
        "serviceKind": "wordpress",
        "dependsOn": [],
        "workingDirectory": ".",
        "command": None,
        "environment": [],
        "port": {"preferred": 8888, "strict": False},
        "readiness": {
            "kind": "http",
            "path": "/wp-json/",
            "text": "",
            "timeoutMs": 60000,
            "intervalMs": 100,
        },
        "restart": {"maxAttempts": 1, "backoffMs": 250},
        "url": {"scheme": "http", "path": "/"},
        "reload": "full-page",
    }
    if service["payload"] != expected_service:
        raise ContractError("inferred WordPress development service defaults drifted")
    if service["dependsOn"] or service["profileCapabilities"]:
        raise ContractError("inferred WordPress development service gained dependencies")
    if service["projections"] != [
        {
            "projectionId": "dev/service/wordpress",
            "emitterId": "wordpresshx.dev",
            "artifactKind": "development.service",
        }
    ]:
        raise ContractError("inferred WordPress development service projection drifted")
    validate_inputs(inputs, plan)


def validate_runtime(path: Path) -> None:
    source = path.read_text(encoding="utf-8")
    forbidden = (
        "wordpress.hx.build",
        "wordpress_hx_build",
        "SemanticCollector",
        "ModuleDeclaration",
        "HookDeclaration",
        "BuildInputDeclaration",
    )
    for token in forbidden:
        if token in source:
            raise ContractError(f"runtime output leaked compile-time token {token}")


def expect_failure(label: str, action, expected: str) -> None:
    try:
        action()
    except ContractError as error:
        if expected not in str(error):
            raise AssertionError(
                f"{label}: expected {expected!r}, found {str(error)!r}"
            ) from error
        return
    raise AssertionError(f"{label}: mutation unexpectedly passed")


def validate_mutations(inputs: dict[str, object], plan: dict[str, object]) -> int:
    mutations = 0

    changed = copy.deepcopy(inputs)
    changed["fingerprint"] = "0" * 64
    expect_failure(
        "input fingerprint",
        lambda: validate_inputs(changed, plan),
        "canonical input fingerprint mismatch",
    )
    mutations += 1

    changed = copy.deepcopy(inputs)
    changed["planDigest"] = "0" * 64
    expect_failure(
        "input plan binding",
        lambda: validate_inputs(changed, plan),
        "does not bind semantic plan",
    )
    mutations += 1

    changed = copy.deepcopy(inputs)
    changed["files"][0]["sha256"] = "0" * 64
    changed["fingerprint"] = sha256(
        CONTRACT.canonical(
            {key: value for key, value in changed.items() if key not in ("fingerprint", "planDigest")}
        )
    )
    changed_plan = copy.deepcopy(plan)
    changed_plan["project"]["sourceTreeSha256"] = changed["fingerprint"]
    expect_failure(
        "file content binding",
        lambda: validate_inputs(changed, changed_plan),
        "content mismatch",
    )
    mutations += 1

    changed = copy.deepcopy(inputs)
    changed["environment"][0]["rawValue"] = "en_US"
    expect_failure(
        "raw environment field",
        lambda: validate_inputs(changed, plan),
        "unknown field",
    )
    mutations += 1

    changed = copy.deepcopy(inputs)
    changed["tools"].reverse()
    changed["fingerprint"] = sha256(
        CONTRACT.canonical(
            {key: value for key, value in changed.items() if key not in ("fingerprint", "planDigest")}
        )
    )
    changed_plan = copy.deepcopy(plan)
    changed_plan["project"]["sourceTreeSha256"] = changed["fingerprint"]
    expect_failure(
        "tool order",
        lambda: validate_inputs(changed, changed_plan),
        "not sorted",
    )
    mutations += 1

    return mutations


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()

    config_schema = CONTRACT.read_json(
        ROOT / "schemas" / "semantic-collector-config.schema.json",
        "semantic collector config schema",
    )
    CONTRACT.require_closed_schema(config_schema)
    config = CONTRACT.read_json(
        ROOT / "fixtures" / "semantic-collector" / "config.json",
        "semantic collector config",
    )
    CONTRACT.ClosedSchemaValidator(config_schema).validate(config)

    plan = read_canonical(args.plan, "macro-generated semantic plan")
    inputs = read_canonical(args.inputs, "macro-generated semantic inputs")
    validate_plan(plan, inputs)
    validate_runtime(args.runtime)
    mutation_count = validate_mutations(inputs, plan)

    summary = {
        "collectorSourceCount": sum(
            1 for item in inputs["files"] if item["role"] == "collector-source"
        ),
        "environmentCount": len(inputs["environment"]),
        "fileCount": len(inputs["files"]),
        "fingerprint": inputs["fingerprint"],
        "negativeMutationCount": mutation_count,
        "nodeCount": len(plan["nodes"]),
        "outcome": "passed",
        "planDigest": plan["planDigest"],
        "resourceCount": len(inputs["resources"]),
        "toolCount": len(inputs["tools"]),
    }
    architecture = CONTRACT.read_json(
        ROOT / "manifests" / "semantic-collector-architecture.json",
        "semantic collector architecture",
    )
    verification = architecture["verification"]
    expected = {
        "collectorSourceCount": verification["collectorSourceCount"],
        "environmentCount": verification["environmentCount"],
        "fileCount": verification["effectiveFileCount"],
        "fingerprint": verification["effectiveInputsFingerprint"],
        "negativeMutationCount": verification["negativeSchemaMutationCount"],
        "nodeCount": verification["nodeCount"],
        "outcome": verification["outcome"],
        "planDigest": verification["planDigest"],
        "resourceCount": verification["resourceCount"],
        "toolCount": verification["toolCount"],
    }
    if summary != expected:
        raise ContractError("generated collector summary drifted from architecture lock")
    if (
        plan["generator"]["collectorSourceSha256"]
        != verification["collectorSourceSha256"]
    ):
        raise ContractError("collector source digest drifted from architecture lock")
    print("SEMANTIC_COLLECTOR_SUMMARY=" + CONTRACT.canonical(summary).decode())


if __name__ == "__main__":
    main()
