#!/usr/bin/env python3
"""Independently validate the proposed ADR-015 adoption contract architecture."""

from __future__ import annotations

import copy
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATHS = {
    "contract": ROOT / "schemas" / "adoption-contract.schema.json",
    "capability": ROOT / "schemas" / "adoption-capability.schema.json",
    "review": ROOT / "schemas" / "adoption-review.schema.json",
    "bundle": ROOT / "schemas" / "adoption-bundle.schema.json",
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
    "bundle": ROOT
    / "fixtures"
    / "adoption-contract"
    / "contract"
    / "acme-calendar.bundle.json",
}
OWNERSHIP_PATH = (
    ROOT
    / "fixtures"
    / "adoption-contract"
    / "contract"
    / "acme-calendar.generated-files.json"
)
ARCHITECTURE_PATH = ROOT / "manifests" / "adoption-contract-architecture.json"
RECEIPT_PATH = ROOT / "manifests" / "evidence" / "adr-015-interop-adoption-contract.json"
CLI_LOCK_PATH = ROOT / "packages" / "cli" / "dependency-lock.json"
TRANSCRIPT_PATH = (
    ROOT / "fixtures" / "adoption-contract" / "expected" / "capability-plan.txt"
)
GENERATOR_PATH = ROOT / "scripts" / "adoption" / "generate-fixture.py"


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


def deterministic_provider_archive() -> bytes:
    entries = [
        "fixtures/adoption-contract/inputs/index.js",
        "fixtures/adoption-contract/inputs/package-metadata.json",
        "fixtures/adoption-contract/inputs/plugin.php",
    ]
    output = io.BytesIO()
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for relative in entries:
            info = zipfile.ZipInfo(relative, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (ROOT / relative).read_bytes())
    return output.getvalue()


