#!/usr/bin/env python3
"""Independently validate the ADR-009 schema IR and mutation corpus."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas" / "contract-schema.schema.json"
ARCHITECTURE_PATH = ROOT / "manifests" / "schema-codec-architecture.json"
SEMANTIC_PLAN_ARCHITECTURE_PATH = ROOT / "manifests" / "semantic-plan-architecture.json"
TRANSCRIPT_PATH = (
    ROOT / "fixtures" / "schema-codec" / "expected" / "cross-target.txt"
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


def haxe_source_tree_digest() -> str:
    source_lines: list[str] = []
    for source_root in (
        ROOT / "packages" / "contracts" / "src",
        ROOT / "packages" / "contracts" / "test",
        ROOT / "packages" / "contracts" / "test-negative",
    ):
        for source in source_root.rglob("*.hx"):
            relative = source.relative_to(ROOT).as_posix()
            source_lines.append(f"{sha256(source.read_bytes())}  {relative}\n")
    return sha256("".join(sorted(source_lines)).encode("utf-8"))


def validate_architecture_manifest() -> None:
    architecture = require_dict(
        strict_json(
            ARCHITECTURE_PATH.read_text(encoding="utf-8"), "architecture manifest"
        ),
        "architecture manifest",
    )
    if architecture.get("schemaVersion") != 1 or architecture.get(
        "decisionId"
    ) != "ADR-009":
        raise ValidationError("architecture manifest identity changed")
    authority = require_dict(
        architecture.get("canonicalAuthority"), "architecture canonicalAuthority"
    )
    if authority.get("identity") != "wordpress-hx.contract-schema.v1":
        raise ValidationError("canonical contract identity changed")
    if authority.get("foreignParserIncluded") is not False:
        raise ValidationError("prototype must not claim a foreign parser")
    if authority.get("runtimeReflectionRequired") is not False:
        raise ValidationError("contract IR unexpectedly requires runtime reflection")

    prototype = require_dict(
        architecture.get("prototypeEvidence"), "architecture prototypeEvidence"
    )
    expected_hashes = {
        "sourceTreeSha256": haxe_source_tree_digest(),
        "schemaSha256": sha256(SCHEMA_PATH.read_bytes()),
        "transcriptSha256": sha256(TRANSCRIPT_PATH.read_bytes()),
    }
    for field, expected in expected_hashes.items():
        if prototype.get(field) != expected:
            raise ValidationError(f"architecture {field} is stale")
    if prototype.get("haxeInvariantCount") != 27:
        raise ValidationError("architecture Haxe invariant count changed")
    if prototype.get("crossTargetVectorCount") != 17:
        raise ValidationError("architecture vector count changed")
    if prototype.get("independentMutationCount") != 18:
        raise ValidationError("architecture mutation count changed")
    if prototype.get("negativeCompileFixtureCount") != 4:
        raise ValidationError("architecture compile-negative count changed")
    targets = require_list(prototype.get("targets"), "architecture targets")
    if not any(isinstance(target, str) and target.startswith("genes-ts-1.36.3-") for target in targets):
        raise ValidationError("architecture target list omitted pinned Genes")

    references = require_list(
        architecture.get("referenceReview"), "architecture referenceReview"
    )
    if len(references) != 7:
        raise ValidationError("architecture reference inventory changed")
    for index, reference_value in enumerate(references):
        reference = require_dict(reference_value, f"architecture reference[{index}]")
        if reference.get("copiedBytes") is not False:
            raise ValidationError(f"architecture reference[{index}] copied bytes")

    claims = require_dict(architecture.get("claims"), "architecture claims")
    if claims.get("architectureDecision") not in {
        "proposed-pending-fresh-review",
        "review-corrections-applied-pending-rereview",
        "accepted-after-review",
    }:
        raise ValidationError("architecture decision claim is invalid")

    serialization = require_dict(
        architecture.get("canonicalSerialization"),
        "architecture canonicalSerialization",
    )
    if serialization.get("payloadStringNormalization") != "preserve":
        raise ValidationError("contract payload normalization changed")
    if serialization.get("semanticPlanCanonicalization") != (
        "wordpress-hx.canonical-json.v1-with-NFC"
    ):
        raise ValidationError("ADR-006 canonicalization relation changed")
    if serialization.get("rawSchemaBytesInlineInSemanticPlan") is not False:
        raise ValidationError("raw contract schema bytes entered the semantic plan")
    rule_policy = require_dict(architecture.get("rules"), "architecture rules")
    validation_policy = require_dict(
        rule_policy.get("validation"), "architecture validation rules"
    )
    if validation_policy.get("pathAffectsRuleSemantics") is not False:
        raise ValidationError("diagnostic paths entered named-rule semantics")
    if validation_policy.get("ruleSetBinding") != (
        "retained-by-SchemaDocument-and-used-by-validator"
    ):
        raise ValidationError("schema document no longer owns its admitted rule set")
    semantic_plan = require_dict(
        strict_json(
            SEMANTIC_PLAN_ARCHITECTURE_PATH.read_text(encoding="utf-8"),
            "semantic-plan architecture",
        ),
        "semantic-plan architecture",
    )
    plan_canonicalization = require_dict(
        semantic_plan.get("canonicalization"),
        "semantic-plan canonicalization",
    )
    if plan_canonicalization.get("identity") != "wordpress-hx.canonical-json.v1":
        raise ValidationError("ADR-006 canonicalization identity changed")
    if plan_canonicalization.get("unicodeNormalization") != "NFC":
        raise ValidationError("ADR-006 Unicode normalization changed")
    hosted = require_dict(architecture.get("hostedGate"), "architecture hostedGate")
    if hosted != {
        "workflow": ".github/workflows/repository.yml",
        "job": "contract-schema",
        "command": "bash scripts/contracts/test-schema-authority.sh",
        "status": "configured-pending-first-hosted-run",
    }:
        raise ValidationError("hosted contract gate declaration changed")
    for claim in (
        "productionMacroDerivation",
        "productionPhpEmitter",
        "productionGenesEmitter",
        "wordpressRestRuntime",
        "gutenbergBlockRuntime",
        "php74Runtime",
        "packedConsumer",
    ):
        if claims.get(claim) != "not-tested":
            raise ValidationError(f"architecture overclaims {claim}")


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
        if not isinstance(current, dict):
            raise ValidationError(f"schema reference is not an object: {reference}")
        return current

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
                if not isinstance(alternative, dict):
                    raise ValidationError(f"{location}: oneOf member is not an object")
                try:
                    self.validate(value, alternative, location)
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
                items = [canonical(item) for item in value]
                if len(items) != len(set(items)):
                    raise ValidationError(f"{location}: array items are not unique")
            item_schema = current.get("items")
            if isinstance(item_schema, dict):
                for index, item in enumerate(value):
                    self.validate(item, item_schema, f"{location}[{index}]")

        if isinstance(value, dict):
            required = current.get("required", [])
            if not isinstance(required, list):
                raise ValidationError(f"{location}: required is not an array")
            for field in required:
                if field not in value:
                    raise ValidationError(f"{location}: missing required field {field}")
            properties = current.get("properties", {})
            if not isinstance(properties, dict):
                raise ValidationError(f"{location}: properties is not an object")
            unknown = sorted(set(value) - set(properties))
            additional = current.get("additionalProperties")
            if additional is False and unknown:
                raise ValidationError(
                    f"{location}: unknown field(s): {', '.join(unknown)}"
                )
            if isinstance(additional, dict):
                for field in unknown:
                    self.validate(value[field], additional, f"{location}.{field}")
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
            if location != "$schema.$defs.wireValue.oneOf[5]":
                raise ValidationError(f"{location}: object schema is not closed")
        reference = value.get("$ref")
        if isinstance(reference, str) and not reference.startswith("#/"):
            raise ValidationError(f"{location}: external reference is forbidden")
        for key, child in value.items():
            require_closed_objects(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            require_closed_objects(child, f"{location}[{index}]")


def require_dict(value: object, location: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{location}: expected object")
    return value


def require_list(value: object, location: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{location}: expected array")
    return value


def semantic_validate(document: dict[str, object]) -> None:
    version = document.get("version")
    if not isinstance(version, int) or isinstance(version, bool):
        raise ValidationError("$.version: expected integer")
    migrations = require_list(document.get("migrations"), "$.migrations")
    if len(migrations) != version - 1:
        raise ValidationError("$.migrations: incomplete adjacent migration chain")
    for index, migration_value in enumerate(migrations):
        migration = require_dict(migration_value, f"$.migrations[{index}]")
        if migration.get("fromVersion") != index + 1:
            raise ValidationError("$.migrations: chain is not ordered")
        if migration.get("toVersion") != index + 2:
            raise ValidationError("$.migrations: chain is not adjacent")
    semantic_validate_node(require_dict(document.get("root"), "$.root"), "$.root")


def semantic_validate_node(node: dict[str, object], location: str) -> None:
    kind = node.get("kind")
    if kind in {"integer", "string"}:
        semantic_validate_range(node, "minimum", "maximum", location)
        semantic_validate_range(node, "minLength", "maxLength", location)
    if kind == "array":
        semantic_validate_range(node, "minItems", "maxItems", location)
        semantic_validate_node(
            require_dict(node.get("items"), f"{location}.items"),
            f"{location}.items",
        )
    elif kind == "nullable":
        child = require_dict(node.get("value"), f"{location}.value")
        if child.get("kind") == "nullable":
            raise ValidationError(f"{location}: nested nullable node")
        semantic_validate_node(child, f"{location}.value")
    elif kind == "object":
        fields = require_list(node.get("fields"), f"{location}.fields")
        names: set[str] = set()
        for index, field_value in enumerate(fields):
            field_location = f"{location}.fields[{index}]"
            field = require_dict(field_value, field_location)
            name = field.get("jsonName")
            if not isinstance(name, str):
                raise ValidationError(f"{field_location}.jsonName: expected string")
            if name in names:
                raise ValidationError(f"{location}.fields: duplicate field {name}")
            names.add(name)
            default_value = require_dict(
                field.get("default"), f"{field_location}.default"
            )
            if default_value.get("mode") == "when-missing":
                if field.get("requirement") != "optional":
                    raise ValidationError(
                        f"{field_location}.default: required fields cannot default"
                    )
                semantic_validate_wire(
                    default_value.get("value"),
                    require_dict(field.get("value"), f"{field_location}.value"),
                    f"{field_location}.default.value",
                )
            semantic_validate_node(
                require_dict(field.get("value"), f"{field_location}.value"),
                f"{field_location}.value",
            )
    elif kind == "tagged-union":
        if node.get("discriminator") == node.get("payloadField"):
            raise ValidationError(
                f"{location}: discriminator and payload field must differ"
            )
        cases = require_list(node.get("cases"), f"{location}.cases")
        tags: set[str] = set()
        for index, case_value in enumerate(cases):
            case_location = f"{location}.cases[{index}]"
            case = require_dict(case_value, case_location)
            tag = case.get("tag")
            if not isinstance(tag, str):
                raise ValidationError(f"{case_location}.tag: expected string")
            if tag in tags:
                raise ValidationError(f"{location}.cases: duplicate tag {tag}")
            tags.add(tag)
            semantic_validate_node(
                require_dict(case.get("value"), f"{case_location}.value"),
                f"{case_location}.value",
            )
    elif kind == "refined":
        child = require_dict(node.get("value"), f"{location}.value")
        if child.get("kind") == "refined":
            raise ValidationError(f"{location}: nested refined node")
        validators = semantic_validate_rules(
            require_list(node.get("validators"), f"{location}.validators"),
            f"{location}.validators",
            exact_required=True,
        )
        sanitizers = semantic_validate_rules(
            require_list(node.get("sanitizers"), f"{location}.sanitizers"),
            f"{location}.sanitizers",
            exact_required=False,
        )
        if validators & sanitizers:
            raise ValidationError(f"{location}: rule revision has conflicting roles")
        semantic_validate_node(child, f"{location}.value")


def semantic_validate_range(
    value: dict[str, object], minimum_name: str, maximum_name: str, location: str
) -> None:
    minimum = value.get(minimum_name)
    maximum = value.get(maximum_name)
    if isinstance(minimum, int) and isinstance(maximum, int) and minimum > maximum:
        raise ValidationError(f"{location}: {minimum_name} exceeds {maximum_name}")


def semantic_validate_wire(
    value: object, node: dict[str, object], location: str
) -> None:
    kind = node.get("kind")
    if kind == "boolean":
        if not isinstance(value, bool):
            raise ValidationError(f"{location}: expected boolean")
    elif kind == "integer":
        if not isinstance(value, int) or isinstance(value, bool):
            raise ValidationError(f"{location}: expected integer")
        if value < -2147483648 or value > 2147483647:
            raise ValidationError(f"{location}: integer is outside signed int32")
        minimum = node.get("minimum")
        maximum = node.get("maximum")
        if isinstance(minimum, int) and value < minimum:
            raise ValidationError(f"{location}: integer is below minimum")
        if isinstance(maximum, int) and value > maximum:
            raise ValidationError(f"{location}: integer is above maximum")
    elif kind == "string":
        if not isinstance(value, str):
            raise ValidationError(f"{location}: expected string")
        minimum = node.get("minLength")
        maximum = node.get("maxLength")
        if isinstance(minimum, int) and len(value) < minimum:
            raise ValidationError(f"{location}: string is too short")
        if isinstance(maximum, int) and len(value) > maximum:
            raise ValidationError(f"{location}: string is too long")
    elif kind == "enum":
        values = require_list(node.get("values"), f"{location}.schema.values")
        if not isinstance(value, str) or value not in values:
            raise ValidationError(f"{location}: value is outside enum")
    elif kind == "array":
        values = require_list(value, location)
        minimum = node.get("minItems")
        maximum = node.get("maxItems")
        if isinstance(minimum, int) and len(values) < minimum:
            raise ValidationError(f"{location}: array is too short")
        if isinstance(maximum, int) and len(values) > maximum:
            raise ValidationError(f"{location}: array is too long")
        item_node = require_dict(node.get("items"), f"{location}.schema.items")
        for index, item in enumerate(values):
            semantic_validate_wire(item, item_node, f"{location}[{index}]")
    elif kind == "nullable":
        if value is not None:
            semantic_validate_wire(
                value,
                require_dict(node.get("value"), f"{location}.schema.value"),
                location,
            )
    elif kind == "object":
        object_value = require_dict(value, location)
        fields = require_list(node.get("fields"), f"{location}.schema.fields")
        known: set[str] = set()
        for index, field_value in enumerate(fields):
            field = require_dict(field_value, f"{location}.schema.fields[{index}]")
            name = field.get("jsonName")
            if not isinstance(name, str):
                raise ValidationError(f"{location}: schema field name is invalid")
            known.add(name)
            field_node = require_dict(
                field.get("value"), f"{location}.schema.fields[{index}].value"
            )
            if name in object_value:
                semantic_validate_wire(
                    object_value[name], field_node, f"{location}.{name}"
                )
                continue
            default_value = require_dict(
                field.get("default"), f"{location}.schema.fields[{index}].default"
            )
            if default_value.get("mode") == "when-missing":
                semantic_validate_wire(
                    default_value.get("value"), field_node, f"{location}.{name}"
                )
            elif field.get("requirement") == "required":
                raise ValidationError(f"{location}.{name}: required field is missing")
        unknown = sorted(set(object_value) - known)
        if unknown:
            raise ValidationError(f"{location}: unknown field(s): {', '.join(unknown)}")
    elif kind == "tagged-union":
        object_value = require_dict(value, location)
        discriminator = node.get("discriminator")
        payload_field = node.get("payloadField")
        if not isinstance(discriminator, str) or not isinstance(payload_field, str):
            raise ValidationError(f"{location}: invalid tagged-union schema")
        if set(object_value) != {discriminator, payload_field}:
            raise ValidationError(f"{location}: invalid tagged-union fields")
        tag = object_value.get(discriminator)
        cases = require_list(node.get("cases"), f"{location}.schema.cases")
        for index, case_value in enumerate(cases):
            schema_case = require_dict(case_value, f"{location}.schema.cases[{index}]")
            if schema_case.get("tag") == tag:
                semantic_validate_wire(
                    object_value[payload_field],
                    require_dict(
                        schema_case.get("value"),
                        f"{location}.schema.cases[{index}].value",
                    ),
                    f"{location}.{payload_field}",
                )
                return
        raise ValidationError(f"{location}.{discriminator}: unknown union tag")
    elif kind == "refined":
        semantic_validate_wire(
            value,
            require_dict(node.get("value"), f"{location}.schema.value"),
            location,
        )
    else:
        raise ValidationError(f"{location}: unknown schema kind {kind}")


def semantic_validate_rules(
    rules: list[object], location: str, *, exact_required: bool
) -> set[tuple[str, int]]:
    identities: set[tuple[str, int]] = set()
    for index, rule_value in enumerate(rules):
        rule = require_dict(rule_value, f"{location}[{index}]")
        rule_id = rule.get("ruleId")
        revision = rule.get("revision")
        if not isinstance(rule_id, str) or not isinstance(revision, int):
            raise ValidationError(f"{location}[{index}]: invalid rule identity")
        if exact_required and rule.get("parity") != "exact":
            raise ValidationError(f"{location}[{index}]: validator parity is not exact")
        identity = (rule_id, revision)
        if identity in identities:
            raise ValidationError(f"{location}: duplicate rule revision")
        identities.add(identity)
    return identities


def replace_root(document: dict[str, object], root: dict[str, object]) -> dict[str, object]:
    result = copy.deepcopy(document)
    result["root"] = root
    return result


def mutation_corpus(document: dict[str, object]) -> list[tuple[str, dict[str, object]]]:
    unknown_top = copy.deepcopy(document)
    unknown_top["surprise"] = True

    zero_version = copy.deepcopy(document)
    zero_version["version"] = 0
    zero_version["migrations"] = []

    missing_migration = copy.deepcopy(document)
    missing_migration["migrations"] = []

    non_adjacent = copy.deepcopy(document)
    require_dict(require_list(non_adjacent["migrations"], "migrations")[0], "migration")[
        "toVersion"
    ] = 3

    duplicate_fields = replace_root(
        document,
        {
            "kind": "object",
            "unknownFields": "reject",
            "fields": [
                {
                    "default": {"mode": "none"},
                    "jsonName": "same",
                    "requirement": "required",
                    "value": {"kind": "boolean"},
                },
                {
                    "default": {"mode": "none"},
                    "jsonName": "same",
                    "requirement": "optional",
                    "value": {"kind": "boolean"},
                },
            ],
        },
    )

    collision_rule = {
        "ruleId": "site.same-rule",
        "revision": 1,
        "parity": "exact",
    }
    conflicting_roles = replace_root(
        document,
        {
            "kind": "refined",
            "value": {"kind": "boolean"},
            "validators": [collision_rule],
            "sanitizers": [collision_rule],
        },
    )

    non_exact_validator = replace_root(
        document,
        {
            "kind": "refined",
            "value": {"kind": "boolean"},
            "validators": [
                {
                    "ruleId": "wordpress.native-only-validation",
                    "revision": 1,
                    "parity": "documented-native-relation",
                }
            ],
            "sanitizers": [],
        },
    )

    required_default = copy.deepcopy(document)
    required_root = require_dict(required_default["root"], "root")
    required_field = require_dict(
        require_list(required_root["fields"], "fields")[0], "field"
    )
    required_field["default"] = {"mode": "when-missing", "value": 1}

    invalid_default = copy.deepcopy(document)
    invalid_root = require_dict(invalid_default["root"], "root")
    optional_field = require_dict(
        require_list(invalid_root["fields"], "fields")[2], "field"
    )
    optional_field["default"] = {"mode": "when-missing", "value": 7}

    overflowing_version = copy.deepcopy(document)
    overflowing_version["version"] = 2147483648

    overflowing_bound = replace_root(
        document, {"kind": "integer", "minimum": -2147483649}
    )

    overflowing_default = copy.deepcopy(document)
    overflowing_root = require_dict(overflowing_default["root"], "root")
    overflowing_field = require_dict(
        require_list(overflowing_root["fields"], "fields")[2], "field"
    )
    overflowing_field["value"] = {"kind": "integer"}
    overflowing_field["default"] = {
        "mode": "when-missing",
        "value": 2147483648,
    }

    return [
        ("unknown-top-field", unknown_top),
        ("zero-version", zero_version),
        ("missing-migration", missing_migration),
        ("non-adjacent-migration", non_adjacent),
        ("unknown-node", replace_root(document, {"kind": "unknown"})),
        (
            "reversed-integer-range",
            replace_root(document, {"kind": "integer", "minimum": 2, "maximum": 1}),
        ),
        ("empty-enum", replace_root(document, {"kind": "enum", "values": []})),
        ("duplicate-fields", duplicate_fields),
        (
            "nested-nullable",
            replace_root(
                document,
                {
                    "kind": "nullable",
                    "value": {"kind": "nullable", "value": {"kind": "boolean"}},
                },
            ),
        ),
        (
            "negative-array-count",
            replace_root(
                document,
                {"kind": "array", "items": {"kind": "boolean"}, "minItems": -1},
            ),
        ),
        ("conflicting-rule-roles", conflicting_roles),
        ("non-exact-validator", non_exact_validator),
        ("required-field-default", required_default),
        ("invalid-default-shape", invalid_default),
        ("overflowing-version", overflowing_version),
        ("overflowing-integer-bound", overflowing_bound),
        ("overflowing-wire-default", overflowing_default),
        (
            "duplicate-union-tags",
            replace_root(
                document,
                {
                    "kind": "tagged-union",
                    "discriminator": "kind",
                    "payloadField": "value",
                    "cases": [
                        {"tag": "same", "value": {"kind": "boolean"}},
                        {"tag": "same", "value": {"kind": "boolean"}},
                    ],
                },
            ),
        ),
    ]


def issue(code: str, path: str, expected: str, actual: str) -> dict[str, str]:
    return {
        "actual": actual,
        "code": code,
        "expected": expected,
        "path": path,
    }


def main() -> None:
    validate_architecture_manifest()
    schema_value = strict_json(SCHEMA_PATH.read_text(encoding="utf-8"), "schema")
    schema = require_dict(schema_value, "$schema")
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        raise ValidationError("contract schema must use JSON Schema draft 2020-12")
    require_closed_objects(schema)
    validator = ClosedSchemaValidator(schema)

    transcript_bytes = TRANSCRIPT_PATH.read_bytes()
    if not transcript_bytes.endswith(b"\n") or transcript_bytes.endswith(b"\n\n"):
        raise ValidationError("cross-target transcript must end in exactly one LF")
    lines = transcript_bytes.decode("utf-8").splitlines()
    entries: dict[str, str] = {}
    for line in lines:
        label, separator, payload = line.partition("=")
        if separator != "=" or not label or label in entries:
            raise ValidationError(f"invalid or duplicate transcript label: {label}")
        entries[label] = payload
    expected_labels = {
        "schema",
        "schema-invariants",
        "encode-invariants",
        "missing-optional",
        "explicit-null",
        "present-summary",
        "unicode-title",
        "decomposed-title",
        "missing-required",
        "wrong-type",
        "zero-id",
        "unknown-enum",
        "empty-tag",
        "too-many-tags",
        "unknown-field",
        "unicode-key-order",
        "duplicate-field",
        "invalid-title",
        "null-required",
    }
    if set(entries) != expected_labels:
        raise ValidationError("cross-target transcript labels changed")
    if entries["schema-invariants"] != "27/27":
        raise ValidationError("Haxe schema invariant corpus did not pass")
    if entries["encode-invariants"] != "1/1":
        raise ValidationError("development encode invariant did not pass")

    document_value = strict_json(entries["schema"], "schema transcript")
    document = require_dict(document_value, "schema transcript")
    if canonical(document) != entries["schema"]:
        raise ValidationError("schema transcript is not canonical JSON")
    validator.validate(document)
    semantic_validate(document)

    vector_labels = expected_labels - {
        "schema",
        "schema-invariants",
        "encode-invariants",
    }
    for label in vector_labels:
        payload = strict_json(entries[label], f"vector {label}")
        if canonical(payload) != entries[label]:
            raise ValidationError(f"vector {label} is not canonical JSON")

    base_article = {
        "id": 7,
        "status": "published",
        "tags": ["compiler", "wordpress"],
        "title": "Typed boundaries",
    }
    expected_vectors: dict[str, object] = {
        "missing-optional": base_article,
        "explicit-null": {**base_article, "summary": None},
        "present-summary": {**base_article, "summary": "A bounded field note."},
        "unicode-title": {**base_article, "title": "Café 🚀"},
        "decomposed-title": {**base_article, "title": "Cafe\u0301"},
        "missing-required": issue("WPHX5202", "/title", "required field", "missing"),
        "wrong-type": issue("WPHX5201", "/id", "integer", "string"),
        "zero-id": issue(
            "WPHX5205", "/id", "integer greater than or equal to 1", "0"
        ),
        "unknown-enum": issue(
            "WPHX5205", "/status", "draft|published", "scheduled"
        ),
        "empty-tag": issue(
            "WPHX5205",
            "/tags/0",
            "string with at least 1 Unicode scalar values",
            "length=0",
        ),
        "too-many-tags": issue(
            "WPHX5205", "/tags", "array with at most 8 items", "length=9"
        ),
        "unknown-field": issue(
            "WPHX5203", "/extra", "closed field set", "unknown-field"
        ),
        "unicode-key-order": issue(
            "WPHX5203", "/", "closed field set", "unknown-field"
        ),
        "duplicate-field": issue(
            "WPHX5204", "/title", "one field occurrence", "duplicate-field"
        ),
        "invalid-title": issue(
            "WPHX5205",
            "/title",
            "site.article.title.nonblank@1",
            "constraint-failed",
        ),
        "null-required": issue("WPHX5201", "/title", "string", "null"),
    }
    for label, expected in expected_vectors.items():
        actual = strict_json(entries[label], f"vector {label}")
        if actual != expected:
            raise ValidationError(f"vector {label} has incorrect semantics")

    for label, mutation in mutation_corpus(document):
        try:
            validator.validate(mutation)
            semantic_validate(mutation)
        except ValidationError:
            continue
        raise ValidationError(f"mutation {label} did not fail closed")

    print(
        "ADR-009 contract schema passed: "
        f"{len(vector_labels) + 1} vectors, 27 Haxe invariants, "
        f"{len(mutation_corpus(document))} independent mutations"
    )


if __name__ == "__main__":
    main()
