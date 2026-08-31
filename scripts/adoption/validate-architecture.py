#!/usr/bin/env python3
"""Check ADR-015 deterministic generation, semantics, and ownership consistency."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import platform
import re
import sys
from pathlib import Path, PurePosixPath

from abi_model import AbiModel, merge_model
from evidence_state import (
    evidence_subject_sha256,
    hosted_gate_identity,
    observer_identities,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "fixtures/adoption-contract"
INPUT_ROOT = FIXTURE / "inputs"
CONTRACT_ROOT = FIXTURE / "contract"
DOCUMENT_PATHS = {
    "contract": CONTRACT_ROOT / "acme-calendar.contract.json",
    "capability": CONTRACT_ROOT / "acme-calendar.capability.json",
    "review": CONTRACT_ROOT / "acme-calendar.review.json",
    "bundle": CONTRACT_ROOT / "acme-calendar.bundle.json",
}
SCHEMA_PATHS = {
    "contract": ROOT / "schemas/adoption-contract.schema.json",
    "capability": ROOT / "schemas/adoption-capability.schema.json",
    "review": ROOT / "schemas/adoption-review.schema.json",
    "bundle": ROOT / "schemas/adoption-bundle.schema.json",
}
OWNERSHIP_PATH = CONTRACT_ROOT / "acme-calendar.generated-files.json"
ARCHITECTURE_PATH = ROOT / "manifests/adoption-contract-architecture.json"
RECEIPT_PATH = ROOT / "manifests/evidence/adr-015-interop-adoption-contract.json"
TRANSCRIPT_PATH = FIXTURE / "expected/capability-plan.txt"
GENERATOR_PATH = ROOT / "scripts/adoption/generate-fixture.py"
ABI_MODEL_PATH = ROOT / "scripts/adoption/abi_model.py"
CLI_LOCK_PATH = ROOT / "packages/cli/dependency-lock.json"
TOOLCHAIN_LOCK_PATH = ROOT / "manifests/toolchain.lock.json"
ADOPTION_TOOLCHAIN_LOCK_PATH = ROOT / "manifests/adoption-contract-toolchain.lock.json"
NPM_LOCK_PATH = ROOT / "packages/gutenberg/build-tooling/package-lock.json"
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "wordpresshx_adoption_generator", GENERATOR_PATH
)
if GENERATOR_SPEC is None or GENERATOR_SPEC.loader is None:
    raise RuntimeError("cannot load the ADR-015 generator module")
GENERATOR_MODULE = importlib.util.module_from_spec(GENERATOR_SPEC)
sys.modules[GENERATOR_SPEC.name] = GENERATOR_MODULE
GENERATOR_SPEC.loader.exec_module(GENERATOR_MODULE)
CONTENT_ROOT = GENERATOR_MODULE.CONTENT_ROOT
browser_facade = GENERATOR_MODULE.browser_facade
canonical = GENERATOR_MODULE.canonical
deterministic_provider_archive = GENERATOR_MODULE.deterministic_provider_archive
php_facade = GENERATOR_MODULE.php_facade
provider_version = GENERATOR_MODULE.provider_version
runtime_bundle_policy = GENERATOR_MODULE.runtime_bundle_policy
static_member_bytes = GENERATOR_MODULE.static_member_bytes
CONTENT_BUNDLE_PATH = f"{CONTENT_ROOT}/adoption.bundle.json"


class ValidationError(ValueError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def self_digest(document: dict[str, object], field: str) -> str:
    value = copy.deepcopy(document)
    value.pop(field, None)
    return sha256(canonical(value))


def strict_json(path: Path) -> dict[str, object]:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ValidationError(f"{path}: duplicate key {key}")
            result[key] = value
        return result

    try:
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs)
    except json.JSONDecodeError as error:
        raise ValidationError(f"{path}: malformed JSON: {error}") from error
    if not isinstance(value, dict):
        raise ValidationError(f"{path}: expected one JSON object")
    return value


def require_dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{label} must be an object")
    return value


def require_list(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{label} must be an array")
    return value


def require_string(value: object, label: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ValidationError(f"{label} must be non-empty text")
    return value


class ClosedSchemaValidator:
    """Small independent validator for the JSON Schema features used here."""

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
        current = self.schema if schema is None else schema
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
                if not isinstance(field, str) or field not in value:
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


def logical_path(path: Path) -> str:
    return (
        Path("fixtures/adoption-contract/inputs") / path.relative_to(INPUT_ROOT)
    ).as_posix()


def clean_relative_path(value: object, label: str) -> str:
    text = require_string(value, label)
    path = PurePosixPath(text)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or "\\" in text:
        raise ValidationError(f"{label} is not a clean relative path")
    return text


def source_inputs(contract: dict[str, object]) -> dict[str, dict[str, object]]:
    generation = require_dict(contract.get("generation"), "contract.generation")
    records: dict[str, dict[str, object]] = {}
    ids: list[str] = []
    source_entries: list[tuple[str, str]] = []
    authority = {
        "typescript-declaration": ("authoritative-signature", 1),
        "provider-stub": ("authoritative-signature", 1),
        "provider-runtime-source": ("package-or-source-signature", 3),
        "package-metadata": ("package-or-source-signature", 3),
    }
    for index, raw in enumerate(require_list(generation.get("inputs"), "generation.inputs")):
        record = require_dict(raw, f"generation.inputs[{index}]")
        input_id = require_string(record.get("id"), "input.id")
        if input_id in records:
            raise ValidationError(f"duplicate source input: {input_id}")
        relative = clean_relative_path(record.get("path"), f"input {input_id}.path")
        path = ROOT / relative
        if not path.is_file() or path.is_symlink():
            raise ValidationError(f"input {input_id} is not a regular file")
        digest = sha256(path.read_bytes())
        if record.get("sha256") != digest or record.get("executed") is not False:
            raise ValidationError(f"input {input_id} identity or execution state is stale")
        kind = require_string(record.get("kind"), "input.kind")
        if authority.get(kind) != (record.get("authorityClass"), record.get("precedence")):
            raise ValidationError(f"input {input_id} precedence is stale")
        ids.append(input_id)
        records[input_id] = record
        source_entries.append((relative, digest))
    if ids != sorted(ids):
        raise ValidationError("source inputs are not sorted")
    if generation.get("mode") != "static-no-execution" or generation.get("reflection") is not None:
        raise ValidationError("fixture generation is not static")
    provider = require_dict(contract.get("provider"), "contract.provider")
    source_material = "".join(
        f"{digest}  {relative}\n" for relative, digest in sorted(source_entries)
    )
    if provider.get("sourceSha256") != sha256(source_material.encode("utf-8")):
        raise ValidationError("provider source tree identity is stale")
    archive = deterministic_provider_archive()
    if provider.get("artifactSha256") != sha256(archive):
        raise ValidationError("provider artifact is not the deterministic source archive")
    return records


def validate_span(
    raw: object,
    inputs: dict[str, dict[str, object]],
    label: str,
) -> bytes:
    span = require_dict(raw, label)
    if set(span) != {"inputId", "path", "startByte", "endByte", "sha256"}:
        raise ValidationError(f"{label} fields differ")
    input_id = require_string(span.get("inputId"), f"{label}.inputId")
    record = inputs.get(input_id)
    if record is None or span.get("path") != record.get("path"):
        raise ValidationError(f"{label} does not bind its source input")
    start = span.get("startByte")
    end = span.get("endByte")
    if not isinstance(start, int) or not isinstance(end, int) or start < 0 or end <= start:
        raise ValidationError(f"{label} byte range is invalid")
    source = (ROOT / require_string(span.get("path"), f"{label}.path")).read_bytes()
    if end > len(source):
        raise ValidationError(f"{label} byte range exceeds the source")
    selected = source[start:end]
    if span.get("sha256") != sha256(selected):
        raise ValidationError(f"{label} selected bytes are stale")
    return selected


def validate_contract(
    contract: dict[str, object],
    model: AbiModel,
) -> dict[str, dict[str, object]]:
    if (
        contract.get("schema") != "wordpress-hx.adoption-contract.v1"
        or contract.get("schemaVersion") != 1
        or contract.get("contractId") != "acme-calendar.wp70"
        or contract.get("contractVersion") != "1.0.0"
    ):
        raise ValidationError("contract identity changed")
    if contract.get("contractDigest") != self_digest(contract, "contractDigest"):
        raise ValidationError("contract self digest is stale")
    if contract.get("profile") != {
        "id": "wp70-release",
        "catalogRevision": "wp70-release/catalog-v1",
        "catalogSha256": "d86d1d887f1a3d8894831e3ec092201ee5caba57e88f4eeff59816d22dd9aa6e",
    }:
        raise ValidationError("contract profile authority changed")
    provider = require_dict(contract.get("provider"), "contract.provider")
    version = provider_version()
    archive = deterministic_provider_archive()
    if provider != {
        "id": "acme-calendar",
        "kind": "wordpress-plugin",
        "version": version,
        "artifactUrl": f"https://example.test/acme-calendar/acme-calendar.{version}.zip",
        "artifactSha256": sha256(archive),
        "artifactFormat": "deterministic-fixture-zip-v1",
        "sourceUrl": f"https://example.test/acme-calendar/source/{version}",
        "sourceRevision": f"fixture-acme-calendar-{version}",
        "sourceSha256": provider.get("sourceSha256"),
        "runtimeOwner": "native-provider",
        "implementationOwnership": "external-not-transferred",
    }:
        raise ValidationError("contract provider policy changed")
    generation = require_dict(contract.get("generation"), "contract.generation")
    if generation.get("mergePolicy") != "one-complete-binding-from-highest-nonconflicting-authority":
        raise ValidationError("contract merge policy changed")
    generator = require_dict(generation.get("generator"), "contract.generator")
    if generator != {
        "id": "wordpress-hx-adoption-generator",
        "version": "0.0.0-fixture",
        "sha256": sha256(GENERATOR_PATH.read_bytes()),
    }:
        raise ValidationError("contract generator identity is stale")
    inputs = source_inputs(contract)
    expected_inputs = {
        "browser-runtime": ("javascript", "provider-runtime-source"),
        "browser-types": ("javascript", "typescript-declaration"),
        "package-metadata": ("provider", "package-metadata"),
        "php-stubs": ("php", "provider-stub"),
        "plugin-source": ("wordpress", "provider-runtime-source"),
    }
    if set(inputs) != set(expected_inputs):
        raise ValidationError("contract source input inventory changed")
    for input_id, (target, kind) in expected_inputs.items():
        if inputs[input_id].get("target") != target or inputs[input_id].get("kind") != kind:
            raise ValidationError(f"input {input_id} target or kind changed")
    source_candidates = model.by_name()
    precise_names = {candidate.native_name for candidate in model.admitted()}
    expected_binding_policy = {
        "@acme/calendar.CalendarBadge": (
            "js.calendar.badge",
            "calendar.badge.browser",
        ),
        "@acme/calendar.formatCalendarLabel": (
            "js.calendar.format-label",
            "calendar.badge.browser",
        ),
        "Acme\\Calendar\\Event::__construct": (
            "php.calendar.event.construct",
            "calendar.read.php",
        ),
        "Acme\\Calendar\\Event::title": (
            "php.calendar.event.title",
            "calendar.read.php",
        ),
        "Acme\\Calendar\\list_events": (
            "php.calendar.list-events",
            "calendar.read.php",
        ),
    }
    bindings: dict[str, dict[str, object]] = {}
    native_names: set[str] = set()
    ids: list[str] = []
    for index, raw in enumerate(require_list(contract.get("bindings"), "contract.bindings")):
        binding = require_dict(raw, f"contract.bindings[{index}]")
        binding_id = require_string(binding.get("id"), "binding.id")
        native_name = require_string(binding.get("nativeName"), "binding.nativeName")
        candidate = source_candidates.get(native_name)
        if candidate is None or not candidate.precise:
            raise ValidationError(f"binding {binding_id} is not a precise source candidate")
        expected_identity = expected_binding_policy.get(native_name)
        if expected_identity != (binding_id, binding.get("capabilityId")):
            raise ValidationError(f"binding {binding_id} identity or capability policy changed")
        if binding_id in bindings or native_name in native_names:
            raise ValidationError("contract repeats a binding id or native name")
        evidence = require_dict(binding.get("sourceEvidence"), "binding.sourceEvidence")
        if evidence.get("signatureSha256") != candidate.declaration.signature_sha256:
            raise ValidationError(f"binding {binding_id} signature is stale")
        actual_spans = require_list(evidence.get("spans"), "binding.sourceEvidence.spans")
        expected_spans = [span.json() for span in candidate.spans]
        if actual_spans != expected_spans:
            raise ValidationError(f"binding {binding_id} source span inventory is stale")
        for span_index, span in enumerate(actual_spans):
            validate_span(span, inputs, f"binding {binding_id}.spans[{span_index}]")
        parameters = [
            parameter.json(position)
            for position, parameter in enumerate(candidate.declaration.parameters)
        ]
        if binding.get("parameters") != parameters or binding.get("returnType") != candidate.declaration.return_type.json():
            raise ValidationError(f"binding {binding_id} ABI differs from provider bytes")
        if binding.get("target") != candidate.declaration.target or binding.get("kind") != candidate.declaration.kind:
            raise ValidationError(f"binding {binding_id} target shape differs from provider bytes")
        if binding.get("sourceInputId") != candidate.declaration.spans[0].input_id:
            raise ValidationError(f"binding {binding_id} source authority changed")
        bindings[binding_id] = binding
        native_names.add(native_name)
        ids.append(binding_id)
    if native_names != precise_names:
        raise ValidationError("contract admission inventory differs from precise source candidates")
    if ids != sorted(ids):
        raise ValidationError("contract bindings are not sorted")
    if contract.get("capabilitySet") != {
        "id": "acme-calendar.capabilities",
        "version": "1.0.0",
    }:
        raise ValidationError("contract capability set identity changed")
    if contract.get("ownership") != {
        "providerRuntime": "external-native-provider",
        "contract": "cli-owned-generated",
        "applicationLogic": "haxe-authored",
        "compilerRecognition": "generic-contract-only-no-provider-name-branches",
        "regeneration": "private-stage-deterministic-diff-before-publication",
        "removal": "manifest-owned-complete-content-bundle-provider-source-untouched",
        "modifiedGeneratedFile": "fail-closed-no-overwrite-or-delete",
    }:
        raise ValidationError("contract ownership policy changed")
    return bindings


def validate_capability(
    contract: dict[str, object],
    capability: dict[str, object],
    bindings: dict[str, dict[str, object]],
) -> None:
    if (
        capability.get("schema") != "wordpress-hx.adoption-capability.v1"
        or capability.get("schemaVersion") != 1
        or capability.get("capabilitySetId") != "acme-calendar.capabilities"
        or capability.get("capabilitySetVersion") != "1.0.0"
    ):
        raise ValidationError("capability set identity changed")
    if capability.get("capabilitySetDigest") != self_digest(capability, "capabilitySetDigest"):
        raise ValidationError("capability self digest is stale")
    if capability.get("contract") != {
        "id": contract.get("contractId"),
        "version": contract.get("contractVersion"),
        "sha256": contract.get("contractDigest"),
    }:
        raise ValidationError("capability contract reference is stale")
    if capability.get("profile") != contract.get("profile"):
        raise ValidationError("capability profile differs from the contract")
    provider = require_dict(contract.get("provider"), "contract.provider")
    if capability.get("provider") != {
        "id": provider.get("id"),
        "version": provider.get("version"),
        "artifactSha256": provider.get("artifactSha256"),
    }:
        raise ValidationError("capability provider differs from the contract")
    expected_authority = {
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
            "bundle-digest",
            "capability-id",
            "lifecycle-kind",
            "observed-bindings",
            "provider-id",
            "provider-version",
            "runtime-nonce",
            "target-executable-closure-sha256",
        ],
        "bundleVerification": "required-before-observation",
        "absenceBehavior": "typed-unavailable-with-core-fallback",
        "providerTrustAdmission": "separate-sdk-117-requirement",
    }
    if capability.get("authority") != expected_authority:
        raise ValidationError("capability authority is forgeable or stale")
    covered: list[str] = []
    ids: list[str] = []
    expected_specs = {
        "calendar.badge.browser": (
            "javascript",
            "browser-module",
            True,
            "javascript-exports",
        ),
        "calendar.read.php": (
            "php",
            "request",
            False,
            "wordpress-plugin-and-symbols",
        ),
    }
    for raw in require_list(capability.get("capabilities"), "capabilities"):
        record = require_dict(raw, "capability")
        capability_id = require_string(record.get("id"), "capability.id")
        expected_spec = expected_specs.get(capability_id)
        if expected_spec is None:
            raise ValidationError(f"unknown capability policy: {capability_id}")
        target, scope, optional, probe_kind = expected_spec
        if (
            record.get("target") != target
            or record.get("scope") != scope
            or record.get("optional") != optional
        ):
            raise ValidationError(f"capability {capability_id} target policy changed")
        probe = require_dict(record.get("probe"), "capability.probe")
        if (
            probe.get("kind") != probe_kind
            or probe.get("versionMatch") != "exact"
            or probe.get("artifactMatch") != "target-executable-closure-sha256"
            or probe.get("executableClosureSha256")
            != (
                sha256((INPUT_ROOT / "plugin.php").read_bytes())
                if target == "php"
                else GENERATOR_MODULE.browser_executable_closure_sha256(
                    sha256((INPUT_ROOT / "index.js").read_bytes()),
                    sha256((INPUT_ROOT / "package-metadata.json").read_bytes()),
                )
            )
            or probe.get("conditionalFailure")
            != "unavailable-not-partially-authorized"
        ):
            raise ValidationError(f"capability {capability_id} probe policy changed")
        required = [require_string(value, "required binding") for value in require_list(probe.get("requiredBindings"), "requiredBindings")]
        native = [require_string(value, "required symbol") for value in require_list(probe.get("requiredNativeSymbols"), "requiredNativeSymbols")]
        selected = [bindings[value] for value in required if value in bindings]
        if len(selected) != len(required):
            raise ValidationError(f"capability {capability_id} references an unknown binding")
        if [value.get("nativeName") for value in selected] != native:
            raise ValidationError(f"capability {capability_id} native symbols are stale")
        if any(value.get("capabilityId") != capability_id for value in selected):
            raise ValidationError(f"capability {capability_id} crosses binding ownership")
        ids.append(capability_id)
        covered.extend(required)
    if (
        ids != sorted(ids)
        or set(ids) != set(expected_specs)
        or sorted(covered) != sorted(bindings)
        or len(covered) != len(set(covered))
    ):
        raise ValidationError("capabilities do not exactly partition admitted bindings")


def validate_review(
    contract: dict[str, object],
    review: dict[str, object],
    bindings: dict[str, dict[str, object]],
    model: AbiModel,
) -> None:
    if (
        review.get("schema") != "wordpress-hx.adoption-review.v1"
        or review.get("schemaVersion") != 1
        or review.get("reportId") != "acme-calendar.review.1"
    ):
        raise ValidationError("review identity changed")
    if review.get("reportDigest") != self_digest(review, "reportDigest"):
        raise ValidationError("review self digest is stale")
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
        raise ValidationError("review provider differs from the contract")
    generation = require_dict(contract.get("generation"), "contract.generation")
    if review.get("generator") != generation.get("generator"):
        raise ValidationError("review generator differs from the contract")
    if review.get("reflection") != {
        "requested": False,
        "executed": False,
        "isolationReceiptSha256": None,
    }:
        raise ValidationError("review reflection state changed")
    if review.get("claims") != {
        "evidenceStage": "contract-generated",
        "reviewRequired": True,
        "providerRuntimeTested": False,
        "providerTrustAdmitted": False,
        "productionSupported": False,
        "implementationOwnershipTransferred": False,
    }:
        raise ValidationError("review claims are stale or overbroad")
    included = require_list(review.get("includedBindings"), "review.includedBindings")
    if included != sorted(bindings):
        raise ValidationError("review admission inventory is stale")
    inputs = source_inputs(contract)
    expected = {candidate.native_name: candidate for candidate in model.omitted()}
    seen: set[str] = set()
    for raw in require_list(review.get("omissions"), "review.omissions"):
        omission = require_dict(raw, "review omission")
        name = require_string(omission.get("nativeName"), "omission.nativeName")
        candidate = expected.get(name)
        if candidate is None or name in seen:
            raise ValidationError("review omission inventory is stale")
        wanted = {
            "code": candidate.omission_code,
            "reason": candidate.omission_reason,
            "requiredAction": candidate.required_action,
            "signatureSha256": candidate.declaration.signature_sha256,
            "sourceInputIds": sorted({span.input_id for span in candidate.spans}),
            "sourceSpans": [span.json() for span in candidate.spans],
            "target": candidate.declaration.target,
            "kind": candidate.declaration.kind,
        }
        for field, value in wanted.items():
            if omission.get(field) != value:
                raise ValidationError(f"omission {name} {field} is stale")
        for index, span in enumerate(require_list(omission.get("sourceSpans"), "omission spans")):
            validate_span(span, inputs, f"omission {name}.spans[{index}]")
        seen.add(name)
    if seen != set(expected):
        raise ValidationError("review omits a source candidate disposition")
    expected_conflicts = [
        {
            "nativeName": candidate.native_name,
            "strongerInputId": candidate.declaration.spans[0].input_id,
            "weakerInputId": candidate.runtime.spans[0].input_id,
            "strongerSourceSpan": candidate.declaration.spans[0].json(),
            "weakerSourceSpan": candidate.runtime.spans[0].json(),
            "resolution": "omit-binding-and-report",
        }
        for candidate in model.omitted()
        if candidate.omission_code == "conflicting-authority"
    ]
    if review.get("conflicts") != expected_conflicts:
        raise ValidationError("review conflict inventory differs from parsed source conflicts")
    summary = require_dict(review.get("summary"), "review.summary")
    if summary != {
        "discovered": len(model.candidates),
        "included": len(model.admitted()),
        "omitted": len(model.omitted()),
        "conflicts": len(expected_conflicts),
    }:
        raise ValidationError("review summary is stale")


def expected_member_bytes(
    documents: dict[str, dict[str, object]],
    model: AbiModel,
) -> dict[str, tuple[str, bytes]]:
    version = provider_version()
    provider_archive = deterministic_provider_archive()
    static_members = static_member_bytes(model, documents, provider_archive, version)
    return static_members


def validate_bundle(
    documents: dict[str, dict[str, object]],
    model: AbiModel,
) -> None:
    bundle = documents["bundle"]
    if bundle.get("bundleDigest") != self_digest(bundle, "bundleDigest"):
        raise ValidationError("content bundle self digest is stale")
    expected_bytes = expected_member_bytes(documents, model)
    expected_members = [
        {
            "role": role,
            "path": path,
            "sha256": sha256(content),
            "sizeBytes": len(content),
        }
        for path, (role, content) in sorted(expected_bytes.items())
    ]
    if bundle.get("members") != expected_members:
        raise ValidationError("content bundle members differ from generated semantic bytes")
    for path, (_, content) in expected_bytes.items():
        generated_path = CONTRACT_ROOT / path
        if (
            not generated_path.is_file()
            or generated_path.is_symlink()
            or generated_path.read_bytes() != content
        ):
            raise ValidationError(f"checked-in bundle member bytes are stale: {path}")
    provider = require_dict(documents["contract"].get("provider"), "contract.provider")
    if bundle.get("provider") != {
        "id": provider.get("id"),
        "version": provider.get("version"),
        "artifactSha256": provider.get("artifactSha256"),
    }:
        raise ValidationError("content bundle provider identity is stale")

    ownership = strict_json(OWNERSHIP_PATH)
    if ownership.get("manifestDigest") != self_digest(ownership, "manifestDigest"):
        raise ValidationError("ownership manifest self digest is stale")
    actual_files = {
        require_string(require_dict(raw, "ownership file").get("path"), "ownership file.path"): (
            require_dict(raw, "ownership file").get("contentSha256"),
            require_dict(raw, "ownership file").get("sizeBytes"),
        )
        for raw in require_list(ownership.get("files"), "ownership.files")
    }
    bundle_bytes = DOCUMENT_PATHS["bundle"].read_bytes()
    expected_files = {
        path: (sha256(content), len(content))
        for path, (_, content) in expected_bytes.items()
    }
    expected_files[CONTENT_BUNDLE_PATH] = (sha256(bundle_bytes), len(bundle_bytes))
    static_policy = runtime_bundle_policy(expected_bytes)
    provider_artifact_sha256 = require_string(provider.get("artifactSha256"), "provider artifact")
    module_sha256 = sha256((INPUT_ROOT / "index.js").read_bytes())
    package_sha256 = sha256((INPUT_ROOT / "package-metadata.json").read_bytes())
    anchors = {
        f"{CONTENT_ROOT}/browser/acme-calendar-facade.mjs": browser_facade(
            provider_version(), module_sha256, package_sha256, provider_artifact_sha256,
            static_policy, require_string(bundle.get("bundleDigest"), "bundle digest"),
            GENERATOR_MODULE.browser_executable_closure_sha256(module_sha256, package_sha256),
        ),
        f"{CONTENT_ROOT}/php/acme-calendar-facade.php": php_facade(
            provider_version(), sha256((INPUT_ROOT / "plugin.php").read_bytes()),
            provider_artifact_sha256, static_policy,
            require_string(bundle.get("bundleDigest"), "bundle digest"),
        ),
    }
    expected_files.update({path: (sha256(content), len(content)) for path, content in anchors.items()})
    if actual_files != expected_files:
        raise ValidationError("ArtifactOwner manifest does not own the bundle and every member")
    if "generated/_GeneratedFiles.json" in {
        require_string(require_dict(raw, "bundle member").get("path"), "bundle member.path")
        for raw in require_list(bundle.get("members"), "bundle.members")
    }:
        raise ValidationError("content bundle creates an ownership digest cycle")


def validate_haxe_authority() -> None:
    adoption = (FIXTURE / "src/wordpress/hx/adoption/prototype/Adoption.hx").read_text(encoding="utf-8")
    calendar = (FIXTURE / "src/wordpress/hx/adoption/prototype/AcmeCalendar.hx").read_text(encoding="utf-8")
    if "@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)" in adoption:
        raise ValidationError("legacy exact-path friend grant remains")
    if "@:allow(" in adoption:
        raise ValidationError("production Haxe authority still depends on a spoofable friend path")
    if "public final requiredBindings:Array<String>" in adoption:
        raise ValidationError("capability bindings remain caller-mutable")
    for required in (
        "requiredBindingIds():Array<String>",
        "return bindings.copy()",
        "private final class AuthorityKey",
        "key.verify()",
        "private final class AuthorityCore",
        "final class PhpAcmeCalendarAdapter",
        "final class BrowserAcmeCalendarAdapter",
        "GeneratedPhpFacade.open",
        "GeneratedBrowserFacade.openExactProvider",
    ):
        if required not in adoption:
            raise ValidationError(f"source-owned Haxe adapter omits {required}")
    if "FixtureTargetAdapter" in adoption or "adoption_contract_test" in adoption:
        raise ValidationError("product Haxe source exposes fixture authority minting")
    if "GeneratedAcmeCalendar.provider" not in calendar:
        raise ValidationError("authored Haxe entry point is detached from generated ABI")
    forbidden = re.compile(r"\b(?:Dynamic|Any|Reflect|untyped|cast)\b")
    for path in (FIXTURE / "src").rglob("*.hx"):
        if forbidden.search(path.read_text(encoding="utf-8")):
            raise ValidationError(f"forbidden weak Haxe type in {path.relative_to(ROOT)}")


def validate_documents(
    documents: dict[str, dict[str, object]],
    model: AbiModel,
    schemas: dict[str, dict[str, object]],
) -> None:
    for name, document in documents.items():
        ClosedSchemaValidator(schemas[name]).validate(document)
    bindings = validate_contract(documents["contract"], model)
    validate_capability(documents["contract"], documents["capability"], bindings)
    validate_review(documents["contract"], documents["review"], bindings, model)
    validate_bundle(documents, model)
    validate_haxe_authority()


def redigest(document: dict[str, object], field: str) -> None:
    document[field] = self_digest(document, field)


def mutation_corpus(
    documents: dict[str, dict[str, object]],
    model: AbiModel,
    schemas: dict[str, dict[str, object]],
) -> list[str]:
    mutations: list[tuple[str, str, object, bool]] = []
    digest_fields = {
        "contract": "contractDigest",
        "capability": "capabilitySetDigest",
        "review": "reportDigest",
        "bundle": "bundleDigest",
    }

    def add(
        layer: str,
        name: str,
        change: object,
        *,
        refresh_digest: bool = True,
    ) -> None:
        mutations.append((layer, name, change, refresh_digest))

    def layer(value: dict[str, dict[str, object]], name: str) -> dict[str, object]:
        return value[name]

    def generation(value: dict[str, dict[str, object]]) -> dict[str, object]:
        return require_dict(layer(value, "contract").get("generation"), "generation")

    def inputs(value: dict[str, dict[str, object]]) -> list[object]:
        return require_list(generation(value).get("inputs"), "inputs")

    def bindings(value: dict[str, dict[str, object]]) -> list[object]:
        return require_list(layer(value, "contract").get("bindings"), "bindings")

    def authority(value: dict[str, dict[str, object]]) -> dict[str, object]:
        return require_dict(layer(value, "capability").get("authority"), "authority")

    def capabilities(value: dict[str, dict[str, object]]) -> list[object]:
        return require_list(layer(value, "capability").get("capabilities"), "capabilities")

    def omissions(value: dict[str, dict[str, object]]) -> list[object]:
        return require_list(layer(value, "review").get("omissions"), "omissions")

    def members(value: dict[str, dict[str, object]]) -> list[object]:
        return require_list(layer(value, "bundle").get("members"), "members")

    # Contract schema, source authority, ABI, and ownership policy adversaries.
    add("contract", "unknown-contract-field", lambda value: layer(value, "contract").__setitem__("surprise", True))
    add("contract", "stale-contract-digest", lambda value: layer(value, "contract").__setitem__("contractDigest", "0" * 64), refresh_digest=False)
    add("contract", "wrong-contract-identity", lambda value: layer(value, "contract").__setitem__("contractId", "acme-calendar.other"))
    add("contract", "wrong-profile", lambda value: require_dict(layer(value, "contract").get("profile"), "profile").__setitem__("catalogSha256", "1" * 64))
    add("contract", "wrong-provider-id", lambda value: require_dict(layer(value, "contract").get("provider"), "provider").__setitem__("id", "other-provider"))
    add("contract", "wrong-provider-artifact", lambda value: require_dict(layer(value, "contract").get("provider"), "provider").__setitem__("artifactSha256", "2" * 64))
    add("contract", "wrong-provider-source", lambda value: require_dict(layer(value, "contract").get("provider"), "provider").__setitem__("sourceSha256", "3" * 64))
    add("contract", "wrong-generator-id", lambda value: require_dict(generation(value).get("generator"), "generator").__setitem__("id", "other-generator"))
    add("contract", "wrong-generator-hash", lambda value: require_dict(generation(value).get("generator"), "generator").__setitem__("sha256", "4" * 64))
    add("contract", "wrong-merge-policy", lambda value: generation(value).__setitem__("mergePolicy", "field-splicing"))
    add("contract", "executed-static-input", lambda value: require_dict(inputs(value)[0], "input").__setitem__("executed", True))
    add("contract", "static-reflection", lambda value: generation(value).__setitem__("reflection", {}))
    add("contract", "wrong-precedence", lambda value: require_dict(inputs(value)[0], "input").__setitem__("precedence", 5))
    add("contract", "wrong-authority-class", lambda value: require_dict(inputs(value)[0], "input").__setitem__("authorityClass", "authoritative-signature"))
    add("contract", "wrong-input-target", lambda value: require_dict(inputs(value)[0], "input").__setitem__("target", "php"))
    add("contract", "wrong-input-kind", lambda value: require_dict(inputs(value)[0], "input").__setitem__("kind", "provider-stub"))
    add("contract", "traversal-input", lambda value: require_dict(inputs(value)[0], "input").__setitem__("path", "../secret"))
    add("contract", "stale-input-hash", lambda value: require_dict(inputs(value)[0], "input").__setitem__("sha256", "5" * 64))
    add("contract", "unsorted-inputs", lambda value: inputs(value).reverse())
    add("contract", "missing-binding-source", lambda value: require_dict(bindings(value)[0], "binding").__setitem__("sourceInputId", "missing-source"))
    add("contract", "duplicate-binding", lambda value: bindings(value).append(copy.deepcopy(bindings(value)[0])))
    add("contract", "cross-target-source", lambda value: require_dict(bindings(value)[0], "binding").__setitem__("sourceInputId", "php-stubs"))
    add("contract", "binding-capability-mismatch", lambda value: require_dict(bindings(value)[0], "binding").__setitem__("capabilityId", "calendar.read.php"))
    add("contract", "binding-return-abi", lambda value: require_dict(bindings(value)[0], "binding").__setitem__("returnType", {"kind": "string"}))
    add("contract", "binding-span-range", lambda value: require_dict(require_list(require_dict(require_dict(bindings(value)[0], "binding").get("sourceEvidence"), "sourceEvidence").get("spans"), "spans")[0], "span").__setitem__("startByte", 1))
    add("contract", "binding-span-hash", lambda value: require_dict(require_list(require_dict(require_dict(bindings(value)[0], "binding").get("sourceEvidence"), "sourceEvidence").get("spans"), "spans")[0], "span").__setitem__("sha256", "6" * 64))
    add("contract", "binding-signature", lambda value: require_dict(require_dict(bindings(value)[0], "binding").get("sourceEvidence"), "sourceEvidence").__setitem__("signatureSha256", "7" * 64))
    add("contract", "parameter-gap", lambda value: require_dict(require_list(require_dict(bindings(value)[0], "binding").get("parameters"), "parameters")[0], "parameter").__setitem__("position", 2))
    add("contract", "void-parameter", lambda value: require_dict(require_list(require_dict(bindings(value)[0], "binding").get("parameters"), "parameters")[0], "parameter").__setitem__("type", {"kind": "void"}))
    add("contract", "cross-target-nominal", lambda value: require_dict(require_list(require_dict(bindings(value)[0], "binding").get("parameters"), "parameters")[0], "parameter").__setitem__("type", {"kind": "native-nominal", "target": "php", "name": "Wrong"}))
    add("contract", "unsorted-bindings", lambda value: bindings(value).reverse())
    add("contract", "missing-precise-binding", lambda value: bindings(value).pop())
    add("contract", "wrong-capability-set", lambda value: require_dict(layer(value, "contract").get("capabilitySet"), "capabilitySet").__setitem__("version", "2.0.0"))
    add("contract", "ownership-policy", lambda value: require_dict(layer(value, "contract").get("ownership"), "ownership").__setitem__("modifiedGeneratedFile", "overwrite"))

    # Capability reference, authority, probe, and exact-partition adversaries.
    add("capability", "stale-capability-digest", lambda value: layer(value, "capability").__setitem__("capabilitySetDigest", "8" * 64), refresh_digest=False)
    add("capability", "wrong-capability-identity", lambda value: layer(value, "capability").__setitem__("capabilitySetId", "other.capabilities"))
    add("capability", "wrong-contract-reference", lambda value: require_dict(layer(value, "capability").get("contract"), "contract reference").__setitem__("sha256", "9" * 64))
    add("capability", "wrong-capability-profile", lambda value: require_dict(layer(value, "capability").get("profile"), "profile").__setitem__("catalogSha256", "a" * 64))
    add("capability", "wrong-provider-version", lambda value: require_dict(layer(value, "capability").get("provider"), "provider").__setitem__("version", "2.5.0"))
    add("capability", "serializable-token", lambda value: authority(value).__setitem__("tokenSerializable", True))
    add("capability", "cacheable-token", lambda value: authority(value).__setitem__("tokenCacheable", True))
    add("capability", "stale-token-authority", lambda value: authority(value).__setitem__("staleTokenAuthority", True))
    add("capability", "caller-supplied-provider-facts", lambda value: authority(value).__setitem__("callerSuppliedFactsAllowed", True))
    add("capability", "same-scope-instance-reuse", lambda value: authority(value).__setitem__("sameNominalScopeInstanceReusable", True))
    add("capability", "wrong-lifecycle-identity", lambda value: authority(value).__setitem__("lifecycleIdentity", "caller-string"))
    add("capability", "wrong-bundle-verification", lambda value: authority(value).__setitem__("bundleVerification", "optional"))
    add("capability", "wrong-capability-target", lambda value: require_dict(capabilities(value)[0], "capability").__setitem__("target", "php"))
    add("capability", "wrong-capability-scope", lambda value: require_dict(capabilities(value)[0], "capability").__setitem__("scope", "request"))
    add("capability", "wrong-capability-optionality", lambda value: require_dict(capabilities(value)[0], "capability").__setitem__("optional", False))
    add("capability", "wrong-probe-kind", lambda value: require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").__setitem__("kind", "wordpress-plugin-and-symbols"))
    add("capability", "wrong-version-match", lambda value: require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").__setitem__("versionMatch", "compatible"))
    add("capability", "wrong-artifact-match", lambda value: require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").__setitem__("artifactMatch", "provider-id-only"))
    add("capability", "partial-authorization", lambda value: require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").__setitem__("conditionalFailure", "partially-authorized"))
    add("capability", "unknown-required-binding", lambda value: require_list(require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").get("requiredBindings"), "requiredBindings").append("missing.binding"))
    add("capability", "binding-reuse", lambda value: require_list(require_dict(require_dict(capabilities(value)[1], "capability").get("probe"), "probe").get("requiredBindings"), "requiredBindings").append(require_string(require_list(require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").get("requiredBindings"), "requiredBindings")[0], "requiredBinding")))
    add("capability", "native-symbol-mismatch", lambda value: require_list(require_dict(require_dict(capabilities(value)[0], "capability").get("probe"), "probe").get("requiredNativeSymbols"), "requiredNativeSymbols").__setitem__(0, "wrong"))
    add("capability", "unsorted-capabilities", lambda value: capabilities(value).reverse())

    # Review identity, bounded-claim, disposition, span, and conflict adversaries.
    add("review", "stale-review-digest", lambda value: layer(value, "review").__setitem__("reportDigest", "b" * 64), refresh_digest=False)
    add("review", "wrong-review-identity", lambda value: layer(value, "review").__setitem__("reportId", "other.review"))
    add("review", "wrong-review-contract", lambda value: require_dict(layer(value, "review").get("contract"), "contract reference").__setitem__("sha256", "c" * 64))
    add("review", "wrong-review-provider", lambda value: require_dict(layer(value, "review").get("provider"), "provider").__setitem__("artifactSha256", "d" * 64))
    add("review", "wrong-review-generator", lambda value: require_dict(layer(value, "review").get("generator"), "generator").__setitem__("sha256", "e" * 64))
    add("review", "review-summary", lambda value: require_dict(layer(value, "review").get("summary"), "summary").__setitem__("omitted", 3))
    add("review", "review-admits-omission", lambda value: require_list(layer(value, "review").get("includedBindings"), "includedBindings").append("not-a-binding"))
    add("review", "review-omission-removal", lambda value: omissions(value).pop())
    add("review", "review-omission-code", lambda value: require_dict(omissions(value)[0], "omission").__setitem__("code", "ambiguous-type"))
    add("review", "review-omission-reason", lambda value: require_dict(omissions(value)[0], "omission").__setitem__("reason", "other reason"))
    add("review", "review-omission-action", lambda value: require_dict(omissions(value)[0], "omission").__setitem__("requiredAction", "none"))
    add("review", "review-omission-source", lambda value: require_list(require_dict(omissions(value)[0], "omission").get("sourceInputIds"), "sourceInputIds").append("missing-source"))
    add("review", "review-omission-span", lambda value: require_dict(require_list(require_dict(omissions(value)[0], "omission").get("sourceSpans"), "sourceSpans")[0], "span").__setitem__("endByte", 1))
    add("review", "review-false-completion", lambda value: require_dict(layer(value, "review").get("claims"), "claims").__setitem__("productionSupported", True))
    add("review", "review-reflection", lambda value: require_dict(layer(value, "review").get("reflection"), "reflection").__setitem__("executed", True))
    add("review", "review-conflict-removal", lambda value: require_list(layer(value, "review").get("conflicts"), "conflicts").clear())
    add("review", "review-conflict-authority", lambda value: require_dict(require_list(layer(value, "review").get("conflicts"), "conflicts")[0], "conflict").__setitem__("strongerInputId", "plugin-source"))
    add("review", "review-conflict-span", lambda value: require_dict(require_dict(require_list(layer(value, "review").get("conflicts"), "conflicts")[0], "conflict").get("weakerSourceSpan"), "weakerSourceSpan").__setitem__("sha256", "f" * 64))

    # Content-root and exact-member adversaries. Each non-stale case receives a
    # fresh self-digest so member semantics, not an old digest, must reject it.
    add("bundle", "stale-bundle-digest", lambda value: layer(value, "bundle").__setitem__("bundleDigest", "0" * 64), refresh_digest=False)
    add("bundle", "wrong-bundle-provider", lambda value: require_dict(layer(value, "bundle").get("provider"), "provider").__setitem__("version", "2.5.0"))
    add("bundle", "bundle-traversal", lambda value: require_dict(members(value)[0], "member").__setitem__("path", "../x"))
    add("bundle", "bundle-role", lambda value: require_dict(members(value)[0], "member").__setitem__("role", "contract"))
    add("bundle", "bundle-member-hash", lambda value: require_dict(members(value)[0], "member").__setitem__("sha256", "1" * 64))
    add("bundle", "bundle-member-size", lambda value: require_dict(members(value)[0], "member").__setitem__("sizeBytes", 1))
    add("bundle", "bundle-member-removal", lambda value: members(value).pop())
    add("bundle", "bundle-member-duplication", lambda value: members(value).append(copy.deepcopy(members(value)[0])))
    add("bundle", "bundle-member-reorder", lambda value: members(value).reverse())

    valid_bindings = validate_contract(documents["contract"], model)
    for layer_name, name, change, refresh_digest in mutations:
        candidate = copy.deepcopy(documents)
        if not callable(change):
            raise AssertionError("mutation must be callable")
        change(candidate)
        document = candidate[layer_name]
        if refresh_digest:
            redigest(document, digest_fields[layer_name])
        try:
            ClosedSchemaValidator(schemas[layer_name]).validate(document)
            if layer_name == "contract":
                validate_contract(document, model)
            elif layer_name == "capability":
                validate_capability(documents["contract"], document, valid_bindings)
            elif layer_name == "review":
                validate_review(documents["contract"], document, valid_bindings, model)
            elif layer_name == "bundle":
                validate_bundle(candidate, model)
            else:
                raise AssertionError(f"unknown mutation layer: {layer_name}")
        except ValidationError:
            continue
        raise ValidationError(f"{layer_name} mutation unexpectedly passed: {name}")
    return [name for _, name, _, _ in mutations]


def haxe_source_tree_digest() -> str:
    lines: list[str] = []
    for source_root in (
        FIXTURE / "src",
        FIXTURE / "test-support",
        FIXTURE / "test",
        FIXTURE / "test-native",
        FIXTURE / "test-negative",
        FIXTURE / "test-ownership",
    ):
        for path in source_root.rglob("*.hx"):
            relative = path.relative_to(ROOT).as_posix()
            lines.append(f"{sha256(path.read_bytes())}  {relative}\n")
    return sha256("".join(sorted(lines)).encode("utf-8"))


def validate_architecture(
    documents: dict[str, dict[str, object]],
    model: AbiModel,
    mutation_count: int,
) -> None:
    architecture = strict_json(ARCHITECTURE_PATH)
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
    if contracts != {
        "adoption": {
            "identity": "wordpress-hx.adoption-contract.v1",
            "schema": "schemas/adoption-contract.schema.json",
            "purpose": "exact-provider-identity-inputs-precise-bindings-and-ownership",
        },
        "capability": {
            "identity": "wordpress-hx.adoption-capability.v1",
            "schema": "schemas/adoption-capability.schema.json",
            "purpose": "exact-runtime-probes-and-nonserializable-scoped-authority",
        },
        "review": {
            "identity": "wordpress-hx.adoption-review.v1",
            "schema": "schemas/adoption-review.schema.json",
            "purpose": "included-omitted-conflicting-and-evidence-stage-report",
        },
        "bundle": {
            "identity": "wordpress-hx.adoption-bundle.v1",
            "schema": "schemas/adoption-bundle.schema.json",
            "purpose": "one-content-root-excluding-final-ownership-manifest",
        },
    }:
        raise ValidationError("architecture contract inventory changed")
    prototype = require_dict(architecture.get("prototypeEvidence"), "prototypeEvidence")
    expected = {
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
        "bindingCount": len(model.admitted()),
        "capabilityCount": len(require_list(documents["capability"].get("capabilities"), "capabilities")),
        "omissionCount": len(model.omitted()),
        "conflictCount": len([candidate for candidate in model.omitted() if candidate.omission_code == "conflicting-authority"]),
        "compileNegativeCount": len([path for path in (FIXTURE / "test-negative").iterdir() if path.is_dir()]),
        "independentMutationCount": mutation_count,
    }
    for field, value in expected.items():
        if prototype.get(field) != value:
            raise ValidationError(f"architecture {field} is stale")

    cli_lock = strict_json(CLI_LOCK_PATH)
    compiler = require_dict(cli_lock.get("compiler"), "CLI dependency lock.compiler")
    runtime = require_dict(cli_lock.get("runtime"), "CLI dependency lock.runtime")
    haxe = require_dict(cli_lock.get("haxe"), "CLI dependency lock.haxe")
    genes_version = require_string(compiler.get("version"), "compiler.version")
    genes_commit = require_string(compiler.get("commit"), "compiler.commit")
    node_version = require_string(runtime.get("version"), "runtime.version")
    haxe_version = require_string(haxe.get("version"), "haxe.version")
    npm_lock = strict_json(NPM_LOCK_PATH)
    npm_packages = require_dict(npm_lock.get("packages"), "npm lock packages")
    typescript = require_dict(
        npm_packages.get("node_modules/typescript"), "npm lock TypeScript"
    )
    typescript_version = require_string(typescript.get("version"), "TypeScript version")
    toolchain = strict_json(TOOLCHAIN_LOCK_PATH)
    images = require_dict(toolchain.get("runtimeImages"), "toolchain runtime images")
    php = require_dict(images.get("php"), "toolchain PHP")
    primary_php = require_dict(php.get("primaryCli"), "toolchain primary PHP")
    php_version = require_string(primary_php.get("version"), "PHP version")
    adoption_toolchain = strict_json(ADOPTION_TOOLCHAIN_LOCK_PATH)
    if set(adoption_toolchain) != {"schemaVersion", "lockId", "python"}:
        raise ValidationError("ADR-015 toolchain lock has an open top-level shape")
    if (
        adoption_toolchain.get("schemaVersion") != 1
        or adoption_toolchain.get("lockId") != "ADR-015-ADOPTION-CONTRACT-TOOLCHAIN"
    ):
        raise ValidationError("ADR-015 toolchain lock identity changed")
    python = require_dict(adoption_toolchain.get("python"), "ADR-015 Python lock")
    if set(python) != {"implementation", "version", "hostedInstaller"}:
        raise ValidationError("ADR-015 Python lock has an open runtime shape")
    python_implementation = require_string(
        python.get("implementation"), "ADR-015 Python implementation"
    )
    python_version = require_string(python.get("version"), "ADR-015 Python version")
    installer = require_dict(
        python.get("hostedInstaller"), "ADR-015 Python hosted installer"
    )
    if installer != {
        "repository": "https://github.com/actions/setup-python",
        "version": "7.0.0",
        "commit": "5fda3b95a4ea91299a34e894583c3862153e4b97",
    }:
        raise ValidationError("ADR-015 Python hosted installer identity changed")
    if (
        platform.python_implementation() != python_implementation
        or platform.python_version() != python_version
    ):
        raise ValidationError("ADR-015 validator is running under an unlocked Python runtime")
    if prototype.get("targets") != [
        f"{python_implementation.lower()}-{python_version}-evidence-runtime",
        f"haxe-{haxe_version}-interp",
        f"genes-ts-{genes_version}@{genes_commit}-typescript-{typescript_version}-node-{node_version}",
        f"stock-haxe-php-{php_version}",
    ]:
        raise ValidationError("architecture targets differ from authoritative locks")
    if prototype.get("syntheticProviderRuntimeUsed") is not True:
        raise ValidationError("architecture omits the synthetic native-provider runtime proof")
    if prototype.get("productionOwnershipTransactionUsed") is not True:
        raise ValidationError("architecture omits the production ownership transaction proof")
    if prototype.get("providerRuntimeExecutionDuringGeneration") is not False:
        raise ValidationError("architecture claims provider execution during static generation")
    if prototype.get("realProviderUsed") is not False:
        raise ValidationError("architecture overclaims a real provider")

    references = require_list(architecture.get("referenceReview"), "referenceReview")
    if len(references) != 3:
        raise ValidationError("architecture reference review inventory changed")
    for raw in references:
        reference = require_dict(raw, "reference")
        if re.fullmatch(r"[0-9a-f]{40}", require_string(reference.get("commit"), "reference.commit")) is None:
            raise ValidationError("reference commit is not immutable")
        if re.fullmatch(r"[0-9a-f]{40}", require_string(reference.get("gitBlob"), "reference.gitBlob")) is None:
            raise ValidationError("reference blob is not immutable")
        if re.fullmatch(r"[0-9a-f]{64}", require_string(reference.get("sha256"), "reference.sha256")) is None:
            raise ValidationError("reference hash is not immutable")
        if reference.get("copiedBytes") is not False:
            raise ValidationError("reference review copied source bytes")

    claims = require_dict(architecture.get("claims"), "architecture.claims")
    if claims.get("architectureDecision") != "proposed-pending-fresh-review":
        raise ValidationError("architecture decision claim changed")
    if claims.get("closedSchemas") != "validated" or claims.get("fixtureContract") != "validated":
        raise ValidationError("architecture drops its schema or fixture validation claim")
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

    validate_receipt(
        architecture,
        genes_version,
        genes_commit,
        node_version,
        haxe_version,
        typescript_version,
        php_version,
        python_implementation,
        python_version,
    )


def validate_receipt(
    architecture: dict[str, object],
    genes_version: str,
    genes_commit: str,
    node_version: str,
    haxe_version: str,
    typescript_version: str,
    php_version: str,
    python_implementation: str,
    python_version: str,
) -> None:
    receipt = strict_json(RECEIPT_PATH)
    if receipt.get("schemaVersion") != 1 or receipt.get("receiptId") != "ADR-015-INTEROP-ADOPTION-CONTRACT":
        raise ValidationError("evidence receipt identity changed")
    if receipt.get("status") != "implemented-hosted-and-review-pending":
        raise ValidationError("evidence receipt status changed or overclaims acceptance")
    if receipt.get("status") == "accepted" or require_dict(receipt.get("review"), "receipt.review").get("acceptanceAuthorized") is not False:
        raise ValidationError("evidence receipt overclaims acceptance")
    for raw in require_dict(receipt.get("subject"), "receipt.subject").values():
        subject = require_dict(raw, "receipt subject")
        relative = clean_relative_path(subject.get("path"), "receipt subject path")
        path = ROOT / relative
        if not path.is_file() or subject.get("sha256") != sha256(path.read_bytes()):
            raise ValidationError(f"receipt subject is stale: {relative}")

    verification = require_dict(receipt.get("verification"), "receipt.verification")
    expected_versions = {
        "genesVersion": genes_version,
        "genesCommit": genes_commit,
        "nodeVersion": node_version,
        "haxeVersion": haxe_version,
        "typescriptVersion": typescript_version,
        "phpVersion": php_version,
        "pythonImplementation": python_implementation,
        "pythonVersion": python_version,
        "pythonAuthority": "manifests/adoption-contract-toolchain.lock.json",
        "genesAuthority": "packages/cli/dependency-lock.json",
    }
    for field, expected in expected_versions.items():
        if verification.get(field) != expected:
            raise ValidationError(f"receipt {field} differs from its lock authority")
    prototype = require_dict(architecture.get("prototypeEvidence"), "prototypeEvidence")
    for field in (
        "sourceTreeSha256",
        "bindingCount",
        "capabilityCount",
        "omissionCount",
        "conflictCount",
        "compileNegativeCount",
        "independentMutationCount",
        "providerRuntimeExecutionDuringGeneration",
        "syntheticProviderRuntimeUsed",
        "productionOwnershipTransactionUsed",
        "realProviderUsed",
    ):
        if verification.get(field) != prototype.get(field):
            raise ValidationError(f"receipt verification {field} differs from architecture")

    claims = require_dict(receipt.get("claims"), "receipt.claims")
    for field in (
        "productionGenerator",
        "isolatedReflectionRuntime",
        "realProviderRuntime",
        "wordpressRuntime",
        "providerTrustAdmission",
        "php74Runtime",
        "publicPackageConsumer",
        "productionSupport",
    ):
        if claims.get(field) != "not-tested":
            raise ValidationError(f"receipt overclaims {field}")
    if claims.get("publicationAuthorized") is not False:
        raise ValidationError("receipt authorizes publication before fresh review")
    architecture_claims = require_dict(architecture.get("claims"), "architecture.claims")
    for architecture_field, receipt_field in (
        ("typedCapabilityPrototype", "typedCapabilityPrototype"),
        ("fixtureGenerator", "fixtureGenerator"),
        ("nativeSyntheticProviderRuntime", "nativeProviderAbi"),
        ("ownershipTransaction", "ownershipTransaction"),
    ):
        if architecture_claims.get(architecture_field) != claims.get(receipt_field):
            raise ValidationError(
                f"architecture claim {architecture_field} differs from its receipt authority"
            )

    expected_observer_ids = [
        "schema",
        "native",
        "haxe",
        "mutation",
        "ownership",
    ]
    identities = observer_identities(ROOT)
    evidence_subject = evidence_subject_sha256(ROOT)
    if prototype.get("evidenceSubjectSha256") != evidence_subject:
        raise ValidationError("prototype evidence uses a stale evidence subject")
    if verification.get("evidenceSubjectSha256") != evidence_subject:
        raise ValidationError("receipt verification uses a stale evidence subject")
    observation_outcomes: list[object] = []
    for key, mode in (
        ("localObservation", "local"),
        ("containerObservation", "container"),
    ):
        observation = require_dict(receipt.get(key), f"receipt.{key}")
        if observation.get("contentRoot") != prototype.get("bundleDigest"):
            raise ValidationError(f"{mode} observation uses a different content root")
        if observation.get("evidenceSubjectSha256") != evidence_subject:
            raise ValidationError(f"{mode} observation uses a stale evidence subject")
        if observation.get("executionMode") != mode:
            raise ValidationError(f"{mode} observation has the wrong execution mode")
        if observation.get("pythonRuntime") != {
            "implementation": python_implementation,
            "version": python_version,
        }:
            raise ValidationError(f"{mode} observation has the wrong Python runtime")
        outcome = observation.get("outcome")
        observation_outcomes.append(outcome)
        observers = require_list(observation.get("observers"), f"{mode} observers")
        if [require_dict(value, f"{mode} observer").get("id") for value in observers] != expected_observer_ids:
            raise ValidationError(f"{mode} observer inventory changed")
        for raw in observers:
            observer = require_dict(raw, f"{mode} observer")
            observer_id = require_string(observer.get("id"), f"{mode} observer id")
            if observer.get("identitySha256") != identities[observer_id]:
                raise ValidationError(f"{mode} observer {observer_id} identity is stale")
        if outcome == "passed":
            if observation.get("observedAt") is None or any(
                require_dict(value, f"{mode} observer").get("outcome") != "passed"
                for value in observers
            ):
                raise ValidationError(f"{mode} pass lacks every observer outcome")
        elif outcome == "pending":
            if observation.get("observedAt") is not None or any(
                require_dict(value, f"{mode} observer").get("outcome") != "pending"
                for value in observers
            ):
                raise ValidationError(f"pending {mode} evidence contains a pass")
        else:
            raise ValidationError(f"{mode} evidence outcome is not closed")
    expected_outcome = (
        "passed-local-and-container-current-evidence-subject"
        if observation_outcomes == ["passed", "passed"]
        else "pending-current-observers"
    )
    if verification.get("outcome") != expected_outcome:
        raise ValidationError("receipt verification differs from exact observer outcomes")

    hosted = require_dict(receipt.get("hostedWorkflow"), "receipt.hostedWorkflow")
    architecture_hosted = require_dict(architecture.get("hostedGate"), "architecture.hostedGate")
    for field in (
        "job",
        "runId",
        "jobId",
        "commit",
        "status",
        "contentRoot",
        "evidenceSubjectSha256",
        "pythonRuntime",
        "gateIdentitySha256",
    ):
        if architecture_hosted.get(field) != hosted.get(field):
            raise ValidationError(f"architecture hosted {field} differs from its receipt authority")
    if hosted.get("contentRoot") != prototype.get("bundleDigest"):
        raise ValidationError("hosted evidence uses a different content root")
    if hosted.get("evidenceSubjectSha256") != evidence_subject:
        raise ValidationError("hosted evidence uses a stale evidence subject")
    if hosted.get("pythonRuntime") != {
        "implementation": python_implementation,
        "version": python_version,
    }:
        raise ValidationError("hosted evidence uses the wrong Python runtime")
    if hosted.get("gateIdentitySha256") != hosted_gate_identity(ROOT):
        raise ValidationError("hosted evidence uses a stale gate identity")
    if hosted.get("required") is not True:
        raise ValidationError("hosted adoption gate is no longer required")
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
    schemas = {name: strict_json(path) for name, path in SCHEMA_PATHS.items()}
    for schema in schemas.values():
        require_closed_objects(schema)
    documents = {name: strict_json(path) for name, path in DOCUMENT_PATHS.items()}
    model = merge_model(INPUT_ROOT, logical_path)
    validate_documents(documents, model, schemas)
    mutations = mutation_corpus(documents, model, schemas)
    validate_architecture(documents, model, len(mutations))
    print(
        "ADR-015 determinism and self-consistency checks passed source-derived ABI, "
        f"immutable bundle, and {len(mutations)} re-digested mutations"
    )


if __name__ == "__main__":
    main()