def validate_source_span(
    value: object,
    inputs: dict[str, dict[str, object]],
    location: str,
) -> bytes:
    span = require_dict(value, location)
    input_id = require_string(span.get("inputId"), f"{location}.inputId")
    source = inputs.get(input_id)
    if source is None:
        raise ValidationError(f"{location}: unknown input {input_id}")
    path = validate_relative_path(span.get("path"), f"{location}.path")
    if span.get("path") != source.get("path"):
        raise ValidationError(f"{location}: span path differs from its input")
    start = span.get("startByte")
    end = span.get("endByte")
    if not isinstance(start, int) or isinstance(start, bool):
        raise ValidationError(f"{location}: invalid start byte")
    if not isinstance(end, int) or isinstance(end, bool) or end <= start:
        raise ValidationError(f"{location}: invalid end byte")
    source_bytes = path.read_bytes()
    if end > len(source_bytes):
        raise ValidationError(f"{location}: source span exceeds input")
    selected = source_bytes[start:end]
    if span.get("sha256") != sha256(selected):
        raise ValidationError(f"{location}: source span digest is stale")
    return selected


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
        pattern = value.get("pattern")
        if isinstance(pattern, str) and not (
            pattern.startswith("^") and pattern.endswith("$")
        ):
            raise ValidationError(
                f"{location}: public JSON Schema pattern is not whole-string anchored"
            )
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
    if generator.get("sha256") != sha256(GENERATOR_PATH.read_bytes()):
        raise ValidationError("contract generator digest is stale")

    inputs = require_list(generation.get("inputs"), "contract.generation.inputs")
    input_records: dict[str, dict[str, object]] = {}
    source_entries: list[tuple[str, str]] = []
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
        source_entries.append((path.relative_to(ROOT).as_posix(), digest))
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
    source_material = "".join(
        f"{digest}  {relative}\n" for relative, digest in sorted(source_entries)
    )
    if provider.get("sourceSha256") != sha256(source_material.encode("utf-8")):
        raise ValidationError("provider source tree digest is stale")
    if provider.get("artifactFormat") != "deterministic-fixture-zip-v1":
        raise ValidationError("provider artifact format changed")
    if provider.get("artifactSha256") != sha256(deterministic_provider_archive()):
        raise ValidationError("provider artifact identity is not bound to the deterministic archive")

    bindings = require_list(contract.get("bindings"), "contract.bindings")
    binding_records: dict[str, dict[str, object]] = {}
    binding_ids: list[str] = []
    native_pairs: set[tuple[object, object]] = set()
    expected_abi: dict[str, tuple[list[dict[str, object]], dict[str, object]]] = {
        "js.calendar.badge": (
            [{"kind": "native-nominal", "target": "javascript", "name": "CalendarBadgeProps"}],
            {"kind": "javascript-object"},
        ),
        "js.calendar.format-label": ([{"kind": "javascript-number"}], {"kind": "string"}),
        "php.calendar.event.construct": (
            [{"kind": "string"}],
            {"kind": "native-nominal", "target": "php", "name": "Acme\\Calendar\\Event"},
        ),
        "php.calendar.event.title": ([], {"kind": "string"}),
        "php.calendar.list-events": (
            [{"kind": "php-int"}],
            {
                "kind": "list",
                "value": {
                    "kind": "native-nominal",
                    "target": "php",
                    "name": "Acme\\Calendar\\Event",
                },
            },
        ),
    }
    expected_signatures = {
        "js.calendar.badge": "function CalendarBadge(props: CalendarBadgeProps): object",
        "js.calendar.format-label": "function formatCalendarLabel(count: number): string",
        "php.calendar.event.construct": "function __construct(string $eventTitle): mixed",
        "php.calendar.event.title": "function title(): string",
        "php.calendar.list-events": "function list_events(int $limit): array",
    }
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
        source_evidence = require_dict(
            binding.get("sourceEvidence"), f"binding {binding_id}.sourceEvidence"
        )
        selected = validate_source_span(
            source_evidence.get("span"),
            input_records,
            f"binding {binding_id}.sourceEvidence.span",
        )
        local_name = require_string(binding.get("nativeName"), "binding.nativeName").rsplit(".", 1)[-1].rsplit("::", 1)[-1].rsplit("\\", 1)[-1]
        if local_name.encode("utf-8") not in selected:
            raise ValidationError(f"binding {binding_id} source span omits its symbol")
        if source_evidence.get("signatureSha256") != sha256(
            expected_signatures.get(binding_id, "").encode("utf-8")
        ):
            raise ValidationError(f"binding {binding_id} normalized signature is stale")
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
        expected = expected_abi.get(binding_id)
        actual_parameter_types = [
            require_dict(require_dict(value, "parameter").get("type"), "parameter.type")
            for value in parameters
        ]
        if expected is None or canonical(actual_parameter_types) != canonical(expected[0]) or canonical(binding.get("returnType")) != canonical(expected[1]):
            raise ValidationError(
                f"binding {binding_id} is stronger or different than its exact provider declaration"
            )
        binding_records[binding_id] = binding
        binding_ids.append(binding_id)
    if set(binding_records) != set(expected_abi):
        raise ValidationError("contract admitted binding inventory changed")
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
    authority = require_dict(capability.get("authority"), "capability.authority")
    if authority != {
        "tokenScope": "declared-per-capability",
        "tokenSerializable": False,
        "tokenCacheable": False,
        "staleTokenAuthority": False,
        "observationOwner": "target-runtime-adapter",
        "callerSuppliedFactsAllowed": False,
        "lifecycleIdentity": "generative-runtime-nonce",
        "scopeTypes": ["browser-module", "php-process", "php-request"],
        "sameNominalScopeInstanceReusable": False,
        "tokenBoundFacts": [
            "artifact-sha256",
            "bundle-digest",
            "capability-id",
            "lifecycle-kind",
            "observed-bindings",
            "provider-id",
            "provider-version",
            "runtime-nonce",
        ],
        "bundleVerification": "required-before-observation",
        "absenceBehavior": "typed-unavailable-with-core-fallback",
        "providerTrustAdmission": "separate-sdk-117-requirement",
    }:
        raise ValidationError("capability observation authority is forgeable or stale")

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
    expected_omission_signatures = {
        "@acme/calendar.CalendarRegistry": "const CalendarRegistry: Record<string, unknown>",
        "Acme\\Calendar\\Event::__call": "function __call(string $name, array $arguments): mixed",
        "Acme\\Calendar\\conditional_helper": "function conditional_helper(string $value): string",
        "Acme\\Calendar\\mutate_all": "function mutate_all(Event &...$events): void",
    }
    for omission_value in omissions:
        omission = require_dict(omission_value, "omission")
        for source_id_value in require_list(omission.get("sourceInputIds"), "omission.sourceInputIds"):
            if require_string(source_id_value, "omission source id") not in input_records:
                raise ValidationError("omission references an unknown source input")
        name = require_string(omission.get("nativeName"), "omission.nativeName")
        expected_signature = expected_omission_signatures.get(name)
        if expected_signature is None or omission.get("signatureSha256") != sha256(
            expected_signature.encode("utf-8")
        ):
            raise ValidationError(f"omission {name} signature is not source-authorized")
        span_values = require_list(omission.get("sourceSpans"), "omission.sourceSpans")
        span_input_ids: list[str] = []
        for span_index, span_value in enumerate(span_values):
            selected = validate_source_span(
                span_value,
                input_records,
                f"omission {name}.sourceSpans[{span_index}]",
            )
            span = require_dict(span_value, "omission source span")
            span_input_ids.append(require_string(span.get("inputId"), "span.inputId"))
            local_name = name.rsplit(".", 1)[-1].rsplit("::", 1)[-1].rsplit("\\", 1)[-1]
            if local_name.encode("utf-8") not in selected:
                raise ValidationError(f"omission {name} source span omits its symbol")
        if sorted(span_input_ids) != require_list(
            omission.get("sourceInputIds"), "omission.sourceInputIds"
        ):
            raise ValidationError(f"omission {name} source span inventory differs")
    if set(omission_names) != set(expected_omission_signatures):
        raise ValidationError("review omission inventory differs from provider declarations")

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
        stronger_bytes = validate_source_span(
            conflict.get("strongerSourceSpan"), input_records, "conflict.strongerSourceSpan"
        )
        weaker_bytes = validate_source_span(
            conflict.get("weakerSourceSpan"), input_records, "conflict.weakerSourceSpan"
        )
        if stronger_bytes == weaker_bytes:
            raise ValidationError("conflict source signatures do not conflict")
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


