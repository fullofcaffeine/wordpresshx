#!/usr/bin/env python3
"""Exercise the ADR-007 ownership schema and crash-recovery contract."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_SCHEMA_PATH = ROOT / "schemas" / "generated-files.schema.json"
JOURNAL_SCHEMA_PATH = (
    ROOT / "schemas" / "ownership-transaction-journal.schema.json"
)
CURRENT_FIXTURE_PATH = (
    ROOT / "fixtures" / "ownership" / "valid" / "current.generated-files.json"
)
NEXT_FIXTURE_PATH = (
    ROOT / "fixtures" / "ownership" / "valid" / "next.generated-files.json"
)
JOURNAL_FIXTURE_PATH = (
    ROOT / "fixtures" / "ownership" / "valid" / "prepared.journal.json"
)
ARTIFACT_ROOT = ROOT / "fixtures" / "ownership" / "artifacts"
SCRIPT_PATH = Path(__file__).resolve()

MANIFEST_RELATIVE = "build/_GeneratedFiles.json"
TRANSACTION_ROOT_RELATIVE = "build/.wphx-transactions"
LOCK_RELATIVE = f"{TRANSACTION_ROOT_RELATIVE}/lock"
JOURNAL_RELATIVE = f"{TRANSACTION_ROOT_RELATIVE}/journal.json"
FIXTURE_TRANSACTION_ID = (
    "ddc0b729820b7dbbe6a5655f5ca506660c38a39b66718a0bd9e67e1ca2c91e07"
)

INITIAL_PLUGIN_PATH = ARTIFACT_ROOT / "initial" / "acme-observatory.php.txt"
INITIAL_STALE_PATH = ARTIFACT_ROOT / "initial" / "stale.php.txt"
NEXT_PLUGIN_PATH = ARTIFACT_ROOT / "next" / "acme-observatory.php.txt"
NEXT_THEME_PATH = ARTIFACT_ROOT / "next" / "theme.json.txt"

PLUGIN_RELATIVE = "build/site/acme-observatory/acme-observatory.php"
STALE_RELATIVE = "build/site/acme-observatory/stale.php"
THEME_RELATIVE = "build/site/acme-observatory/theme.json"
UNOWNED_RELATIVE = "build/site/acme-observatory/README.txt"

PORTABLE_SEGMENT = re.compile(r"^[A-Za-z0-9._@+-]+$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
STABLE_ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:[._:/-][a-z0-9]+)*$")
WINDOWS_RESERVED = {
    "con",
    "prn",
    "aux",
    "nul",
    *(f"com{index}" for index in range(1, 10)),
    *(f"lpt{index}" for index in range(1, 10)),
}


class ContractError(ValueError):
    pass


class SimulatedCrash(RuntimeError):
    """Leaves the durable journal and work tree behind like an abrupt exit."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256(path.read_bytes())


def normalize_value(value: object, location: str = "$") -> object:
    if value is None or isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        raise ContractError(f"{location}: floating-point JSON is forbidden")
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)
    if isinstance(value, list):
        return [
            normalize_value(child, f"{location}[{index}]")
            for index, child in enumerate(value)
        ]
    if isinstance(value, dict):
        result: dict[str, object] = {}
        for key, child in value.items():
            if not isinstance(key, str):
                raise ContractError(f"{location}: JSON key is not a string")
            normalized = unicodedata.normalize("NFC", key)
            if normalized in result:
                raise ContractError(
                    f"{location}: duplicate key after NFC normalization: {normalized}"
                )
            result[normalized] = normalize_value(child, f"{location}.{normalized}")
        return result
    raise ContractError(f"{location}: unsupported JSON type {type(value).__name__}")


