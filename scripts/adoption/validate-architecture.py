#!/usr/bin/env python3
"""Independently validate the proposed ADR-015 adoption contract architecture."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATHS = {
    "contract": ROOT / "schemas" / "adoption-contract.schema.json",
    "capability": ROOT / "schemas" / "adoption-capability.schema.json",
    "review": ROOT / "schemas" / "adoption-review.schema.json",
}
DOCUMENT_PATHS = {
    "contract": ROOT
    / "fixtures"
    / "adoption-contract"
    / "contract"
    / "acme-calendar.contract.json",
    "capability": ROOT
    / "fixtures"
    / "adoption-contract"
    / "contract"
    / "acme-calendar.capability.json",
    "review": ROOT
    / "fixtures"
    / "adoption-contract"
    / "contract"
    / "acme-calendar.review.json",
}
ARCHITECTURE_PATH = ROOT / "manifests" / "adoption-contract-architecture.json"
TRANSCRIPT_PATH = (
    ROOT / "fixtures" / "adoption-contract" / "expected" / "capability-plan.txt"
)
GENERATOR_INPUT_PATH = (
    ROOT / "fixtures" / "adoption-contract" / "inputs" / "generator.txt"
)


class ValidationError(ValueError):
    pass


def strict_json(text: str, label: str) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ValidationError(f"{label}: duplicate key {key}")
            result[key] = value
        return result

    def reject_float(value: str) -> object:
        raise ValidationError(f"{label}: floating point is forbidden: {value}")

    try:
        return json.loads(
            text,
            object_pairs_hook=pairs,
            parse_float=reject_float,
            parse_constant=reject_float,
        )
    except json.JSONDecodeError as error:
        raise ValidationError(f"{label}: malformed JSON: {error}") from error


def canonical(value: object) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require_dict(value: object, location: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{location}: expected object")
    return value


def require_list(value: object, location: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{location}: expected array")
    return value


def require_string(value: object, location: str) -> str:
    if not isinstance(value, str):
        raise ValidationError(f"{location}: expected string")
    return value


class ClosedSchemaValidator:
    def __init__(self, schema: dict[str, object]) -> None:
        self.schema = schema

    def resolve(self, reference: str) -> dict[str, object]:
        if not reference.startswith("#/"):
            raise ValidationError(f"external schema reference is forbidden: {reference}")
        current: object = self.schema
        for component in reference[2:].split("/"):
            if not isinstance(current, dict) or component not in current:
                raise ValidationError(f"unresolvable schema reference: {reference}")
            current = current[component]
        return require_dict(current, reference)

    def validate(
        self,
        value: object,
        schema: dict[str, object] | None = None,
        location: str = "$",
    ) -> None:
        current = schema or self.schema
        reference = current.get("$ref")
        if isinstance(reference, str):
            self.validate(value, self.resolve(reference), location)
            return

        alternatives = current.get("oneOf")
        if isinstance(alternatives, list):
            matches = 0
            for alternative in alternatives:
                try:
                    self.validate(value, require_dict(alternative, location), location)
                    matches += 1
                except ValidationError:
                    pass
            if matches != 1:
                raise ValidationError(
                    f"{location}: expected exactly one schema branch, matched {matches}"
                )
            return

        if "const" in current and value != current["const"]:
            raise ValidationError(
                f"{location}: expected {current['const']!r}, found {value!r}"
            )
        enumeration = current.get("enum")
        if isinstance(enumeration, list) and value not in enumeration:
            raise ValidationError(f"{location}: value is outside the closed enum")

        expected_type = current.get("type")
        if isinstance(expected_type, str):
            self.require_type(value, expected_type, location)

        if isinstance(value, str):
            minimum_length = current.get("minLength")
            if isinstance(minimum_length, int) and len(value) < minimum_length:
                raise ValidationError(f"{location}: string is too short")
            pattern = current.get("pattern")
            if isinstance(pattern, str) and re.fullmatch(pattern, value) is None:
                raise ValidationError(f"{location}: string does not match {pattern}")

        if isinstance(value, int) and not isinstance(value, bool):
            minimum = current.get("minimum")
            if isinstance(minimum, int) and value < minimum:
                raise ValidationError(f"{location}: integer is below {minimum}")
            maximum = current.get("maximum")
            if isinstance(maximum, int) and value > maximum:
                raise ValidationError(f"{location}: integer is above {maximum}")

        if isinstance(value, list):
            minimum_items = current.get("minItems")
            if isinstance(minimum_items, int) and len(value) < minimum_items:
                raise ValidationError(f"{location}: array has too few items")
            if current.get("uniqueItems") is True:
                encoded = [canonical(item) for item in value]
                if len(encoded) != len(set(encoded)):
                    raise ValidationError(f"{location}: array items are not unique")
            item_schema = current.get("items")
            if isinstance(item_schema, dict):
                for index, item in enumerate(value):
                    self.validate(item, item_schema, f"{location}[{index}]")

        if isinstance(value, dict):
            required = require_list(current.get("required", []), f"{location}.required")
            for field in required:
                if field not in value:
                    raise ValidationError(f"{location}: missing required field {field}")
            properties = require_dict(
                current.get("properties", {}), f"{location}.properties"
            )
            unknown = sorted(set(value) - set(properties))
            if current.get("additionalProperties") is False and unknown:
                raise ValidationError(
                    f"{location}: unknown field(s): {', '.join(unknown)}"
                )
            for field, child in value.items():
                child_schema = properties.get(field)
                if isinstance(child_schema, dict):
                    self.validate(child, child_schema, f"{location}.{field}")

    @staticmethod
    def require_type(value: object, expected: str, location: str) -> None:
        matches = {
            "object": isinstance(value, dict),
            "array": isinstance(value, list),
            "string": isinstance(value, str),
            "integer": isinstance(value, int) and not isinstance(value, bool),
            "boolean": isinstance(value, bool),
            "null": value is None,
        }.get(expected)
        if matches is None:
            raise ValidationError(f"{location}: unsupported schema type {expected}")
        if not matches:
            raise ValidationError(f"{location}: expected {expected}")


def require_closed_objects(value: object, location: str = "$schema") -> None:
    if isinstance(value, dict):
        if value.get("type") == "object" and value.get("additionalProperties") is not False:
            raise ValidationError(f"{location}: object schema is not closed")
        reference = value.get("$ref")
        if isinstance(reference, str) and not reference.startswith("#/"):
            raise ValidationError(f"{location}: external reference is forbidden")
        for key, child in value.items():
            require_closed_objects(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            require_closed_objects(child, f"{location}[{index}]")


def self_digest(document: dict[str, object], field: str) -> str:
    payload = copy.deepcopy(document)
    payload.pop(field, None)
    return sha256(canonical(payload).encode("utf-8"))


def validate_relative_path(raw: object, location: str) -> Path:
    value = require_string(raw, location)
    posix = PurePosixPath(value)
    if posix.is_absolute() or ".." in posix.parts or "." in posix.parts:
        raise ValidationError(f"{location}: path is not a clean project-relative path")
    resolved = ROOT.joinpath(*posix.parts).resolve()
    try:
        resolved.relative_to(ROOT.resolve())
    except ValueError as error:
        raise ValidationError(f"{location}: path escapes repository") from error
    if not resolved.is_file() or resolved.is_symlink():
        raise ValidationError(f"{location}: input is not a real regular file")
    return resolved


INPUT_AUTHORITY = {
    "provider-stub": ("authoritative-signature", 1),
    "typescript-declaration": ("authoritative-signature", 1),
    "block-metadata": ("authoritative-signature", 1),
    "rest-schema": ("authoritative-signature", 1),
    "reflection-snapshot": ("isolated-reflection", 2),
    "package-metadata": ("package-or-source-signature", 3),
    "source-signature": ("package-or-source-signature", 3),
    "plugin-header": ("package-or-source-signature", 3),
    "provider-runtime-source": ("package-or-source-signature", 3),
    "documentation-metadata": ("documentation", 4),
    "curated-contract": ("curated", 5),
}


def walk_type(value: dict[str, object], location: str) -> list[dict[str, object]]:
    result = [value]
    kind = value.get("kind")
    if kind in {"list", "nullable"}:
        result.extend(
            walk_type(require_dict(value.get("value"), f"{location}.value"), f"{location}.value")
        )
    return result


def validate_contract(contract: dict[str, object]) -> dict[str, dict[str, object]]:
    if contract.get("contractDigest") != self_digest(contract, "contractDigest"):
        raise ValidationError("contract self digest is stale")
    if contract.get("contractVersion") != "1.0.0":
        raise ValidationError("fixture contract version changed")

    profile = require_dict(contract.get("profile"), "contract.profile")
    catalog_path = ROOT / "generated" / "wp70-release" / "catalog-v1" / "catalog.json"
    if profile.get("catalogSha256") != sha256(catalog_path.read_bytes()):
        raise ValidationError("contract profile catalog digest is stale")

    generation = require_dict(contract.get("generation"), "contract.generation")
    generator = require_dict(generation.get("generator"), "contract.generation.generator")
    if generator.get("sha256") != sha256(GENERATOR_INPUT_PATH.read_bytes()):
        raise ValidationError("contract generator digest is stale")

    inputs = require_list(generation.get("inputs"), "contract.generation.inputs")
    input_records: dict[str, dict[str, object]] = {}
    source_lines: list[str] = []
    input_ids: list[str] = []
    for index, input_value in enumerate(inputs):
        record = require_dict(input_value, f"contract.generation.inputs[{index}]")
        input_id = require_string(record.get("id"), f"input[{index}].id")
        if input_id in input_records:
            raise ValidationError(f"duplicate input id {input_id}")
        kind = require_string(record.get("kind"), f"input[{index}].kind")
        expected = INPUT_AUTHORITY.get(kind)
        if expected != (record.get("authorityClass"), record.get("precedence")):
            raise ValidationError(f"input {input_id} authority precedence changed")
        path = validate_relative_path(record.get("path"), f"input[{index}].path")
        digest = sha256(path.read_bytes())
        if record.get("sha256") != digest:
            raise ValidationError(f"input {input_id} digest is stale")
        if generation.get("mode") == "static-no-execution" and record.get("executed") is not False:
            raise ValidationError(f"static generation executed input {input_id}")
        if kind != "reflection-snapshot" and record.get("executed") is not False:
            raise ValidationError(f"non-reflection input {input_id} was executed")
        input_records[input_id] = record
        input_ids.append(input_id)
        source_lines.append(f"{digest}  {path.name}\n")
    if input_ids != sorted(input_ids):
        raise ValidationError("contract inputs are not sorted by stable id")
    if generation.get("mode") == "static-no-execution":
        if generation.get("reflection") is not None:
            raise ValidationError("static generation retained a reflection receipt")
        if any(record.get("kind") == "reflection-snapshot" for record in input_records.values()):
            raise ValidationError("static generation retained a reflection snapshot")
    else:
        if not isinstance(generation.get("reflection"), dict):
            raise ValidationError("reflection opt-in omitted its isolation receipt")
        if not any(
            record.get("kind") == "reflection-snapshot" and record.get("executed") is True
            for record in input_records.values()
        ):
            raise ValidationError("reflection opt-in omitted its executed snapshot")

    provider = require_dict(contract.get("provider"), "contract.provider")
    if provider.get("sourceSha256") != sha256("".join(sorted(source_lines)).encode("utf-8")):
        raise ValidationError("provider source tree digest is stale")
    plugin_source = input_records.get("plugin-source")
    if plugin_source is None or provider.get("artifactSha256") != plugin_source.get("sha256"):
        raise ValidationError("provider artifact identity is not bound to the fixture artifact")

    bindings = require_list(contract.get("bindings"), "contract.bindings")
    binding_records: dict[str, dict[str, object]] = {}
    binding_ids: list[str] = []
    native_pairs: set[tuple[object, object]] = set()
    for index, binding_value in enumerate(bindings):
        binding = require_dict(binding_value, f"contract.bindings[{index}]")
        binding_id = require_string(binding.get("id"), f"binding[{index}].id")
        if binding_id in binding_records:
            raise ValidationError(f"duplicate binding id {binding_id}")
        pair = (binding.get("target"), binding.get("nativeName"))
        if pair in native_pairs:
            raise ValidationError(f"duplicate native binding {pair}")
        native_pairs.add(pair)
        source = input_records.get(require_string(binding.get("sourceInputId"), "binding.sourceInputId"))
        if source is None:
            raise ValidationError(f"binding {binding_id} references an unknown input")
        target = binding.get("target")
        if source.get("target") not in {target, "provider"}:
            raise ValidationError(f"binding {binding_id} crosses source targets")
        parameters = require_list(binding.get("parameters"), f"binding {binding_id}.parameters")
        saw_optional = False
        for position, parameter_value in enumerate(parameters):
            parameter = require_dict(parameter_value, f"binding {binding_id}.parameters[{position}]")
            if parameter.get("position") != position:
                raise ValidationError(f"binding {binding_id} parameter positions are not contiguous")
            if parameter.get("requirement") == "optional":
                saw_optional = True
            elif saw_optional:
                raise ValidationError(f"binding {binding_id} requires a parameter after an optional one")
            nodes = walk_type(require_dict(parameter.get("type"), "parameter.type"), "parameter.type")
            if any(node.get("kind") == "void" for node in nodes):
                raise ValidationError(f"binding {binding_id} uses void as a parameter")
            if any(
                node.get("kind") == "native-nominal" and node.get("target") != target
                for node in nodes
            ):
                raise ValidationError(f"binding {binding_id} has a cross-target nominal parameter")
        return_nodes = walk_type(require_dict(binding.get("returnType"), "binding.returnType"), "binding.returnType")
        if any(
            node.get("kind") == "native-nominal" and node.get("target") != target
            for node in return_nodes
        ):
            raise ValidationError(f"binding {binding_id} has a cross-target nominal return")
        for node in [*return_nodes, *[node for parameter in parameters for node in walk_type(require_dict(require_dict(parameter, "parameter").get("type"), "parameter.type"), "parameter.type")]]:
            if node.get("kind") == "nullable" and require_dict(node.get("value"), "nullable.value").get("kind") == "nullable":
                raise ValidationError(f"binding {binding_id} has nested nullable types")
        binding_records[binding_id] = binding
        binding_ids.append(binding_id)
    if binding_ids != sorted(binding_ids):
        raise ValidationError("contract bindings are not sorted by stable id")
    return binding_records


def validate_capabilities(
    contract: dict[str, object],
    capability: dict[str, object],
    bindings: dict[str, dict[str, object]],
) -> dict[str, dict[str, object]]:
    if capability.get("capabilitySetDigest") != self_digest(
        capability, "capabilitySetDigest"
    ):
        raise ValidationError("capability set self digest is stale")
    contract_ref = require_dict(capability.get("contract"), "capability.contract")
    if contract_ref != {
        "id": contract.get("contractId"),
        "version": contract.get("contractVersion"),
        "sha256": contract.get("contractDigest"),
    }:
        raise ValidationError("capability set contract reference is stale")
    if capability.get("profile") != contract.get("profile"):
        raise ValidationError("capability set profile differs from contract")
    provider = require_dict(contract.get("provider"), "contract.provider")
    if capability.get("provider") != {
        "id": provider.get("id"),
        "version": provider.get("version"),
        "artifactSha256": provider.get("artifactSha256"),
    }:
        raise ValidationError("capability set provider identity differs from contract")
    capability_ref = require_dict(contract.get("capabilitySet"), "contract.capabilitySet")
    if capability_ref != {
        "id": capability.get("capabilitySetId"),
        "version": capability.get("capabilitySetVersion"),
    }:
        raise ValidationError("contract capability-set reference is stale")

    records: dict[str, dict[str, object]] = {}
    ids: list[str] = []
    covered: set[str] = set()
    for index, value in enumerate(
        require_list(capability.get("capabilities"), "capability.capabilities")
    ):
        record = require_dict(value, f"capability.capabilities[{index}]")
        capability_id = require_string(record.get("id"), f"capability[{index}].id")
        if capability_id in records:
            raise ValidationError(f"duplicate capability id {capability_id}")
        probe = require_dict(record.get("probe"), f"capability {capability_id}.probe")
        for binding_id_value in require_list(
            probe.get("requiredBindings"), f"capability {capability_id}.requiredBindings"
        ):
            binding_id = require_string(binding_id_value, "required binding id")
            binding = bindings.get(binding_id)
            if binding is None:
                raise ValidationError(f"capability {capability_id} references an unknown binding")
            if binding.get("capabilityId") != capability_id:
                raise ValidationError(f"binding {binding_id} belongs to another capability")
            target = record.get("target")
            if target != "cross-target" and binding.get("target") != target:
                raise ValidationError(f"capability {capability_id} crosses target ownership")
            if binding_id in covered:
                raise ValidationError(f"binding {binding_id} belongs to two capabilities")
            covered.add(binding_id)
        records[capability_id] = record
        ids.append(capability_id)
    if ids != sorted(ids):
        raise ValidationError("capabilities are not sorted by stable id")
    if covered != set(bindings):
        raise ValidationError("capabilities do not cover the exact admitted binding set")
    return records


def validate_review(
    contract: dict[str, object],
    review: dict[str, object],
    bindings: dict[str, dict[str, object]],
) -> None:
    if review.get("reportDigest") != self_digest(review, "reportDigest"):
        raise ValidationError("review report self digest is stale")
    if review.get("contract") != {
        "id": contract.get("contractId"),
        "version": contract.get("contractVersion"),
        "sha256": contract.get("contractDigest"),
    }:
        raise ValidationError("review contract reference is stale")
    provider = require_dict(contract.get("provider"), "contract.provider")
    if review.get("provider") != {
        "id": provider.get("id"),
        "version": provider.get("version"),
        "artifactSha256": provider.get("artifactSha256"),
    }:
        raise ValidationError("review provider reference is stale")
    generation = require_dict(contract.get("generation"), "contract.generation")
    if review.get("generator") != generation.get("generator"):
        raise ValidationError("review generator reference is stale")

    included_values = require_list(review.get("includedBindings"), "review.includedBindings")
    included = [require_string(value, "review included binding") for value in included_values]
    if included != sorted(bindings):
        raise ValidationError("review does not list the exact sorted admitted bindings")
    omissions = require_list(review.get("omissions"), "review.omissions")
    omission_names = [
        require_string(require_dict(value, "omission").get("nativeName"), "omission.nativeName")
        for value in omissions
    ]
    if omission_names != sorted(omission_names):
        raise ValidationError("review omissions are not sorted by native name")
    if len(omission_names) != len(set(omission_names)):
        raise ValidationError("review contains duplicate omissions")
    admitted_native = {
        require_string(binding.get("nativeName"), "binding.nativeName")
        for binding in bindings.values()
    }
    if admitted_native.intersection(omission_names):
        raise ValidationError("an omitted symbol was also admitted")
    input_records = {
        require_string(require_dict(value, "input").get("id"), "input.id"): require_dict(value, "input")
        for value in require_list(generation.get("inputs"), "generation.inputs")
    }
    for omission_value in omissions:
        omission = require_dict(omission_value, "omission")
        for source_id_value in require_list(omission.get("sourceInputIds"), "omission.sourceInputIds"):
            if require_string(source_id_value, "omission source id") not in input_records:
                raise ValidationError("omission references an unknown source input")

    conflicts = require_list(review.get("conflicts"), "review.conflicts")
    conflict_names: set[str] = set()
    for conflict_value in conflicts:
        conflict = require_dict(conflict_value, "conflict")
        name = require_string(conflict.get("nativeName"), "conflict.nativeName")
        conflict_names.add(name)
        stronger = input_records.get(require_string(conflict.get("strongerInputId"), "conflict.strongerInputId"))
        weaker = input_records.get(require_string(conflict.get("weakerInputId"), "conflict.weakerInputId"))
        if stronger is None or weaker is None:
            raise ValidationError("conflict references an unknown input")
        stronger_rank = stronger.get("precedence")
        weaker_rank = weaker.get("precedence")
        if not isinstance(stronger_rank, int) or not isinstance(weaker_rank, int) or stronger_rank >= weaker_rank:
            raise ValidationError("conflict precedence is not stronger-before-weaker")
    omitted_conflicts = {
        require_string(require_dict(value, "omission").get("nativeName"), "omission.nativeName")
        for value in omissions
        if require_dict(value, "omission").get("code") == "conflicting-authority"
    }
    if conflict_names != omitted_conflicts:
        raise ValidationError("conflict inventory differs from conflict omissions")

    summary = require_dict(review.get("summary"), "review.summary")
    if summary != {
        "discovered": len(bindings) + len(omissions),
        "included": len(bindings),
        "omitted": len(omissions),
        "conflicts": len(conflicts),
    }:
        raise ValidationError("review summary counts are stale")
    reflection = require_dict(review.get("reflection"), "review.reflection")
    if generation.get("mode") == "static-no-execution" and reflection != {
        "requested": False,
        "executed": False,
        "isolationReceiptSha256": None,
    }:
        raise ValidationError("static review falsely records reflection")
    claims = require_dict(review.get("claims"), "review.claims")
    for field in (
        "providerRuntimeTested",
        "providerTrustAdmitted",
        "productionSupported",
        "implementationOwnershipTransferred",
    ):
        if claims.get(field) is not False:
            raise ValidationError(f"review overclaims {field}")
    if omissions and claims.get("reviewRequired") is not True:
        raise ValidationError("omissions did not retain review-required state")


def validate_documents(
    documents: dict[str, dict[str, object]],
    schemas: dict[str, dict[str, object]],
) -> None:
    for name in ("contract", "capability", "review"):
        ClosedSchemaValidator(schemas[name]).validate(documents[name])
    encoded = canonical(documents)
    if re.search(r"\b(?:Dynamic|Any|Reflect|untyped|cast)\b", encoded):
        raise ValidationError("serialized adoption proof contains a forbidden weak type")
    bindings = validate_contract(documents["contract"])
    validate_capabilities(documents["contract"], documents["capability"], bindings)
    validate_review(documents["contract"], documents["review"], bindings)


def mutation_corpus(
    documents: dict[str, dict[str, object]],
    schemas: dict[str, dict[str, object]],
) -> list[tuple[str, dict[str, dict[str, object]]]]:
    mutations: list[tuple[str, dict[str, dict[str, object]]]] = []

    def add(name: str, mutate: object) -> None:
        candidate = copy.deepcopy(documents)
        assert callable(mutate)
        mutate(candidate)
        mutations.append((name, candidate))

    def contract(candidate: dict[str, dict[str, object]]) -> dict[str, object]:
        return candidate["contract"]

    def capability(candidate: dict[str, dict[str, object]]) -> dict[str, object]:
        return candidate["capability"]

    def review(candidate: dict[str, dict[str, object]]) -> dict[str, object]:
        return candidate["review"]

    add("unknown-contract-field", lambda value: contract(value).__setitem__("surprise", True))
    add("stale-contract-digest", lambda value: contract(value).__setitem__("contractDigest", "0" * 64))
    add("wrong-profile", lambda value: require_dict(contract(value)["profile"], "profile").__setitem__("catalogSha256", "1" * 64))
    add("executed-static-input", lambda value: require_dict(require_list(require_dict(contract(value)["generation"], "generation")["inputs"], "inputs")[0], "input").__setitem__("executed", True))
    add("static-reflection", lambda value: require_dict(contract(value)["generation"], "generation").__setitem__("reflection", {}))
    add("wrong-precedence", lambda value: require_dict(require_list(require_dict(contract(value)["generation"], "generation")["inputs"], "inputs")[0], "input").__setitem__("precedence", 5))
    add("traversal-input", lambda value: require_dict(require_list(require_dict(contract(value)["generation"], "generation")["inputs"], "inputs")[0], "input").__setitem__("path", "../secret"))
    add("stale-input-hash", lambda value: require_dict(require_list(require_dict(contract(value)["generation"], "generation")["inputs"], "inputs")[0], "input").__setitem__("sha256", "2" * 64))
    add("unsorted-inputs", lambda value: require_list(require_dict(contract(value)["generation"], "generation")["inputs"], "inputs").reverse())
    add("missing-binding-source", lambda value: require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding").__setitem__("sourceInputId", "missing-source"))
    add("duplicate-binding", lambda value: require_list(contract(value)["bindings"], "bindings").append(copy.deepcopy(require_list(contract(value)["bindings"], "bindings")[0])))
    add("cross-target-source", lambda value: require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding").__setitem__("sourceInputId", "php-stubs"))
    add("parameter-gap", lambda value: require_dict(require_list(require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding")["parameters"], "parameters")[0], "parameter").__setitem__("position", 2))
    add("void-parameter", lambda value: require_dict(require_list(require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding")["parameters"], "parameters")[0], "parameter").__setitem__("type", {"kind": "void"}))
    add("cross-target-nominal", lambda value: require_dict(require_list(require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding")["parameters"], "parameters")[0], "parameter").__setitem__("type", {"kind": "native-nominal", "target": "php", "name": "Wrong"}))
    add("unsorted-bindings", lambda value: require_list(contract(value)["bindings"], "bindings").reverse())
    add("serializable-token", lambda value: require_dict(capability(value)["authority"], "authority").__setitem__("tokenSerializable", True))
    add("cacheable-token", lambda value: require_dict(capability(value)["authority"], "authority").__setitem__("tokenCacheable", True))
    add("stale-token-authority", lambda value: require_dict(capability(value)["authority"], "authority").__setitem__("staleTokenAuthority", True))
    add("wrong-provider-version", lambda value: require_dict(capability(value)["provider"], "provider").__setitem__("version", "2.5.0"))
    add("unknown-required-binding", lambda value: require_list(require_dict(require_list(capability(value)["capabilities"], "capabilities")[0], "capability")["probe"]["requiredBindings"], "requiredBindings").append("missing.binding"))
    add("binding-capability-mismatch", lambda value: require_dict(require_list(contract(value)["bindings"], "bindings")[0], "binding").__setitem__("capabilityId", "calendar.read.php"))
    add("unsorted-capabilities", lambda value: require_list(capability(value)["capabilities"], "capabilities").reverse())
    add("stale-capability-digest", lambda value: capability(value).__setitem__("capabilitySetDigest", "3" * 64))
    add("stale-review-digest", lambda value: review(value).__setitem__("reportDigest", "4" * 64))
    add("review-summary", lambda value: require_dict(review(value)["summary"], "summary").__setitem__("omitted", 3))
    add("review-admits-omission", lambda value: require_list(review(value)["includedBindings"], "includedBindings").append("not-a-binding"))
    add("review-omission-source", lambda value: require_list(require_dict(require_list(review(value)["omissions"], "omissions")[0], "omission")["sourceInputIds"], "sourceInputIds").append("missing-source"))
    add("review-false-completion", lambda value: require_dict(review(value)["claims"], "claims").__setitem__("productionSupported", True))
    add("review-reflection", lambda value: require_dict(review(value)["reflection"], "reflection").__setitem__("executed", True))
    add("conflict-order", lambda value: require_dict(require_list(review(value)["conflicts"], "conflicts")[0], "conflict").__setitem__("strongerInputId", "plugin-source"))

    for name, candidate in mutations:
        try:
            validate_documents(candidate, schemas)
        except ValidationError:
            continue
        raise ValidationError(f"mutation unexpectedly passed: {name}")
    return mutations


def haxe_source_tree_digest() -> str:
    lines: list[str] = []
    fixture = ROOT / "fixtures" / "adoption-contract"
    for source_root in (fixture / "src", fixture / "test", fixture / "test-negative"):
        for path in source_root.rglob("*.hx"):
            relative = path.relative_to(ROOT).as_posix()
            lines.append(f"{sha256(path.read_bytes())}  {relative}\n")
    return sha256("".join(sorted(lines)).encode("utf-8"))


def validate_architecture(
    documents: dict[str, dict[str, object]], mutation_count: int
) -> None:
    architecture = require_dict(
        strict_json(ARCHITECTURE_PATH.read_text(encoding="utf-8"), "architecture"),
        "architecture",
    )
    if architecture.get("schemaVersion") != 1 or architecture.get("decisionId") != "ADR-015":
        raise ValidationError("architecture identity changed")
    if architecture.get("status") != "proposed-pending-fresh-review":
        raise ValidationError("architecture status overclaims acceptance")
    authority = require_dict(architecture.get("authority"), "architecture.authority")
    expected_authority = {
        "defaultExecution": "forbidden",
        "bindingPolicy": "precise-or-omitted",
        "sourceMerge": "one-complete-binding-no-field-splicing",
        "providerRuntimeOwner": "native-provider",
        "implementationOwnershipTransferred": False,
        "compilerProviderNameBranchesAllowed": False,
        "weakFallbackTypesAllowed": False,
        "capabilityTokensSerializable": False,
        "staleCapabilityAuthority": False,
    }
    if authority != expected_authority:
        raise ValidationError("architecture authority contract changed")
    if architecture.get("sourcePrecedence") != [
        "authoritative-signature",
        "isolated-reflection-opt-in",
        "package-or-source-signature",
        "documentation",
        "curated-contract",
    ]:
        raise ValidationError("architecture source precedence changed")
    prototype = require_dict(architecture.get("prototypeEvidence"), "prototypeEvidence")
    expected_hashes = {
        "contractSha256": documents["contract"]["contractDigest"],
        "capabilitySha256": documents["capability"]["capabilitySetDigest"],
        "reviewSha256": documents["review"]["reportDigest"],
        "sourceTreeSha256": haxe_source_tree_digest(),
        "transcriptSha256": sha256(TRANSCRIPT_PATH.read_bytes()),
        "contractSchemaSha256": sha256(SCHEMA_PATHS["contract"].read_bytes()),
        "capabilitySchemaSha256": sha256(SCHEMA_PATHS["capability"].read_bytes()),
        "reviewSchemaSha256": sha256(SCHEMA_PATHS["review"].read_bytes()),
    }
    for field, expected in expected_hashes.items():
        if prototype.get(field) != expected:
            raise ValidationError(f"architecture {field} is stale")
    expected_counts = {
        "bindingCount": 3,
        "capabilityCount": 2,
        "omissionCount": 4,
        "conflictCount": 1,
        "compileNegativeCount": 4,
        "independentMutationCount": mutation_count,
    }
    for field, expected in expected_counts.items():
        if prototype.get(field) != expected:
            raise ValidationError(f"architecture {field} changed")
    references = require_list(architecture.get("referenceReview"), "referenceReview")
    if len(references) != 3:
        raise ValidationError("architecture reference review inventory changed")
    for value in references:
        reference = require_dict(value, "reference")
        if not re.fullmatch(r"[0-9a-f]{40}", require_string(reference.get("commit"), "reference.commit")):
            raise ValidationError("reference commit is not immutable")
        if not re.fullmatch(r"[0-9a-f]{40}", require_string(reference.get("gitBlob"), "reference.gitBlob")):
            raise ValidationError("reference blob is not immutable")
        if not re.fullmatch(r"[0-9a-f]{64}", require_string(reference.get("sha256"), "reference.sha256")):
            raise ValidationError("reference hash is not immutable")
        if reference.get("copiedBytes") is not False:
            raise ValidationError("reference review copied source bytes")
    claims = require_dict(architecture.get("claims"), "claims")
    if claims.get("architectureDecision") != "proposed-pending-fresh-review":
        raise ValidationError("architecture decision claim changed")
    for field in (
        "productionGenerator",
        "isolatedReflectionRuntime",
        "realProviderRuntime",
        "wordpressRuntime",
        "providerTrustAdmission",
        "publicPackageConsumer",
        "productionSupport",
    ):
        if claims.get(field) != "not-tested":
            raise ValidationError(f"architecture overclaims {field}")


def main() -> None:
    schemas = {
        name: require_dict(
            strict_json(path.read_text(encoding="utf-8"), f"{name} schema"),
            f"{name} schema",
        )
        for name, path in SCHEMA_PATHS.items()
    }
    for schema in schemas.values():
        require_closed_objects(schema)
    documents = {
        name: require_dict(
            strict_json(path.read_text(encoding="utf-8"), name), name
        )
        for name, path in DOCUMENT_PATHS.items()
    }
    validate_documents(documents, schemas)
    mutations = mutation_corpus(documents, schemas)
    validate_architecture(documents, len(mutations))
    print(
        "ADR-015 adoption architecture passed "
        f"({len(mutations)} independent mutations)"
    )


if __name__ == "__main__":
    main()