def validate_bundle(
    documents: dict[str, dict[str, object]], bundle: dict[str, object]
) -> None:
    if bundle.get("bundleDigest") != self_digest(bundle, "bundleDigest"):
        raise ValidationError("adoption bundle self digest is stale")
    contract = documents["contract"]
    provider = require_dict(contract.get("provider"), "contract.provider")
    if bundle.get("provider") != {
        "id": provider.get("id"),
        "version": provider.get("version"),
        "artifactSha256": provider.get("artifactSha256"),
    }:
        raise ValidationError("adoption bundle provider identity is stale")
    records = require_dict(bundle.get("records"), "bundle.records")
    expected_records = {
        "contract": (
            "generated/adoption/acme-calendar/contract.json",
            DOCUMENT_PATHS["contract"],
        ),
        "capability": (
            "generated/adoption/acme-calendar/capability.json",
            DOCUMENT_PATHS["capability"],
        ),
        "review": (
            "generated/adoption/acme-calendar/review.json",
            DOCUMENT_PATHS["review"],
        ),
    }
    for name, (path, current) in expected_records.items():
        record = require_dict(records.get(name), f"bundle.records.{name}")
        if record != {"path": path, "sha256": sha256(current.read_bytes())}:
            raise ValidationError(f"bundle {name} record is stale")
    ownership = require_dict(
        strict_json(OWNERSHIP_PATH.read_text(encoding="utf-8"), "ownership"),
        "ownership",
    )
    if ownership.get("manifestDigest") != self_digest(ownership, "manifestDigest"):
        raise ValidationError("adoption ownership manifest digest is stale")
    ownership_record = require_dict(records.get("ownership"), "bundle.records.ownership")
    if ownership_record != {
        "path": "generated/_GeneratedFiles.json",
        "sha256": sha256(OWNERSHIP_PATH.read_bytes()),
        "manifestDigest": ownership.get("manifestDigest"),
    }:
        raise ValidationError("bundle ownership record is stale")
    owned_files = {
        require_string(require_dict(value, "ownership file").get("path"), "ownership file.path"): (
            require_dict(value, "ownership file").get("contentSha256"),
            require_dict(value, "ownership file").get("sizeBytes"),
        )
        for value in require_list(ownership.get("files"), "ownership.files")
    }
    bundle_files = require_list(bundle.get("generatedFiles"), "bundle.generatedFiles")
    bundle_file_map = {
        require_string(require_dict(value, "bundle file").get("path"), "bundle file.path"): (
            require_dict(value, "bundle file").get("sha256"),
            require_dict(value, "bundle file").get("sizeBytes"),
        )
        for value in bundle_files
    }
    if bundle_file_map != owned_files:
        raise ValidationError("bundle file set differs from ADR-007 ownership authority")
    if [require_string(require_dict(value, "bundle file").get("path"), "bundle file.path") for value in bundle_files] != sorted(bundle_file_map):
        raise ValidationError("bundle files are not sorted")