def canonical(value: object, *, newline: bool = False) -> bytes:
    encoded = json.dumps(
        normalize_value(value),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return encoded + (b"\n" if newline else b"")


def strict_json(data: bytes, label: str) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ContractError(f"{label}: duplicate JSON key {key}")
            result[key] = value
        return result

    def reject_float(value: str) -> object:
        raise ContractError(f"{label}: floating-point JSON {value} is forbidden")

    def reject_constant(value: str) -> object:
        raise ContractError(f"{label}: non-finite JSON {value} is forbidden")

    try:
        return json.loads(
            data,
            object_pairs_hook=pairs,
            parse_float=reject_float,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError(f"{label}: malformed UTF-8 JSON") from error


def read_canonical(path: Path, label: str) -> dict[str, object]:
    data = path.read_bytes()
    value = strict_json(data, label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected JSON object")
    if data != canonical(value, newline=True):
        raise ContractError(f"{label}: expected canonical JSON plus one LF")
    return value


def read_json_object(path: Path, label: str) -> dict[str, object]:
    value = strict_json(path.read_bytes(), label)
    if not isinstance(value, dict):
        raise ContractError(f"{label}: expected JSON object")
    return value


def with_digest(value: dict[str, object], field: str) -> dict[str, object]:
    result = copy.deepcopy(value)
    result.pop(field, None)
    result[field] = sha256(canonical(result))
    return result


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
        if "$ref" in current:
            current = self.resolve(str(current["$ref"]))
        if "oneOf" in current:
            matches = 0
            errors: list[str] = []
            for candidate in current["oneOf"]:
                try:
                    self.validate(value, candidate, location)
                    matches += 1
                except ContractError as error:
                    errors.append(str(error))
            if matches != 1:
                raise ContractError(
                    f"{location}: expected exactly one schema match, found {matches}: "
                    + "; ".join(errors)
                )
            return
        if "const" in current and value != current["const"]:
            raise ContractError(
                f"{location}: expected {current['const']!r}, found {value!r}"
            )
        if "enum" in current and value not in current["enum"]:
            raise ContractError(f"{location}: value is outside the closed enum")
        expected_type = current.get("type")
        if expected_type is not None:
            self.require_type(value, str(expected_type), location)
        if isinstance(value, str):
            if len(value) < int(current.get("minLength", 0)):
                raise ContractError(f"{location}: string is too short")
            pattern = current.get("pattern")
            if pattern is not None and re.fullmatch(str(pattern), value) is None:
                raise ContractError(f"{location}: string does not match {pattern}")
        if isinstance(value, int) and not isinstance(value, bool):
            minimum = current.get("minimum")
            if minimum is not None and value < int(minimum):
                raise ContractError(f"{location}: integer is below {minimum}")
        if isinstance(value, list):
            if len(value) < int(current.get("minItems", 0)):
                raise ContractError(f"{location}: array has too few items")
            if current.get("uniqueItems") is True:
                items = [canonical(item) for item in value]
                if len(items) != len(set(items)):
                    raise ContractError(f"{location}: array contains duplicates")
            item_schema = current.get("items")
            if isinstance(item_schema, dict):
                for index, child in enumerate(value):
                    self.validate(child, item_schema, f"{location}[{index}]")
        if isinstance(value, dict):
            properties = current.get("properties", {})
            for field in current.get("required", []):
                if field not in value:
                    raise ContractError(f"{location}: missing field {field}")
            unknown = sorted(set(value) - set(properties))
            if current.get("additionalProperties") is False and unknown:
                raise ContractError(
                    f"{location}: unknown fields: {', '.join(unknown)}"
                )
            for field, child in value.items():
                field_schema = properties.get(field)
                if isinstance(field_schema, dict):
                    self.validate(child, field_schema, f"{location}.{field}")

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
            raise ContractError(f"{location}: unsupported schema type {expected}")
        if not matches:
            raise ContractError(
                f"{location}: expected {expected}, found {type(value).__name__}"
            )


def require_closed_schema(value: object, location: str = "$schema") -> None:
    if isinstance(value, dict):
        if value.get("type") == "object" and value.get("additionalProperties") is not False:
            raise ContractError(f"{location}: object schema is not closed")
        for key, child in value.items():
            require_closed_schema(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            require_closed_schema(child, f"{location}[{index}]")


def validate_relative(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ContractError(f"{label}: path must be a non-empty string")
    if unicodedata.normalize("NFC", value) != value:
        raise ContractError(f"{label}: path must be NFC")
    if "\\" in value or value.startswith("/") or "\x00" in value:
        raise ContractError(f"{label}: path is not project-relative POSIX")
    if "\n" in value or "\r" in value:
        raise ContractError(f"{label}: path contains a line break")
    segments = value.split("/")
    if any(
        not segment
        or segment in {".", ".."}
        or PORTABLE_SEGMENT.fullmatch(segment) is None
        or segment.endswith((".", " "))
        or segment.split(".", 1)[0].casefold() in WINDOWS_RESERVED
        for segment in segments
    ):
        raise ContractError(f"{label}: path is outside the portable segment policy")
    return value


def collision_key(value: str) -> str:
    return unicodedata.normalize("NFC", value).casefold()


def is_at_or_below(path: str, root: str) -> bool:
    path_parts = PurePosixPath(path).parts
    root_parts = PurePosixPath(root).parts
    return len(path_parts) >= len(root_parts) and path_parts[: len(root_parts)] == root_parts


def content_state(data: bytes | None) -> dict[str, object]:
    if data is None:
        return {"state": "absent"}
    return {"state": "file", "sha256": sha256(data), "sizeBytes": len(data)}


def generation_digest(files: list[dict[str, object]]) -> str:
    material = [
        {
            "contentSha256": item["contentSha256"],
            "path": item["path"],
            "sizeBytes": item["sizeBytes"],
        }
        for item in files
    ]
    return sha256(canonical(material))


def source_span() -> dict[str, object]:
    return {
        "path": "fixtures/semantic-plan/src/SemanticPlanFixture.hx",
        "sourceSha256": (
            "462105433b9a20dde949d7749c9897de0da223f86d6029d0b62fbc32ec71dd54"
        ),
        "start": {"offset": 61, "line": 4, "column": 1},
        "end": {"offset": 111, "line": 4, "column": 51},
        "symbol": "fixtures.semanticplan.SemanticPlanFixture.moduleId",
    }


def file_entry(
    relative: str,
    data: bytes,
    kind: str,
    projection: str,
) -> dict[str, object]:
    return {
        "path": relative,
        "rootId": "build",
        "contentSha256": sha256(data),
        "sizeBytes": len(data),
        "kind": kind,
        "ownerNodeId": "module/acme-observatory",
        "projectionIds": [projection],
        "sourceNodeIds": ["module/acme-observatory"],
        "sourceSpans": [source_span()],
        "validatorIds": ["fixture.bytes"],
    }


def make_manifest(
    entries: list[dict[str, object]],
    *,
    source_sha256: str | None = None,
) -> dict[str, object]:
    files = sorted(copy.deepcopy(entries), key=lambda item: str(item["path"]))
    script_digest = source_sha256 or file_sha256(SCRIPT_PATH)
    value: dict[str, object] = {
        "schema": "wordpress-hx.generated-files.v1",
        "canonicalization": "wordpress-hx.canonical-json.v1",
        "transactionProtocol": "wordpress-hx.ownership-transaction.v1",
        "manifestDigestAlgorithm": (
            "sha256-canonical-json-without-manifestDigest-v1"
        ),
        "locations": {
            "manifestPath": MANIFEST_RELATIVE,
            "transactionRoot": TRANSACTION_ROOT_RELATIVE,
            "lockPath": LOCK_RELATIVE,
            "journalPath": JOURNAL_RELATIVE,
        },
        "generator": {
            "sdkVersion": "0.0.0-dev",
            "cliVersion": "0.0.0-dev",
            "generatorId": "wordpress-hx.ownership.contract-fixture",
            "generatorSourceSha256": script_digest,
            "toolchainSha256": (
                "549f0b84740be8df96ecb576690358874cb173a37aeb62298e6ae9cbb0bd5a46"
            ),
        },
        "inputs": {
            "sourceTreeSha256": (
                "f4eb38f34bc4aa1e048dd382379b86cb6d209a3e31d482c55d31a14e59722f2c"
            ),
            "semanticPlanSha256": (
                "9de65539baed674562f90707a2d5bbe0fe1f089022c7ca17d25f8f31f158fd49"
            ),
            "emissionResultSha256s": [
                "5a265058db49d614a25cec15d9175efe7bc3c6a682418e663ec5c4b9aac1e2e3"
            ],
            "generationSha256": generation_digest(files),
            "profile": {
                "profileId": "wp70-release",
                "catalogRevision": "wp70-release/catalog-v1",
                "catalogSha256": (
                    "530a1581d07e7509fb68f7da5b53575009ed4a94280513efd82a8c99622d9d61"
                ),
            },
        },
        "outputRoots": [
            {
                "rootId": "build",
                "path": "build",
                "ownershipMode": "exact-file-manifest-coexists-with-unowned",
            }
        ],
        "validators": [
            {
                "validatorId": "fixture.bytes",
                "tool": "ADR-007 contract fixture",
                "version": "v1",
                "toolSha256": script_digest,
                "configSha256": file_sha256(MANIFEST_SCHEMA_PATH),
                "scope": "complete-staged-tree",
                "outcome": "passed",
            }
        ],
        "files": files,
    }
    return with_digest(value, "manifestDigest")


def fixture_manifests() -> tuple[dict[str, object], dict[str, object]]:
    current = make_manifest(
        [
            file_entry(
                PLUGIN_RELATIVE,
                INITIAL_PLUGIN_PATH.read_bytes(),
                "plugin.bootstrap.php",
                "php/acme-observatory/bootstrap",
            ),
            file_entry(
                STALE_RELATIVE,
                INITIAL_STALE_PATH.read_bytes(),
                "plugin.support.php",
                "php/acme-observatory/stale",
            ),
        ]
    )
    next_manifest = make_manifest(
        [
            file_entry(
                PLUGIN_RELATIVE,
                NEXT_PLUGIN_PATH.read_bytes(),
                "plugin.bootstrap.php",
                "php/acme-observatory/bootstrap",
            ),
            file_entry(
                THEME_RELATIVE,
                NEXT_THEME_PATH.read_bytes(),
                "theme.metadata.json",
                "metadata/acme-observatory/theme",
            ),
        ]
    )
    return current, next_manifest


def manifest_file_map(value: dict[str, object]) -> dict[str, dict[str, object]]:
    return {str(item["path"]): item for item in value["files"]}


def validate_manifest(
    value: dict[str, object], validator: ClosedSchemaValidator
) -> None:
    validator.validate(value)
    if value != normalize_value(value):
        raise ContractError("manifest: strings are not NFC-normalized")
    expected = with_digest(value, "manifestDigest")["manifestDigest"]
    if value["manifestDigest"] != expected:
        raise ContractError("manifest: manifestDigest does not bind canonical bytes")

    locations = value["locations"]
    for field, path in locations.items():
        validate_relative(path, f"manifest.locations.{field}")
    transaction_root = str(locations["transactionRoot"])
    if locations["lockPath"] != f"{transaction_root}/lock":
        raise ContractError("manifest: lockPath is not the reserved transaction lock")
    if locations["journalPath"] != f"{transaction_root}/journal.json":
        raise ContractError("manifest: journalPath is not the reserved journal")
    manifest_path = str(locations["manifestPath"])
    if is_at_or_below(manifest_path, transaction_root) or is_at_or_below(
        transaction_root, manifest_path
    ):
        raise ContractError(
            "manifest: ownership manifest and transaction root must be disjoint"
        )

    roots = value["outputRoots"]
    if roots != sorted(roots, key=lambda item: (item["path"], item["rootId"])):
        raise ContractError("manifest: output roots are not deterministically sorted")
    root_ids: set[str] = set()
    root_keys: set[str] = set()
    for index, root in enumerate(roots):
        path = validate_relative(root["path"], f"manifest.outputRoots[{index}]")
        if root["rootId"] in root_ids or collision_key(path) in root_keys:
            raise ContractError("manifest: duplicate output root identity or path")
        for other in roots[:index]:
            if is_at_or_below(path, str(other["path"])) or is_at_or_below(
                str(other["path"]), path
            ):
                raise ContractError("manifest: nested output roots are forbidden in v1")
        root_ids.add(str(root["rootId"]))
        root_keys.add(collision_key(path))
    for reserved in (manifest_path, transaction_root):
        if not any(
            reserved != str(root["path"])
            and is_at_or_below(reserved, str(root["path"]))
            for root in roots
        ):
            raise ContractError("manifest: reserved ownership path is outside output roots")

    validators = value["validators"]
    validator_ids = [str(item["validatorId"]) for item in validators]
    if validator_ids != sorted(validator_ids) or len(validator_ids) != len(
        set(validator_ids)
    ):
        raise ContractError("manifest: validator IDs are not a sorted unique set")

    files = value["files"]
    file_paths = [str(item["path"]) for item in files]
    if file_paths != sorted(file_paths):
        raise ContractError("manifest: files are not sorted by exact path")
    if len({collision_key(path) for path in file_paths}) != len(file_paths):
        raise ContractError("manifest: duplicate or case-folding-colliding file path")
    for index, item in enumerate(files):
        path = validate_relative(item["path"], f"manifest.files[{index}].path")
        if path == locations["manifestPath"] or is_at_or_below(path, transaction_root):
            raise ContractError("manifest: generated file uses a reserved ownership path")
        owners = [
            root
            for root in roots
            if is_at_or_below(path, str(root["path"]))
        ]
        if len(owners) != 1 or item["rootId"] != owners[0]["rootId"]:
            raise ContractError("manifest: file is not confined to its declared root")
        if not SHA256_PATTERN.fullmatch(str(item["contentSha256"])):
            raise ContractError("manifest: invalid content digest")
        if item["projectionIds"] != sorted(item["projectionIds"]):
            raise ContractError("manifest: projection IDs are not sorted")
        if item["sourceNodeIds"] != sorted(item["sourceNodeIds"]):
            raise ContractError("manifest: source node IDs are not sorted")
        if item["validatorIds"] != sorted(item["validatorIds"]):
            raise ContractError("manifest: validator IDs are not sorted")
        if not set(item["validatorIds"]).issubset(validator_ids):
            raise ContractError("manifest: file names an unknown validator")
        spans = item["sourceSpans"]
        span_keys = [
            (
                span["path"],
                span["start"]["offset"],
                span["end"]["offset"],
                span["symbol"],
            )
            for span in spans
        ]
        if span_keys != sorted(span_keys):
            raise ContractError("manifest: source spans are not sorted")
        for span in spans:
            validate_relative(span["path"], "manifest.file.sourceSpan.path")
            if span["start"]["offset"] >= span["end"]["offset"]:
                raise ContractError("manifest: source span is empty or reversed")
    if value["inputs"]["emissionResultSha256s"] != sorted(
        value["inputs"]["emissionResultSha256s"]
    ):
        raise ContractError("manifest: emission result digests are not sorted")
    if value["inputs"]["generationSha256"] != generation_digest(files):
        raise ContractError("manifest: generation digest does not bind file set")


def make_journal(
    current: dict[str, object] | None,
    next_manifest: dict[str, object],
    *,
    transaction_id: str = FIXTURE_TRANSACTION_ID,
    mode: str = "build",
    relinquish: set[str] | None = None,
) -> dict[str, object]:
    relinquished = relinquish or set()
    work_root = f"{TRANSACTION_ROOT_RELATIVE}/{transaction_id}"
    stage_root = f"{work_root}/stage"
    backup_root = f"{work_root}/backup"
    current_files = {} if current is None else manifest_file_map(current)
    next_files = manifest_file_map(next_manifest)
    if mode == "build" and relinquished:
        raise ContractError("journal: build mode cannot relinquish ownership")
    if mode == "clean" and (next_files or relinquished):
        raise ContractError("journal: clean mode requires an empty next ownership set")
    if mode == "adopt-generated":
        if current is None or not relinquished:
            raise ContractError(
                "journal: adopt-generated requires existing exact owned paths"
            )
        if set(next_files) != set(current_files) - relinquished:
            raise ContractError(
                "journal: adopt-generated may only reduce the current ownership set"
            )
        if any(next_files[path] != current_files[path] for path in next_files):
            raise ContractError(
                "journal: adopt-generated cannot rewrite retained ownership entries"
            )
    operations: list[dict[str, object]] = []
    for index, path in enumerate(sorted(set(current_files) | set(next_files)), start=1):
        old = current_files.get(path)
        new = next_files.get(path)
        if path in relinquished:
            if old is None or new is not None:
                raise ContractError("journal: relinquish must remove one owned entry")
            action = "relinquish"
            new_state = {
                "state": "file",
                "sha256": old["contentSha256"],
                "sizeBytes": old["sizeBytes"],
            }
        elif old is None:
            action = "create"
            new_state = {
                "state": "file",
                "sha256": new["contentSha256"],
                "sizeBytes": new["sizeBytes"],
            }
        elif new is None:
            action = "remove"
            new_state = {"state": "absent"}
        elif old["contentSha256"] != new["contentSha256"]:
            action = "replace"
            new_state = {
                "state": "file",
                "sha256": new["contentSha256"],
                "sizeBytes": new["sizeBytes"],
            }
        else:
            continue
        old_state = (
            {"state": "absent"}
            if old is None
            else {
                "state": "file",
                "sha256": old["contentSha256"],
                "sizeBytes": old["sizeBytes"],
            }
        )
        root_id = str((new or old)["rootId"])
        operations.append(
            {
                "operationId": f"op/{index:04d}",
                "action": action,
                "path": path,
                "rootId": root_id,
                "oldContent": old_state,
                "newContent": new_state,
                "backupPath": f"{backup_root}/{path}",
                "stagedPath": f"{stage_root}/{path}",
            }
        )
    value: dict[str, object] = {
        "schema": "wordpress-hx.ownership-journal.v1",
        "canonicalization": "wordpress-hx.canonical-json.v1",
        "journalDigestAlgorithm": (
            "sha256-canonical-json-without-journalDigest-v1"
        ),
        "transactionId": transaction_id,
        "mode": mode,
        "phase": "prepared",
        "locations": {
            "manifestPath": MANIFEST_RELATIVE,
            "transactionRoot": TRANSACTION_ROOT_RELATIVE,
            "lockPath": LOCK_RELATIVE,
            "journalPath": JOURNAL_RELATIVE,
            "workRoot": work_root,
            "stageRoot": stage_root,
            "backupRoot": backup_root,
        },
        "priorManifest": {
            "content": content_state(
                None if current is None else canonical(current, newline=True)
            ),
            "storagePath": f"{work_root}/prior-manifest.json",
        },
        "nextManifest": {
            "content": content_state(canonical(next_manifest, newline=True)),
            "storagePath": f"{work_root}/next-manifest.json",
        },
        "operations": operations,
    }
    return with_digest(value, "journalDigest")


def validate_content_state(value: dict[str, object], label: str) -> None:
    if value["state"] == "absent":
        if set(value) != {"state"}:
            raise ContractError(f"{label}: absent content has extra fields")
        return
    if value["state"] != "file" or set(value) != {
        "state",
        "sha256",
        "sizeBytes",
    }:
        raise ContractError(f"{label}: invalid file content descriptor")
    if not SHA256_PATTERN.fullmatch(str(value["sha256"])):
        raise ContractError(f"{label}: invalid content digest")
    if not isinstance(value["sizeBytes"], int) or value["sizeBytes"] < 0:
        raise ContractError(f"{label}: invalid content size")


def validate_journal(
    value: dict[str, object], validator: ClosedSchemaValidator
) -> None:
    validator.validate(value)
    if value != normalize_value(value):
        raise ContractError("journal: strings are not NFC-normalized")
    expected = with_digest(value, "journalDigest")["journalDigest"]
    if value["journalDigest"] != expected:
        raise ContractError("journal: journalDigest does not bind canonical bytes")
    transaction_id = str(value["transactionId"])
    if SHA256_PATTERN.fullmatch(transaction_id) is None:
        raise ContractError("journal: invalid transaction ID")
    locations = value["locations"]
    for field, path in locations.items():
        validate_relative(path, f"journal.locations.{field}")
    work_root = f"{locations['transactionRoot']}/{transaction_id}"
    if locations != {
        "manifestPath": MANIFEST_RELATIVE,
        "transactionRoot": TRANSACTION_ROOT_RELATIVE,
        "lockPath": LOCK_RELATIVE,
        "journalPath": JOURNAL_RELATIVE,
        "workRoot": work_root,
        "stageRoot": f"{work_root}/stage",
        "backupRoot": f"{work_root}/backup",
    }:
        raise ContractError("journal: reserved locations do not match transaction ID")
    for label in ("priorManifest", "nextManifest"):
        state = value[label]
        validate_content_state(state["content"], f"journal.{label}.content")
        validate_relative(state["storagePath"], f"journal.{label}.storagePath")
        if not is_at_or_below(state["storagePath"], work_root):
            raise ContractError(f"journal: {label} storage escapes work root")

    operations = value["operations"]
    paths = [str(operation["path"]) for operation in operations]
    if paths != sorted(paths) or len({collision_key(path) for path in paths}) != len(
        paths
    ):
        raise ContractError("journal: operation paths are not a sorted unique set")
    operation_ids = [str(operation["operationId"]) for operation in operations]
    if len(operation_ids) != len(set(operation_ids)) or any(
        STABLE_ID_PATTERN.fullmatch(operation_id) is None
        for operation_id in operation_ids
    ):
        raise ContractError("journal: operation IDs are invalid or duplicate")
    actions = [str(operation["action"]) for operation in operations]
    mode = str(value["mode"])
    if mode == "build" and "relinquish" in actions:
        raise ContractError("journal: build mode contains a relinquish operation")
    if mode == "clean" and any(action != "remove" for action in actions):
        raise ContractError("journal: clean mode contains a non-remove operation")
    if mode == "adopt-generated" and (
        not actions or any(action != "relinquish" for action in actions)
    ):
        raise ContractError(
            "journal: adopt-generated must contain only relinquish operations"
        )
    for operation in operations:
        path = validate_relative(operation["path"], "journal.operation.path")
        old = operation["oldContent"]
        new = operation["newContent"]
        validate_content_state(old, "journal.operation.oldContent")
        validate_content_state(new, "journal.operation.newContent")
        expected_states = {
            "create": ("absent", "file"),
            "replace": ("file", "file"),
            "remove": ("file", "absent"),
            "relinquish": ("file", "file"),
        }[operation["action"]]
        if (old["state"], new["state"]) != expected_states:
            raise ContractError("journal: action/content state mismatch")
        if operation["action"] == "replace" and old["sha256"] == new["sha256"]:
            raise ContractError("journal: replace operation does not change content")
        if operation["action"] == "relinquish" and old != new:
            raise ContractError("journal: relinquish changes live bytes")
        expected_backup = f"{locations['backupRoot']}/{path}"
        expected_stage = f"{locations['stageRoot']}/{path}"
        if operation["backupPath"] != expected_backup:
            raise ContractError("journal: backup path is not content-path-derived")
        if operation["stagedPath"] != expected_stage:
            raise ContractError("journal: staged path is not content-path-derived")


def validate_journal_plan(
    value: dict[str, object],
    prior_manifest: dict[str, object] | None,
    next_manifest: dict[str, object],
) -> None:
    mode = str(value["mode"])
    prior_files = {} if prior_manifest is None else manifest_file_map(prior_manifest)
    next_files = manifest_file_map(next_manifest)
    relinquished = (
        set(prior_files) - set(next_files) if mode == "adopt-generated" else set()
    )
    expected = make_journal(
        prior_manifest,
        next_manifest,
        transaction_id=str(value["transactionId"]),
        mode=mode,
        relinquish=relinquished,
    )
    for field in (
        "transactionId",
        "mode",
        "locations",
        "priorManifest",
        "nextManifest",
        "operations",
    ):
        if value[field] != expected[field]:
            raise ContractError(
                f"journal: {field} is not derived from the bound manifests"
            )


def lexists(path: Path) -> bool:
    return os.path.lexists(path)


def assert_safe_components(project: Path, relative: str, label: str) -> None:
    validate_relative(relative, label)
    current = project
    if stat.S_ISLNK(os.lstat(project).st_mode):
        raise ContractError(f"{label}: project root is a symbolic link")
    parts = PurePosixPath(relative).parts
    for index, component in enumerate(parts):
        current = current / component
        if not lexists(current):
            continue
        mode = os.lstat(current).st_mode
        if stat.S_ISLNK(mode):
            raise ContractError(f"{label}: symbolic-link component is forbidden")
        if index < len(parts) - 1 and not stat.S_ISDIR(mode):
            raise ContractError(f"{label}: parent component is not a directory")


def ensure_safe_parent(project: Path, relative: str) -> Path:
    assert_safe_components(project, relative, "destination")
    target = project.joinpath(*PurePosixPath(relative).parts)
    current = project
    for component in PurePosixPath(relative).parts[:-1]:
        current = current / component
        if not lexists(current):
            current.mkdir()
        mode = os.lstat(current).st_mode
        if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
            raise ContractError("destination: unsafe parent appeared during preparation")
    assert_safe_components(project, relative, "destination")
    return target


def require_regular_state(project: Path, relative: str) -> dict[str, object]:
    assert_safe_components(project, relative, "live path")
    path = project.joinpath(*PurePosixPath(relative).parts)
    if not lexists(path):
        return {"state": "absent"}
    mode = os.lstat(path).st_mode
    if not stat.S_ISREG(mode):
        raise ContractError("live path: owned destination is not a regular file")
    return content_state(path.read_bytes())


def descriptor_matches(actual: dict[str, object], expected: dict[str, object]) -> bool:
    return actual == expected


def atomic_write(project: Path, relative: str, data: bytes) -> None:
    target = ensure_safe_parent(project, relative)
    temporary = target.with_name(f".{target.name}.tmp")
    if lexists(temporary):
        raise ContractError("atomic metadata temporary path already exists")
    with temporary.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, target)
    fsync_directory(target.parent)


def fsync_directory(path: Path) -> None:
    try:
        descriptor = os.open(path, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(descriptor)
    except OSError:
        pass
    finally:
        os.close(descriptor)


def is_additive_root_migration(
    current: dict[str, object], next_manifest: dict[str, object]
) -> bool:
    current_roots = current["outputRoots"]
    next_roots = next_manifest["outputRoots"]
    if not isinstance(current_roots, list) or not isinstance(next_roots, list):
        return False
    if len(next_roots) <= len(current_roots):
        return False
    next_by_id = {root["rootId"]: root for root in next_roots}
    return all(next_by_id.get(root["rootId"]) == root for root in current_roots)


def safe_unlink_matching(
    project: Path, relative: str, expected: dict[str, object]
) -> None:
    actual = require_regular_state(project, relative)
    if actual["state"] == "absent":
        return
    if not descriptor_matches(actual, expected):
        raise ContractError("recovery refused to remove unexpected live bytes")
    project.joinpath(*PurePosixPath(relative).parts).unlink()


def remove_empty_parents(project: Path, relatives: list[str]) -> None:
    candidates: set[Path] = set()
    protected = project / "build"
    for relative in relatives:
        current = project.joinpath(*PurePosixPath(relative).parts).parent
        while current != protected and protected in current.parents:
            candidates.add(current)
            current = current.parent
    for directory in sorted(candidates, key=lambda value: len(value.parts), reverse=True):
        if lexists(directory) and not directory.is_symlink() and directory.is_dir():
            try:
                directory.rmdir()
            except OSError:
                pass


class FixtureTransaction:
    """Reference-only transaction harness; SDK-041 owns the production port."""

    def __init__(
        self,
        manifest_validator: ClosedSchemaValidator,
        journal_validator: ClosedSchemaValidator,
    ) -> None:
        self.manifest_validator = manifest_validator
        self.journal_validator = journal_validator
        self.counter = 0

    def path(self, project: Path, relative: str) -> Path:
        return project.joinpath(*PurePosixPath(relative).parts)

    def read_manifest(self, project: Path) -> dict[str, object] | None:
        path = self.path(project, MANIFEST_RELATIVE)
        if not lexists(path):
            return None
        assert_safe_components(project, MANIFEST_RELATIVE, "ownership manifest")
        if not stat.S_ISREG(os.lstat(path).st_mode):
            raise ContractError("ownership manifest is not a regular file")
        value = read_canonical(path, "ownership manifest")
        validate_manifest(value, self.manifest_validator)
        return value

    def verify_owned_tree(self, project: Path, manifest: dict[str, object]) -> None:
        for item in manifest["files"]:
            actual = require_regular_state(project, str(item["path"]))
            expected = {
                "state": "file",
                "sha256": item["contentSha256"],
                "sizeBytes": item["sizeBytes"],
            }
            if actual != expected:
                raise ContractError(
                    f"owned file is missing or modified: {item['path']}"
                )

    def check_root_safety(self, project: Path, manifest: dict[str, object]) -> None:
        device: int | None = None
        for root in manifest["outputRoots"]:
            relative = str(root["path"])
            assert_safe_components(project, relative, "output root")
            path = self.path(project, relative)
            if lexists(path):
                mode = os.lstat(path).st_mode
                if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
                    raise ContractError("output root is not a real directory")
                probe = path
            else:
                probe = path.parent
                while not lexists(probe):
                    probe = probe.parent
                mode = os.lstat(probe).st_mode
                if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
                    raise ContractError("output root has no safe existing ancestor")
            observed = os.stat(probe).st_dev
            if device is None:
                device = observed
            elif observed != device:
                raise ContractError("v1 output roots must use one filesystem")

    def acquire_lock(self, project: Path) -> None:
        lock = ensure_safe_parent(project, LOCK_RELATIVE)
        try:
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError as error:
            raise ContractError("ownership transaction lock already exists") from error
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(b"wordpress-hx.ownership-lock.v1\n")
            handle.flush()
            os.fsync(handle.fileno())

    def release_lock(self, project: Path) -> None:
        lock = self.path(project, LOCK_RELATIVE)
        if lexists(lock):
            if lock.is_symlink() or not lock.is_file():
                raise ContractError("ownership lock changed type")
            lock.unlink()

    def transaction_id(
        self,
        current: dict[str, object] | None,
        next_manifest: dict[str, object],
        mode: str,
    ) -> str:
        self.counter += 1
        material = (
            ("absent" if current is None else str(current["manifestDigest"]))
            + str(next_manifest["manifestDigest"])
            + mode
            + str(self.counter)
        ).encode("utf-8")
        return sha256(material)

    def publish(
        self,
        project: Path,
        next_manifest: dict[str, object],
        staged: dict[str, bytes],
        *,
        mode: str = "build",
        relinquish: set[str] | None = None,
        validator_passed: bool = True,
        injection: str | None = None,
    ) -> str:
        validate_manifest(next_manifest, self.manifest_validator)
        if next_manifest["locations"] != {
            "manifestPath": MANIFEST_RELATIVE,
            "transactionRoot": TRANSACTION_ROOT_RELATIVE,
            "lockPath": LOCK_RELATIVE,
            "journalPath": JOURNAL_RELATIVE,
        }:
            raise ContractError(
                "fixture transaction only supports its declared reserved locations"
            )
        journal_target = self.path(project, JOURNAL_RELATIVE)
        if lexists(journal_target):
            raise ContractError("interrupted transaction must recover before new work")
        if lexists(journal_target.with_name(f".{journal_target.name}.tmp")):
            raise ContractError("orphan journal temporary requires explicit diagnosis")
        live_current = self.read_manifest(project)
        current = live_current or make_manifest([])
        if live_current is not None and current["locations"] != next_manifest["locations"]:
            raise ContractError("v1 cannot migrate ownership metadata locations implicitly")
        if (
            live_current is not None
            and current["outputRoots"] != next_manifest["outputRoots"]
            and not is_additive_root_migration(current, next_manifest)
        ):
            raise ContractError("v1 only permits an additive exact output-root migration")
        self.check_root_safety(project, next_manifest)
        self.verify_owned_tree(project, current)
        if not validator_passed:
            raise ContractError("staged validator failed before journal creation")

        relinquished = relinquish or set()
        current_files = manifest_file_map(current)
        next_files = manifest_file_map(next_manifest)
        if mode not in {"build", "clean", "adopt-generated"}:
            raise ContractError("unknown ownership transaction mode")
        if mode == "build" and relinquished:
            raise ContractError("build mode cannot relinquish ownership")
        if mode == "clean" and (next_files or relinquished):
            raise ContractError("clean mode requires an empty next ownership set")
        if mode == "adopt-generated":
            if live_current is None or not relinquished:
                raise ContractError(
                    "adopt-generated requires existing exact owned paths"
                )
            if set(next_files) != set(current_files) - relinquished:
                raise ContractError(
                    "adopt-generated may only reduce the current ownership set"
                )
            if any(next_files[path] != current_files[path] for path in next_files):
                raise ContractError(
                    "adopt-generated cannot rewrite retained ownership entries"
                )

        for relative, item in next_files.items():
            assert_safe_components(project, relative, "next destination")
            old = current_files.get(relative)
            if old is None and lexists(self.path(project, relative)):
                raise ContractError(f"unowned destination already exists: {relative}")
            if mode == "build":
                data = staged.get(relative)
                expected = {
                    "state": "file",
                    "sha256": item["contentSha256"],
                    "sizeBytes": item["sizeBytes"],
                }
                if data is None or content_state(data) != expected:
                    raise ContractError(f"staged bytes do not match manifest: {relative}")
        if mode == "build" and set(staged) != set(next_files):
            raise ContractError(
                "build staging tree is not the complete next ownership set"
            )
        if mode != "build" and staged:
            raise ContractError(f"{mode} cannot stage generated artifact bytes")
        if not relinquished.issubset(current_files) or relinquished & set(next_files):
            raise ContractError("relinquish set is not an exact owned removal set")

        if (
            live_current is not None
            and current["manifestDigest"] == next_manifest["manifestDigest"]
            and not relinquished
        ):
            return "no-op"

        output_root_existed = lexists(self.path(project, "build"))
        transaction_root_existed = lexists(
            self.path(project, TRANSACTION_ROOT_RELATIVE)
        )
        self.acquire_lock(project)
        work_root: str | None = None
        try:
            self.verify_owned_tree(project, current)
            transaction_id = self.transaction_id(live_current, next_manifest, mode)
            journal = make_journal(
                live_current,
                next_manifest,
                transaction_id=transaction_id,
                mode=mode,
                relinquish=relinquished,
            )
            validate_journal(journal, self.journal_validator)
            validate_journal_plan(journal, live_current, next_manifest)
            candidate_work_root = str(journal["locations"]["workRoot"])
            if lexists(self.path(project, candidate_work_root)):
                raise ContractError("fresh transaction work root already exists")
            self.path(project, candidate_work_root).mkdir(parents=True)
            work_root = candidate_work_root
            next_bytes = canonical(next_manifest, newline=True)
            if live_current is not None:
                atomic_write(
                    project,
                    str(journal["priorManifest"]["storagePath"]),
                    canonical(live_current, newline=True),
                )
            atomic_write(
                project,
                str(journal["nextManifest"]["storagePath"]),
                next_bytes,
            )
            for operation in journal["operations"]:
                if operation["newContent"]["state"] != "file":
                    continue
                if operation["action"] == "relinquish":
                    continue
                data = staged[str(operation["path"])]
                atomic_write(project, str(operation["stagedPath"]), data)
            atomic_write(project, JOURNAL_RELATIVE, canonical(journal, newline=True))
            return self.commit(project, journal, injection=injection)
        except SimulatedCrash:
            raise
        except Exception:
            journal_path = self.path(project, JOURNAL_RELATIVE)
            if lexists(journal_path):
                try:
                    recovery = self.recover(project)
                    if recovery == "finalized":
                        return "published-recovered"
                except Exception as recovery_error:
                    raise ContractError(
                        "publication failed and automatic recovery requires diagnosis"
                    ) from recovery_error
            else:
                self.cleanup_prejournal(
                    project,
                    work_root,
                    output_root_existed=output_root_existed,
                    transaction_root_existed=transaction_root_existed,
                )
            raise

    def cleanup_prejournal(
        self,
        project: Path,
        work_root: str | None,
        *,
        output_root_existed: bool,
        transaction_root_existed: bool,
    ) -> None:
        if work_root is not None:
            if not is_at_or_below(work_root, TRANSACTION_ROOT_RELATIVE):
                raise ContractError("pre-journal work root escaped transaction root")
            path = self.path(project, work_root)
            if lexists(path):
                if path.is_symlink() or not path.is_dir():
                    raise ContractError("pre-journal work root changed type")
                shutil.rmtree(path)
        journal_target = self.path(project, JOURNAL_RELATIVE)
        journal_temporary = journal_target.with_name(f".{journal_target.name}.tmp")
        if lexists(journal_temporary):
            mode = os.lstat(journal_temporary).st_mode
            if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
                raise ContractError("pre-journal temporary changed type")
            journal_temporary.unlink()
        self.release_lock(project)
        transaction_root = self.path(project, TRANSACTION_ROOT_RELATIVE)
        if not transaction_root_existed and lexists(transaction_root):
            transaction_root.rmdir()
        output_root = self.path(project, "build")
        if not output_root_existed and lexists(output_root):
            output_root.rmdir()

    def read_journal(self, project: Path) -> dict[str, object]:
        path = self.path(project, JOURNAL_RELATIVE)
        assert_safe_components(project, JOURNAL_RELATIVE, "ownership journal")
        value = read_canonical(path, "ownership journal")
        validate_journal(value, self.journal_validator)
        return value

    def journal_manifest(
        self,
        project: Path,
        journal: dict[str, object],
        field: str,
    ) -> dict[str, object] | None:
        state = journal[field]
        expected = state["content"]
        storage_relative = str(state["storagePath"])
        storage_actual = require_regular_state(project, storage_relative)
        if expected["state"] == "absent":
            if storage_actual["state"] != "absent":
                raise ContractError(f"journal: absent {field} has stored bytes")
            return None
        if storage_actual["state"] != "absent":
            if storage_actual != expected:
                raise ContractError(f"journal: stored {field} bytes are unexpected")
            source_relative = storage_relative
        else:
            live_actual = require_regular_state(project, MANIFEST_RELATIVE)
            if live_actual != expected:
                raise ContractError(f"journal: bound {field} bytes are missing")
            source_relative = MANIFEST_RELATIVE
        value = read_canonical(self.path(project, source_relative), field)
        validate_manifest(value, self.manifest_validator)
        return value

    def validate_bound_journal(
        self, project: Path, journal: dict[str, object]
    ) -> None:
        prior_manifest = self.journal_manifest(project, journal, "priorManifest")
        next_manifest = self.journal_manifest(project, journal, "nextManifest")
        if next_manifest is None:
            raise ContractError("journal: next manifest must always be present")
        validate_journal_plan(journal, prior_manifest, next_manifest)

    def update_phase(
        self, project: Path, journal: dict[str, object], phase: str
    ) -> dict[str, object]:
        updated = copy.deepcopy(journal)
        updated["phase"] = phase
        updated = with_digest(updated, "journalDigest")
        validate_journal(updated, self.journal_validator)
        atomic_write(project, JOURNAL_RELATIVE, canonical(updated, newline=True))
        return updated

    def commit(
        self,
        project: Path,
        journal: dict[str, object],
        *,
        injection: str | None,
    ) -> str:
        journal = self.update_phase(project, journal, "publishing")
        published = 0
        for operation in journal["operations"]:
            action = str(operation["action"])
            if action == "relinquish":
                continue
            live = self.path(project, str(operation["path"]))
            backup = ensure_safe_parent(project, str(operation["backupPath"]))
            stage = self.path(project, str(operation["stagedPath"]))
            old = operation["oldContent"]
            if old["state"] == "file":
                if require_regular_state(project, str(operation["path"])) != old:
                    raise ContractError("live bytes changed after transaction preflight")
                os.replace(live, backup)
            elif lexists(live):
                raise ContractError("unowned live destination appeared during publication")
            if operation["newContent"]["state"] == "file":
                ensure_safe_parent(project, str(operation["path"]))
                if require_regular_state(project, str(operation["stagedPath"])) != operation[
                    "newContent"
                ]:
                    raise ContractError("staged bytes changed during publication")
                os.replace(stage, live)
            published += 1
            if published == 1 and injection == "failure-after-first-operation":
                raise ContractError("simulated caught publication failure")
            if published == 1 and injection == "crash-after-first-operation":
                raise SimulatedCrash("simulated abrupt publication interruption")

        next_storage = str(journal["nextManifest"]["storagePath"])
        if require_regular_state(project, next_storage) != journal["nextManifest"][
            "content"
        ]:
            raise ContractError("staged next manifest changed before publication")
        os.replace(
            self.path(project, next_storage),
            ensure_safe_parent(project, MANIFEST_RELATIVE),
        )
        fsync_directory(self.path(project, MANIFEST_RELATIVE).parent)
        journal = self.update_phase(project, journal, "manifest-published")
        if injection == "failure-after-manifest":
            raise ContractError("simulated caught failure after manifest commit marker")
        if injection == "crash-after-manifest":
            raise SimulatedCrash("simulated crash after manifest commit marker")
        self.finalize(project, journal)
        return "published"

    def live_next_is_complete(
        self, project: Path, journal: dict[str, object]
    ) -> bool:
        actual_manifest = require_regular_state(project, MANIFEST_RELATIVE)
        if actual_manifest != journal["nextManifest"]["content"]:
            return False
        try:
            manifest = self.read_manifest(project)
            if manifest is None:
                return False
            self.verify_owned_tree(project, manifest)
        except ContractError:
            return False
        for operation in journal["operations"]:
            if operation["action"] == "remove":
                if require_regular_state(project, str(operation["path"]))["state"] != "absent":
                    return False
            if operation["action"] == "relinquish":
                if require_regular_state(project, str(operation["path"])) != operation[
                    "newContent"
                ]:
                    return False
        return True

    def recover(self, project: Path) -> str:
        if not lexists(self.path(project, JOURNAL_RELATIVE)):
            if lexists(self.path(project, LOCK_RELATIVE)):
                raise ContractError("orphan ownership lock requires explicit diagnosis")
            return "nothing-to-recover"
        journal = self.read_journal(project)
        if not lexists(self.path(project, LOCK_RELATIVE)):
            raise ContractError("journal exists without its transaction lock")
        self.validate_bound_journal(project, journal)
        if self.live_next_is_complete(project, journal):
            self.finalize(project, journal)
            return "finalized"
        self.rollback(project, journal)
        return "rolled-back"

    def rollback(self, project: Path, journal: dict[str, object]) -> None:
        for operation in reversed(journal["operations"]):
            if operation["action"] == "relinquish":
                continue
            live_relative = str(operation["path"])
            backup_relative = str(operation["backupPath"])
            backup = self.path(project, backup_relative)
            old = operation["oldContent"]
            new = operation["newContent"]
            if lexists(backup):
                if require_regular_state(project, backup_relative) != old:
                    raise ContractError("rollback backup bytes are unexpected")
                actual_live = require_regular_state(project, live_relative)
                if actual_live["state"] != "absent":
                    if new["state"] != "file" or actual_live != new:
                        raise ContractError("rollback found unexpected live bytes")
                    self.path(project, live_relative).unlink()
                os.replace(backup, ensure_safe_parent(project, live_relative))
            elif old["state"] == "absent":
                safe_unlink_matching(project, live_relative, new)
            elif require_regular_state(project, live_relative) != old:
                raise ContractError("rollback lost both old live bytes and backup")

        prior = journal["priorManifest"]
        current_manifest = require_regular_state(project, MANIFEST_RELATIVE)
        if prior["content"]["state"] == "absent":
            safe_unlink_matching(
                project, MANIFEST_RELATIVE, journal["nextManifest"]["content"]
            )
        elif current_manifest != prior["content"]:
            if current_manifest["state"] != "absent" and current_manifest != journal[
                "nextManifest"
            ]["content"]:
                raise ContractError("rollback found an unexpected ownership manifest")
            prior_storage = str(prior["storagePath"])
            if require_regular_state(project, prior_storage) != prior["content"]:
                raise ContractError("rollback prior manifest backup is missing")
            os.replace(
                self.path(project, prior_storage),
                ensure_safe_parent(project, MANIFEST_RELATIVE),
            )
        self.cleanup_transaction(project, journal)

    def finalize(self, project: Path, journal: dict[str, object]) -> None:
        self.cleanup_transaction(project, journal)

    def cleanup_transaction(
        self, project: Path, journal: dict[str, object]
    ) -> None:
        work_root = self.path(project, str(journal["locations"]["workRoot"]))
        transaction_root = self.path(project, TRANSACTION_ROOT_RELATIVE)
        journal_path = self.path(project, JOURNAL_RELATIVE)
        if lexists(work_root):
            if work_root.is_symlink() or not work_root.is_dir():
                raise ContractError("transaction work root changed type")
            shutil.rmtree(work_root)
        if lexists(journal_path):
            journal_path.unlink()
        self.release_lock(project)
        if lexists(transaction_root):
            try:
                transaction_root.rmdir()
            except OSError:
                pass
        remove_empty_parents(
            project, [str(operation["path"]) for operation in journal["operations"]]
        )
        for root in sorted(
            {
                PurePosixPath(str(operation["path"])).parts[0]
                for operation in journal["operations"]
            },
            reverse=True,
        ):
            root_path = project / root
            if lexists(root_path) and root_path.is_dir() and not root_path.is_symlink():
                try:
                    root_path.rmdir()
                except OSError:
                    pass


def write_project_file(project: Path, relative: str, data: bytes) -> None:
    target = project.joinpath(*PurePosixPath(relative).parts)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def materialize_current(project: Path, current: dict[str, object]) -> None:
    write_project_file(project, PLUGIN_RELATIVE, INITIAL_PLUGIN_PATH.read_bytes())
    write_project_file(project, STALE_RELATIVE, INITIAL_STALE_PATH.read_bytes())
    write_project_file(project, UNOWNED_RELATIVE, b"hand-owned fixture\n")
    write_project_file(project, MANIFEST_RELATIVE, canonical(current, newline=True))


def next_bytes() -> dict[str, bytes]:
    return {
        PLUGIN_RELATIVE: NEXT_PLUGIN_PATH.read_bytes(),
        THEME_RELATIVE: NEXT_THEME_PATH.read_bytes(),
    }


def current_bytes() -> dict[str, bytes]:
    return {
        PLUGIN_RELATIVE: INITIAL_PLUGIN_PATH.read_bytes(),
        STALE_RELATIVE: INITIAL_STALE_PATH.read_bytes(),
    }


def snapshot(project: Path) -> dict[str, tuple[str, bytes | str | int]]:
    result: dict[str, tuple[str, bytes | str | int]] = {}
    for path in sorted(project.rglob("*")):
        relative = path.relative_to(project).as_posix()
        if path.is_symlink():
            result[relative] = ("symlink", os.readlink(path))
        elif path.is_file():
            result[relative] = ("file", path.read_bytes())
        elif path.is_dir():
            result[relative] = ("directory", "")
        else:
            result[relative] = ("special", stat.S_IFMT(os.lstat(path).st_mode))
    return result


def expect_failure(label: str, action: Callable[[], object]) -> None:
    try:
        action()
    except (ContractError, FileExistsError, OSError):
        return
    raise AssertionError(f"negative case unexpectedly passed: {label}")


def mutated_manifest(
    base: dict[str, object], mutation: Callable[[dict[str, object]], None]
) -> dict[str, object]:
    value = copy.deepcopy(base)
    mutation(value)
    return with_digest(value, "manifestDigest")


def mutated_journal(
    base: dict[str, object], mutation: Callable[[dict[str, object]], None]
) -> dict[str, object]:
    value = copy.deepcopy(base)
    mutation(value)
    return with_digest(value, "journalDigest")


def run_filesystem_scenarios(
    engine: FixtureTransaction,
    current: dict[str, object],
    next_manifest: dict[str, object],
) -> tuple[int, int]:
    positive = 0
    negative = 0

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-success-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        assert engine.publish(project, next_manifest, next_bytes()) == "published"
        assert engine.read_manifest(project) == next_manifest
        assert engine.path(project, PLUGIN_RELATIVE).read_bytes() == NEXT_PLUGIN_PATH.read_bytes()
        assert engine.path(project, THEME_RELATIVE).read_bytes() == NEXT_THEME_PATH.read_bytes()
        assert not lexists(engine.path(project, STALE_RELATIVE))
        assert engine.path(project, UNOWNED_RELATIVE).read_bytes() == b"hand-owned fixture\n"
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-first-") as raw:
        project = Path(raw)
        assert engine.publish(project, next_manifest, next_bytes()) == "published"
        assert engine.read_manifest(project) == next_manifest
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-first-crash-") as raw:
        project = Path(raw)
        try:
            engine.publish(
                project,
                next_manifest,
                next_bytes(),
                injection="crash-after-first-operation",
            )
        except SimulatedCrash:
            pass
        else:
            raise AssertionError("first-generation crash injection unexpectedly returned")
        assert engine.recover(project) == "rolled-back"
        assert snapshot(project) == {}
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-failure-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        before = snapshot(project)
        expect_failure(
            "caught mid-publication rollback",
            lambda: engine.publish(
                project,
                next_manifest,
                next_bytes(),
                injection="failure-after-first-operation",
            ),
        )
        assert snapshot(project) == before
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-crash-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        before = snapshot(project)
        try:
            engine.publish(
                project,
                next_manifest,
                next_bytes(),
                injection="crash-after-first-operation",
            )
        except SimulatedCrash:
            pass
        else:
            raise AssertionError("crash injection unexpectedly returned")
        assert engine.recover(project) == "rolled-back"
        assert snapshot(project) == before
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-finalize-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        try:
            engine.publish(
                project,
                next_manifest,
                next_bytes(),
                injection="crash-after-manifest",
            )
        except SimulatedCrash:
            pass
        else:
            raise AssertionError("post-manifest crash injection unexpectedly returned")
        assert engine.recover(project) == "finalized"
        assert engine.read_manifest(project) == next_manifest
        assert not lexists(engine.path(project, STALE_RELATIVE))
        positive += 1

    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-ownership-caught-finalize-"
    ) as raw:
        project = Path(raw)
        materialize_current(project, current)
        assert engine.publish(
            project,
            next_manifest,
            next_bytes(),
            injection="failure-after-manifest",
        ) == "published-recovered"
        assert engine.read_manifest(project) == next_manifest
        assert not lexists(engine.path(project, STALE_RELATIVE))
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-clean-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        empty = make_manifest([])
        assert engine.publish(project, empty, {}, mode="clean") == "published"
        assert engine.read_manifest(project) == empty
        assert not lexists(engine.path(project, PLUGIN_RELATIVE))
        assert not lexists(engine.path(project, STALE_RELATIVE))
        assert engine.path(project, UNOWNED_RELATIVE).read_bytes() == b"hand-owned fixture\n"
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-adopt-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        retained_entries = [
            item for item in current["files"] if item["path"] != PLUGIN_RELATIVE
        ]
        adopted = make_manifest(retained_entries)
        assert engine.publish(
            project,
            adopted,
            {},
            mode="adopt-generated",
            relinquish={PLUGIN_RELATIVE},
        ) == "published"
        assert engine.path(project, PLUGIN_RELATIVE).read_bytes() == INITIAL_PLUGIN_PATH.read_bytes()
        expect_failure(
            "adopted destination is unowned on next build",
            lambda: engine.publish(project, next_manifest, next_bytes()),
        )
        negative += 1
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-noop-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        before = snapshot(project)
        assert engine.publish(project, current, current_bytes()) == "no-op"
        assert snapshot(project) == before
        positive += 1

    with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-hardlink-") as raw:
        project = Path(raw)
        materialize_current(project, current)
        hand_owned = project / "hand-owned"
        hand_owned.mkdir()
        plugin_link = hand_owned / "acme-observatory.php"
        stale_link = hand_owned / "stale.php"
        os.link(engine.path(project, PLUGIN_RELATIVE), plugin_link)
        os.link(engine.path(project, STALE_RELATIVE), stale_link)
        assert engine.publish(project, next_manifest, next_bytes()) == "published"
        assert plugin_link.read_bytes() == INITIAL_PLUGIN_PATH.read_bytes()
        assert stale_link.read_bytes() == INITIAL_STALE_PATH.read_bytes()
        assert engine.path(project, PLUGIN_RELATIVE).read_bytes() == NEXT_PLUGIN_PATH.read_bytes()
        assert not lexists(engine.path(project, STALE_RELATIVE))
        positive += 1

    filesystem_cases: list[tuple[str, Callable[[Path], None], Callable[[Path], None]]] = []

    def unowned_setup(project: Path) -> None:
        materialize_current(project, current)
        write_project_file(project, THEME_RELATIVE, b"hand-owned theme\n")

    filesystem_cases.append(
        (
            "unowned destination",
            unowned_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def special_file_setup(project: Path) -> None:
        materialize_current(project, current)
        target = engine.path(project, PLUGIN_RELATIVE)
        target.unlink()
        os.mkfifo(target)

    filesystem_cases.append(
        (
            "owned special file",
            special_file_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def modified_setup(project: Path) -> None:
        materialize_current(project, current)
        engine.path(project, PLUGIN_RELATIVE).write_bytes(b"manual edit\n")

    filesystem_cases.append(
        (
            "modified owned file",
            modified_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def stale_modified_setup(project: Path) -> None:
        materialize_current(project, current)
        engine.path(project, STALE_RELATIVE).write_bytes(b"manual stale edit\n")

    filesystem_cases.append(
        (
            "modified stale file",
            stale_modified_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def missing_manifest_setup(project: Path) -> None:
        materialize_current(project, current)
        engine.path(project, MANIFEST_RELATIVE).unlink()

    filesystem_cases.append(
        (
            "missing manifest makes existing destination unowned",
            missing_manifest_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def malformed_manifest_setup(project: Path) -> None:
        materialize_current(project, current)
        engine.path(project, MANIFEST_RELATIVE).write_bytes(b"{not-json}\n")

    filesystem_cases.append(
        (
            "malformed manifest",
            malformed_manifest_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def legacy_manifest_setup(project: Path) -> None:
        materialize_current(project, current)
        engine.path(project, MANIFEST_RELATIVE).write_bytes(
            b'{"schema":"wordpress-hx.generated-files.v0"}\n'
        )

    filesystem_cases.append(
        (
            "legacy manifest without migration",
            legacy_manifest_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def parent_symlink_setup(project: Path) -> None:
        outside = project / "outside"
        outside.mkdir()
        build = project / "build"
        build.mkdir()
        os.symlink(outside, build / "site")

    filesystem_cases.append(
        (
            "parent symlink escape",
            parent_symlink_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def file_symlink_setup(project: Path) -> None:
        materialize_current(project, current)
        target = engine.path(project, PLUGIN_RELATIVE)
        target.unlink()
        os.symlink(project / "outside.php", target)

    filesystem_cases.append(
        (
            "owned file symlink",
            file_symlink_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def broken_symlink_setup(project: Path) -> None:
        materialize_current(project, current)
        target = engine.path(project, THEME_RELATIVE)
        os.symlink(project / "missing-target", target)

    filesystem_cases.append(
        (
            "broken destination symlink",
            broken_symlink_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def lock_setup(project: Path) -> None:
        materialize_current(project, current)
        write_project_file(project, LOCK_RELATIVE, b"other writer\n")

    filesystem_cases.append(
        (
            "concurrent writer lock",
            lock_setup,
            lambda project: engine.publish(project, next_manifest, next_bytes()),
        )
    )

    def orphan_lock_setup(project: Path) -> None:
        materialize_current(project, current)
        write_project_file(project, LOCK_RELATIVE, b"orphan\n")

    filesystem_cases.append(
        (
            "orphan lock cannot be guessed",
            orphan_lock_setup,
            lambda project: engine.recover(project),
        )
    )

    filesystem_cases.append(
        (
            "validator failure",
            lambda project: None,
            lambda project: engine.publish(
                project, next_manifest, next_bytes(), validator_passed=False
            ),
        )
    )
    incomplete_stage = current_bytes()
    del incomplete_stage[STALE_RELATIVE]
    filesystem_cases.append(
        (
            "incomplete unchanged build stage",
            lambda project: materialize_current(project, current),
            lambda project: engine.publish(project, current, incomplete_stage),
        )
    )
    bad_stage = next_bytes()
    bad_stage[PLUGIN_RELATIVE] = b"wrong staged bytes\n"
    filesystem_cases.append(
        (
            "staged hash mismatch",
            lambda project: materialize_current(project, current),
            lambda project: engine.publish(project, next_manifest, bad_stage),
        )
    )
    extra_stage = next_bytes()
    extra_stage["build/site/unlisted.php"] = b"undeclared\n"
    filesystem_cases.append(
        (
            "undeclared staged file",
            lambda project: materialize_current(project, current),
            lambda project: engine.publish(project, next_manifest, extra_stage),
        )
    )

    for label, setup, action in filesystem_cases:
        with tempfile.TemporaryDirectory(prefix="wordpresshx-ownership-negative-") as raw:
            project = Path(raw)
            setup(project)
            before = snapshot(project)
            expect_failure(label, lambda project=project, action=action: action(project))
            after = snapshot(project)
            if label not in {"concurrent writer lock", "orphan lock cannot be guessed"}:
                assert after == before, f"negative case mutated live tree: {label}"
            negative += 1

    return positive, negative


def main() -> int:
    manifest_schema = read_json_object(MANIFEST_SCHEMA_PATH, "manifest schema")
    journal_schema = read_json_object(JOURNAL_SCHEMA_PATH, "journal schema")
    require_closed_schema(manifest_schema)
    require_closed_schema(journal_schema)
    manifest_validator = ClosedSchemaValidator(manifest_schema)
    journal_validator = ClosedSchemaValidator(journal_schema)

    expected_current, expected_next = fixture_manifests()
    expected_journal = make_journal(expected_current, expected_next)
    current = read_canonical(CURRENT_FIXTURE_PATH, "current manifest fixture")
    next_manifest = read_canonical(NEXT_FIXTURE_PATH, "next manifest fixture")
    journal = read_canonical(JOURNAL_FIXTURE_PATH, "journal fixture")
    assert current == expected_current, "current ownership fixture is stale"
    assert next_manifest == expected_next, "next ownership fixture is stale"
    assert journal == expected_journal, "ownership journal fixture is stale"
    validate_manifest(current, manifest_validator)
    validate_manifest(next_manifest, manifest_validator)
    validate_journal(journal, journal_validator)
    validate_journal_plan(journal, current, next_manifest)

    negative_mutations: list[tuple[str, Callable[[], object]]] = []

    def bad_digest() -> dict[str, object]:
        value = copy.deepcopy(current)
        value["manifestDigest"] = "0" * 64
        return value

    negative_mutations.append(
        ("manifest digest", lambda: validate_manifest(bad_digest(), manifest_validator))
    )
    negative_mutations.extend(
        [
            (
                "traversal path",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": "build/site/../escape.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "absolute path",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": "/tmp/escape.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "backslash path",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": "build\\escape.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "reserved device path",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": "build/site/CON.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "file outside output root",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": "dist/escape.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "duplicate path",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"].append(
                            copy.deepcopy(value["files"][0])
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "case collision",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"].append(
                            {
                                **copy.deepcopy(value["files"][0]),
                                "path": str(value["files"][0]["path"]).upper(),
                            }
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "unsorted files",
                lambda: validate_manifest(
                    mutated_manifest(
                        current, lambda value: value["files"].reverse()
                    ),
                    manifest_validator,
                ),
            ),
            (
                "nested roots",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["outputRoots"].append(
                            {
                                "rootId": "site",
                                "path": "build/site",
                                "ownershipMode": (
                                    "exact-file-manifest-coexists-with-unowned"
                                ),
                            }
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "reserved transaction output",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"path": f"{TRANSACTION_ROOT_RELATIVE}/payload.php"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "reserved metadata ancestor",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["locations"].update(
                            {"manifestPath": "build"}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "unknown validator",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0].update(
                            {"validatorIds": ["missing.validator"]}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "generation digest mismatch",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["inputs"].update(
                            {"generationSha256": "1" * 64}
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "source span reversed",
                lambda: validate_manifest(
                    mutated_manifest(
                        current,
                        lambda value: value["files"][0]["sourceSpans"][0].update(
                            {
                                "start": {"offset": 111, "line": 4, "column": 51},
                                "end": {"offset": 61, "line": 4, "column": 1},
                            }
                        ),
                    ),
                    manifest_validator,
                ),
            ),
            (
                "unknown manifest field",
                lambda: validate_manifest(
                    mutated_manifest(
                        current, lambda value: value.update({"force": True})
                    ),
                    manifest_validator,
                ),
            ),
        ]
    )

    bad_journal_digest = copy.deepcopy(journal)
    bad_journal_digest["journalDigest"] = "0" * 64
    negative_mutations.append(
        (
            "journal digest",
            lambda: validate_journal(bad_journal_digest, journal_validator),
        )
    )
    negative_mutations.extend(
        [
            (
                "journal work-root mismatch",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value["locations"].update(
                            {"workRoot": f"{TRANSACTION_ROOT_RELATIVE}/other"}
                        ),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal action mismatch",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value["operations"][0].update(
                            {"action": "create"}
                        ),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal backup escape",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value["operations"][0].update(
                            {"backupPath": "build/elsewhere/file.php"}
                        ),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal duplicate operation",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value["operations"].append(
                            copy.deepcopy(value["operations"][0])
                        ),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal unknown phase",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value.update({"phase": "guess"}),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal adopt mode with generation operations",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value.update({"mode": "adopt-generated"}),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal clean mode with generation operations",
                lambda: validate_journal(
                    mutated_journal(
                        journal,
                        lambda value: value.update({"mode": "clean"}),
                    ),
                    journal_validator,
                ),
            ),
            (
                "journal operation root does not match manifests",
                lambda: validate_journal_plan(
                    mutated_journal(
                        journal,
                        lambda value: value["operations"][0].update(
                            {"rootId": "other"}
                        ),
                    ),
                    current,
                    next_manifest,
                ),
            ),
        ]
    )

    for label, action in negative_mutations:
        expect_failure(label, action)

    engine = FixtureTransaction(manifest_validator, journal_validator)
    positive_filesystem, negative_filesystem = run_filesystem_scenarios(
        engine, current, next_manifest
    )
    summary = {
        "currentFileCount": len(current["files"]),
        "journalOperationCount": len(journal["operations"]),
        "manifestDigest": current["manifestDigest"],
        "negativeFilesystemCount": negative_filesystem,
        "negativeMutationCount": len(negative_mutations),
        "nextFileCount": len(next_manifest["files"]),
        "nextManifestDigest": next_manifest["manifestDigest"],
        "positiveFilesystemCount": positive_filesystem,
        "recoveryModes": ["finalize-complete-next", "rollback-partial"],
    }
    print("OWNERSHIP_CONTRACT_SUMMARY=" + canonical(summary).decode("utf-8"))
    return 0


def refresh_fixtures() -> int:
    current, next_manifest = fixture_manifests()
    journal = make_journal(current, next_manifest)
    for path, value in (
        (CURRENT_FIXTURE_PATH, current),
        (NEXT_FIXTURE_PATH, next_manifest),
        (JOURNAL_FIXTURE_PATH, journal),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(canonical(value, newline=True))
    print("refreshed canonical ADR-007 ownership fixtures")
    return 0


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--write-fixtures"]:
            raise SystemExit(refresh_fixtures())
        if sys.argv[1:]:
            raise ContractError("usage: test-contract.py [--write-fixtures]")
        raise SystemExit(main())
    except (AssertionError, ContractError, KeyError, OSError, TypeError) as error:
        print(f"ownership contract failed: {error}", file=sys.stderr)
        raise SystemExit(1)