def validate_haxe_authority(
    documents: dict[str, dict[str, object]], bundle: dict[str, object]
) -> None:
    adoption_path = (
        ROOT
        / "fixtures"
        / "adoption-contract"
        / "src"
        / "wordpress"
        / "hx"
        / "adoption"
        / "prototype"
        / "Adoption.hx"
    )
    calendar_path = adoption_path.with_name("AcmeCalendar.hx")
    probe_path = (
        ROOT
        / "fixtures"
        / "adoption-contract"
        / "test-support"
        / "wordpress"
        / "hx"
        / "adoption"
        / "prototype"
        / "testing"
        / "TargetProbe.hx"
    )
    adoption_source = adoption_path.read_text(encoding="utf-8")
    calendar_source = calendar_path.read_text(encoding="utf-8")
    probe_source = probe_path.read_text(encoding="utf-8")
    for forbidden in (
        "public static function beginRequest",
        "public static function observeExact",
        "public static function observeAbsent",
        "public static function runtime",
    ):
        if forbidden in adoption_source:
            raise ValidationError(f"application-facing Haxe authority is forgeable: {forbidden}")
    for required in (
        "final class PhpRequestScope",
        "final class PhpProcessScope",
        "final class BrowserModuleScope",
        "new LifecycleNonce()",
        "this.nonce == nonce",
        "final bundleDigest:String",
        "final observedBindings:Array<String>",
    ):
        if required not in adoption_source:
            raise ValidationError(f"Haxe lifecycle authority omitted {required}")
    provider = require_dict(documents["contract"].get("provider"), "contract.provider")
    identities = (
        require_string(provider.get("version"), "provider.version"),
        require_string(provider.get("artifactSha256"), "provider.artifactSha256"),
        require_string(bundle.get("bundleDigest"), "bundle.bundleDigest"),
    )
    for identity in identities:
        if calendar_source.count(identity) != 1 or probe_source.count(identity) != 1:
            raise ValidationError("Haxe runtime authority is not bound to the exact adoption bundle")


def validate_documents(
    documents: dict[str, dict[str, object]],
    schemas: dict[str, dict[str, object]],
) -> None:
    for name in ("contract", "capability", "review", "bundle"):
        ClosedSchemaValidator(schemas[name]).validate(documents[name])
    encoded = canonical(documents)
    if re.search(r"\b(?:Dynamic|Any|Reflect|untyped|cast)\b", encoded):
        raise ValidationError("serialized adoption proof contains a forbidden weak type")
    bindings = validate_contract(documents["contract"])
    validate_capabilities(documents["contract"], documents["capability"], bindings)
    validate_review(documents["contract"], documents["review"], bindings)
    validate_bundle(documents, documents["bundle"])
    validate_haxe_authority(documents, documents["bundle"])


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
    add("caller-supplied-provider-facts", lambda value: require_dict(capability(value)["authority"], "authority").__setitem__("callerSuppliedFactsAllowed", True))
    add("same-scope-instance-reuse", lambda value: require_dict(capability(value)["authority"], "authority").__setitem__("sameNominalScopeInstanceReusable", True))
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
    for source_root in (
        fixture / "src",
        fixture / "test-support",
        fixture / "test",
        fixture / "test-negative",
    ):
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
        "capabilityObservationOwner": "target-runtime-adapter",
        "callerSuppliedObservationFactsAllowed": False,
        "lifecycleIdentity": "generative-runtime-nonce",
        "sameNominalScopeInstanceReusable": False,
        "bundleVerificationBeforeCapabilityMint": True,
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
    contracts = require_dict(architecture.get("contracts"), "architecture.contracts")
    bundle_contract = require_dict(contracts.get("bundle"), "architecture.contracts.bundle")
    if bundle_contract != {
        "identity": "wordpress-hx.adoption-bundle.v1",
        "schema": "schemas/adoption-bundle.schema.json",
        "purpose": "one-digest-root-for-records-facades-and-ownership",
    }:
        raise ValidationError("architecture bundle contract changed")
    prototype = require_dict(architecture.get("prototypeEvidence"), "prototypeEvidence")
    expected_hashes = {
        "contractSha256": documents["contract"]["contractDigest"],
        "capabilitySha256": documents["capability"]["capabilitySetDigest"],
        "reviewSha256": documents["review"]["reportDigest"],
        "bundleDigest": documents["bundle"]["bundleDigest"],
        "bundleFileSha256": sha256(DOCUMENT_PATHS["bundle"].read_bytes()),
        "ownershipManifestSha256": sha256(OWNERSHIP_PATH.read_bytes()),
        "sourceTreeSha256": haxe_source_tree_digest(),
        "transcriptSha256": sha256(TRANSCRIPT_PATH.read_bytes()),
        "contractSchemaSha256": sha256(SCHEMA_PATHS["contract"].read_bytes()),
        "capabilitySchemaSha256": sha256(SCHEMA_PATHS["capability"].read_bytes()),
        "reviewSchemaSha256": sha256(SCHEMA_PATHS["review"].read_bytes()),
        "bundleSchemaSha256": sha256(SCHEMA_PATHS["bundle"].read_bytes()),
    }
    for field, expected in expected_hashes.items():
        if prototype.get(field) != expected:
            raise ValidationError(f"architecture {field} is stale")
    expected_counts = {
        "bindingCount": 5,
        "capabilityCount": 2,
        "omissionCount": 4,
        "conflictCount": 1,
        "compileNegativeCount": 6,
        "independentMutationCount": mutation_count,
    }
    for field, expected in expected_counts.items():
        if prototype.get(field) != expected:
            raise ValidationError(f"architecture {field} changed")
    cli_lock = require_dict(
        strict_json(CLI_LOCK_PATH.read_text(encoding="utf-8"), "CLI dependency lock"),
        "CLI dependency lock",
    )
    compiler = require_dict(cli_lock.get("compiler"), "CLI dependency lock.compiler")
    runtime = require_dict(cli_lock.get("runtime"), "CLI dependency lock.runtime")
    genes_version = require_string(compiler.get("version"), "compiler.version")
    genes_commit = require_string(compiler.get("commit"), "compiler.commit")
    node_version = require_string(runtime.get("version"), "runtime.version")
    targets = require_list(prototype.get("targets"), "prototype.targets")
    if len(targets) != 3 or targets[1] != (
        f"genes-ts-{genes_version}@{genes_commit}-typescript-5.9.3-node-{node_version}"
    ):
        raise ValidationError("architecture Genes target differs from the CLI dependency lock")
    if prototype.get("syntheticProviderRuntimeUsed") is not True:
        raise ValidationError("architecture omits the synthetic native-provider runtime proof")
    if prototype.get("productionOwnershipTransactionUsed") is not True:
        raise ValidationError("architecture omits the production ownership transaction proof")
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
    receipt = require_dict(
        strict_json(RECEIPT_PATH.read_text(encoding="utf-8"), "ADR-015 receipt"),
        "ADR-015 receipt",
    )
    verification = require_dict(receipt.get("verification"), "receipt.verification")
    if verification.get("genesVersion") != genes_version or verification.get("genesCommit") != genes_commit:
        raise ValidationError("receipt Genes identity differs from the CLI dependency lock")
    if verification.get("genesAuthority") != "packages/cli/dependency-lock.json":
        raise ValidationError("receipt Genes identity has no single lock authority")
    receipt_claims = require_dict(receipt.get("claims"), "receipt.claims")
    for architecture_field, receipt_field in (
        ("typedCapabilityPrototype", "typedCapabilityPrototype"),
        ("fixtureGenerator", "fixtureGenerator"),
        ("nativeSyntheticProviderRuntime", "nativeProviderAbi"),
        ("ownershipTransaction", "ownershipTransaction"),
    ):
        if claims.get(architecture_field) != receipt_claims.get(receipt_field):
            raise ValidationError(f"architecture claim {architecture_field} differs from its receipt authority")
    hosted = require_dict(receipt.get("hostedWorkflow"), "receipt.hostedWorkflow")
    architecture_hosted = require_dict(architecture.get("hostedGate"), "architecture.hostedGate")
    for field in ("job", "runId", "jobId", "commit", "status"):
        if architecture_hosted.get(field) != hosted.get(field):
            raise ValidationError(f"architecture hosted {field} differs from its receipt authority")
    if hosted.get("status") == "pending-current-main-run":
        if any(hosted.get(field) is not None for field in ("runId", "jobId", "commit")):
            raise ValidationError("pending hosted evidence carries a current run identity")
    elif hosted.get("status") == "passed-current-main":
        if not isinstance(hosted.get("runId"), int) or not isinstance(hosted.get("jobId"), int):
            raise ValidationError("passed hosted evidence omits its exact run identity")
        if re.fullmatch(r"[0-9a-f]{40}", require_string(hosted.get("commit"), "hosted.commit")) is None:
            raise ValidationError("passed hosted evidence omits its exact commit")
    else:
        raise ValidationError("ADR-015 hosted evidence state is not current")


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
