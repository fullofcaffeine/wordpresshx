#!/usr/bin/env python3
"""Validate the ADR-019 unsafe-boundary policy and fail-closed scenarios."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROOT_RESOLVED = ROOT.resolve(strict=True)
POLICY_PATH = ROOT / "manifests" / "unsafe-boundary-policy.json"
SCHEMA_PATH = ROOT / "schemas" / "unsafe-boundary-waiver.schema.json"
SCENARIOS_PATH = ROOT / "fixtures" / "unsafe-boundary" / "scenarios.json"
WAIVER_PATH = (
    ROOT
    / "fixtures"
    / "unsafe-boundary"
    / "waivers"
    / "WPHX-UNSAFE-9999.json"
)
SHA256 = re.compile(r"^[0-9a-f]{64}$")
UTC_INSTANT = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
)
VERIFY_BEADS = "--verify-beads" in sys.argv[1:]


class ValidationError(ValueError):
    pass


def strict_json(path: Path) -> object:
    def pairs(values: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in values:
            if key in result:
                raise ValidationError(f"{path}: duplicate key {key}")
            result[key] = value
        return result

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=pairs,
            parse_constant=lambda value: (_ for _ in ()).throw(
                ValidationError(f"{path}: invalid constant {value}")
            ),
        )
    except json.JSONDecodeError as error:
        raise ValidationError(f"{path}: malformed JSON: {error}") from error


def object_value(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ValidationError(f"{label} must be an object")
    return value


def array_value(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise ValidationError(f"{label} must be an array")
    return value


def string_value(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ValidationError(f"{label} must be a non-empty string")
    return value


def bool_value(value: object, label: str) -> bool:
    if not isinstance(value, bool):
        raise ValidationError(f"{label} must be boolean")
    return value


def integer_value(value: object, label: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValidationError(f"{label} must be an integer")
    return value


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    actual = set(value)
    if actual != expected:
        raise ValidationError(
            f"{label} keys changed: missing={sorted(expected - actual)}, "
            f"extra={sorted(actual - expected)}"
        )


def unique_strings(value: object, label: str) -> list[str]:
    raw = array_value(value, label)
    strings = [string_value(entry, f"{label} entry") for entry in raw]
    if len(strings) != len(set(strings)):
        raise ValidationError(f"{label} contains duplicates")
    return strings


def parse_utc(value: object, label: str) -> datetime:
    text = string_value(value, label)
    if UTC_INSTANT.fullmatch(text) is None:
        raise ValidationError(f"{label} must be an exact UTC instant")
    parsed = datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ")
    return parsed.replace(tzinfo=timezone.utc)


def digest(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def repository_path(value: object, label: str) -> Path:
    text = string_value(value, label)
    if (
        text.startswith("/")
        or "\\" in text
        or any(part == ".." for part in text.split("/"))
    ):
        raise ValidationError(f"{label} escapes the repository")
    path = ROOT / text
    cursor = ROOT
    for part in Path(text).parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise ValidationError(f"{label} contains a symbolic link: {text}")
    try:
        resolved = path.resolve(strict=True)
        resolved.relative_to(ROOT_RESOLVED)
    except (FileNotFoundError, ValueError) as error:
        raise ValidationError(f"{label} escapes or is absent: {text}") from error
    if not resolved.is_file():
        raise ValidationError(f"{label} does not name a file: {text}")
    return resolved


def validate_schema(schema: dict[str, object], category_ids: list[str]) -> None:
    if digest(schema) != (
        "de07948d5b41a37a4f20d13cbdf769b238114f387427e16f740282aabb9d15eb"
    ):
        raise ValidationError(
            "waiver schema differs from the exhaustively reviewed closed contract"
        )
    exact_keys(
        schema,
        {
            "$schema",
            "$id",
            "title",
            "type",
            "additionalProperties",
            "required",
            "properties",
            "$defs",
        },
        "waiver schema",
    )
    if schema["type"] != "object" or schema["additionalProperties"] is not False:
        raise ValidationError("waiver schema root must be closed")
    required = unique_strings(schema["required"], "waiver schema required")
    properties = object_value(schema["properties"], "waiver schema properties")
    if set(required) != set(properties):
        raise ValidationError("waiver schema required/properties differ")
    expected = {
        "schemaVersion",
        "simulationOnly",
        "id",
        "boundaryId",
        "category",
        "reason",
        "owner",
        "review",
        "lifecycle",
        "createdAt",
        "expiresAt",
        "risk",
        "source",
        "scope",
        "evidence",
        "removal",
    }
    if set(required) != expected:
        raise ValidationError("waiver schema required fields changed")
    definitions = object_value(schema["$defs"], "waiver schema definitions")
    category = object_value(definitions.get("category"), "category definition")
    if unique_strings(category.get("enum"), "category enum") != category_ids:
        raise ValidationError("waiver schema category enum differs from policy")
    sha = object_value(definitions.get("sha256"), "sha256 definition")
    if sha.get("pattern") != "^[0-9a-f]{64}$":
        raise ValidationError("waiver schema SHA-256 pattern changed")
    repository_path = object_value(
        definitions.get("repositoryPath"), "repository path definition"
    )
    pattern = string_value(repository_path.get("pattern"), "repository path pattern")
    if "(?!/)" not in pattern or "\\.\\." not in pattern or "\\\\" not in pattern:
        raise ValidationError("repository path confinement weakened")
    for closed_object in (
        "review",
        "lifecycle",
        "risk",
        "source",
        "scope",
        "removal",
    ):
        field = object_value(properties.get(closed_object), closed_object)
        if field.get("additionalProperties") is not False:
            raise ValidationError(f"{closed_object} schema must be closed")


def validate_file_digest(value: object, label: str) -> tuple[str, str]:
    reference = object_value(value, label)
    exact_keys(reference, {"path", "sha256"}, label)
    path_text = string_value(reference["path"], f"{label} path")
    path = repository_path(path_text, f"{label} path")
    expected = string_value(reference["sha256"], f"{label} SHA-256")
    if (
        SHA256.fullmatch(expected) is None
        or hashlib.sha256(path.read_bytes()).hexdigest() != expected
    ):
        raise ValidationError(f"{label} digest drifted")
    return path_text, expected


def waiver_subject(waiver: dict[str, object]) -> dict[str, object]:
    subject = copy.deepcopy(waiver)
    subject.pop("review", None)
    subject.pop("lifecycle", None)
    return subject


def validate_review_receipt(
    waiver: dict[str, object],
    owner: str,
    subject_sha256: str,
    simulation_only: bool,
) -> tuple[datetime, str]:
    reference = object_value(waiver["review"], "waiver review reference")
    exact_keys(reference, {"receiptId", "path", "sha256"}, "waiver review reference")
    receipt_id = string_value(reference["receiptId"], "review receipt ID")
    path_text = string_value(reference["path"], "review receipt path")
    path = repository_path(path_text, "review receipt path")
    expected_hash = string_value(reference["sha256"], "review receipt SHA-256")
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
        raise ValidationError("review receipt digest drifted")
    receipt = object_value(strict_json(path), "review receipt")
    exact_keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "simulationOnly",
            "waiverId",
            "waiverSubjectSha256",
            "reviewer",
            "reviewedAt",
            "prompt",
            "inputs",
            "repositorySnapshotSha256",
            "source",
            "evidence",
            "findings",
            "decision",
            "independence",
            "limitations",
        },
        "review receipt",
    )
    if (
        receipt["schemaVersion"] != 1
        or receipt["receiptId"] != receipt_id
        or receipt["waiverId"] != waiver["id"]
        or receipt["waiverSubjectSha256"] != subject_sha256
        or receipt["decision"] != "approved"
        or receipt["simulationOnly"] is not simulation_only
    ):
        raise ValidationError("review receipt identity, subject, or decision is invalid")
    reviewer = object_value(receipt["reviewer"], "review receipt reviewer")
    exact_keys(
        reviewer, {"identity", "provider", "model", "role"}, "review receipt reviewer"
    )
    identity = string_value(reviewer["identity"], "reviewer identity")
    string_value(reviewer["provider"], "reviewer provider")
    string_value(reviewer["model"], "reviewer model")
    if reviewer["role"] != "independent-security-reviewer" or identity == owner:
        raise ValidationError("reviewer identity or role is not independent")
    independence = object_value(receipt["independence"], "review independence")
    if independence != {
        "reviewerDiffersFromOwner": True,
        "contextIsolated": True,
        "reviewerAuthoredWaiver": False,
    }:
        raise ValidationError("review independence declaration is invalid")
    validate_file_digest(receipt["prompt"], "review prompt")
    declared: list[dict[str, str]] = []
    for index, entry in enumerate(array_value(receipt["inputs"], "review inputs")):
        path_value, hash_value = validate_file_digest(
            entry, f"review input[{index}]"
        )
        declared.append({"path": path_value, "sha256": hash_value})
    source_path, source_hash = validate_file_digest(
        receipt["source"], "review source"
    )
    if (
        source_path != object_value(waiver["source"], "waiver source")["path"]
        or source_hash != object_value(waiver["source"], "waiver source")["sha256"]
    ):
        raise ValidationError("review source does not bind the waiver source")
    declared.append({"path": source_path, "sha256": source_hash})
    evidence_bindings: list[dict[str, str]] = []
    for index, entry in enumerate(array_value(receipt["evidence"], "review evidence")):
        path_value, hash_value = validate_file_digest(
            entry, f"review evidence[{index}]"
        )
        binding = {"path": path_value, "sha256": hash_value}
        evidence_bindings.append(binding)
        declared.append(binding)
    waiver_evidence = [
        object_value(entry, "waiver evidence")
        for entry in array_value(waiver["evidence"], "waiver evidence")
    ]
    if evidence_bindings != waiver_evidence:
        raise ValidationError("review evidence does not exactly bind waiver evidence")
    if receipt["repositorySnapshotSha256"] != digest(declared):
        raise ValidationError("review repository snapshot digest drifted")
    for index, raw_finding in enumerate(
        array_value(receipt["findings"], "review findings")
    ):
        finding = object_value(raw_finding, f"review finding[{index}]")
        exact_keys(
            finding,
            {"id", "severity", "summary", "disposition"},
            f"review finding[{index}]",
        )
        string_value(finding["id"], "review finding ID")
        if finding["severity"] in {"high", "critical"}:
            raise ValidationError("approved review retains a high or critical finding")
        string_value(finding["summary"], "review finding summary")
        if finding["disposition"] not in {"accepted-risk", "resolved"}:
            raise ValidationError("review finding disposition is invalid")
    if not unique_strings(receipt["limitations"], "review limitations"):
        raise ValidationError("review limitations are required")
    return parse_utc(receipt["reviewedAt"], "review reviewedAt"), expected_hash


def validate_bead_status(
    value: object,
    expected_bead: str,
    evaluation_at: datetime,
    verify_live: bool,
) -> None:
    path_text, _ = validate_file_digest(value, "removal Bead status")
    receipt = object_value(strict_json(repository_path(path_text, "Bead status path")), "Bead status")
    exact_keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "source",
            "observedAt",
            "issue",
            "projectionSha256",
        },
        "Bead status",
    )
    issue = object_value(receipt["issue"], "Bead status issue")
    exact_keys(issue, {"id", "status", "updatedAt"}, "Bead status issue")
    if (
        receipt["schemaVersion"] != 1
        or receipt["source"] != "bd-show-after-dolt-pull"
        or issue["id"] != expected_bead
        or issue["status"] not in {"open", "in_progress"}
    ):
        raise ValidationError("removal Bead is absent, closed, or not authoritative")
    observed_at = parse_utc(receipt["observedAt"], "Bead status observedAt")
    updated_at = parse_utc(issue["updatedAt"], "Bead status updatedAt")
    if not updated_at <= observed_at <= evaluation_at:
        raise ValidationError("Bead status receipt timestamps are invalid")
    projection = {
        "id": issue["id"],
        "status": issue["status"],
        "updatedAt": issue["updatedAt"],
    }
    if receipt["projectionSha256"] != digest(projection):
        raise ValidationError("Bead status projection digest drifted")
    if VERIFY_BEADS and verify_live:
        binary = os.environ.get("WORDPRESSHX_BD_BIN", "bd")
        pull = subprocess.run(
            [binary, "dolt", "pull"],
            cwd=ROOT,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if pull.returncode != 0:
            raise ValidationError(
                "authoritative Beads Dolt pull failed:\n" + pull.stdout
            )
        completed = subprocess.run(
            [binary, "show", expected_bead, "--json"],
            cwd=ROOT,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        live_values = json.loads(completed.stdout)
        if not isinstance(live_values, list) or len(live_values) != 1:
            raise ValidationError("authoritative Beads query returned no unique issue")
        live = object_value(live_values[0], "live Bead")
        live_projection = {
            "id": live.get("id"),
            "status": live.get("status"),
            "updatedAt": live.get("updated_at"),
        }
        if live_projection != projection:
            raise ValidationError("committed Bead status differs from live Dolt authority")


def validate_lifecycle(
    waiver: dict[str, object],
    subject_sha256: str,
    review_sha256: str,
    created_at: datetime,
    reviewed_at: datetime,
    evaluation_at: datetime,
    expires_at: datetime,
    simulation_only: bool,
) -> None:
    reference = object_value(waiver["lifecycle"], "waiver lifecycle reference")
    exact_keys(
        reference,
        {"ledgerId", "path", "sha256", "currentRecordId"},
        "waiver lifecycle reference",
    )
    path_text = string_value(reference["path"], "lifecycle path")
    path = repository_path(path_text, "lifecycle path")
    if hashlib.sha256(path.read_bytes()).hexdigest() != reference["sha256"]:
        raise ValidationError("lifecycle ledger digest drifted")
    ledger = object_value(strict_json(path), "lifecycle ledger")
    exact_keys(
        ledger,
        {
            "schemaVersion",
            "ledgerId",
            "waiverId",
            "simulationOnly",
            "currentRecordId",
            "records",
        },
        "lifecycle ledger",
    )
    if (
        ledger["schemaVersion"] != 1
        or ledger["ledgerId"] != reference["ledgerId"]
        or ledger["waiverId"] != waiver["id"]
        or ledger["currentRecordId"] != reference["currentRecordId"]
        or ledger["simulationOnly"] is not simulation_only
    ):
        raise ValidationError("lifecycle identity differs from waiver reference")
    records = array_value(ledger["records"], "lifecycle records")
    if not records:
        raise ValidationError("lifecycle ledger is empty")
    previous_id: str | None = None
    previous_hash: str | None = None
    ids: set[str] = set()
    current: dict[str, object] | None = None
    for index, raw_record in enumerate(records):
        record = object_value(raw_record, f"lifecycle record[{index}]")
        exact_keys(
            record,
            {
                "id",
                "sequence",
                "recordedAt",
                "state",
                "waiverSubjectSha256",
                "reviewReceiptSha256",
                "previousRecordId",
                "previousRecordSha256",
                "renewalOf",
                "supersededBy",
                "revocation",
                "removalStatus",
            },
            f"lifecycle record[{index}]",
        )
        record_id = string_value(record["id"], "lifecycle record ID")
        if (
            record_id in ids
            or integer_value(record["sequence"], "lifecycle sequence") != index + 1
            or record["previousRecordId"] != previous_id
            or record["previousRecordSha256"] != previous_hash
        ):
            raise ValidationError("lifecycle ancestry is not additive and contiguous")
        ids.add(record_id)
        recorded_at = parse_utc(record["recordedAt"], "lifecycle recordedAt")
        if not created_at <= reviewed_at <= recorded_at <= evaluation_at < expires_at:
            raise ValidationError("lifecycle, review, evaluation, or expiry order is invalid")
        if (
            record["waiverSubjectSha256"] != subject_sha256
            or record["reviewReceiptSha256"] != review_sha256
        ):
            raise ValidationError("lifecycle record does not bind waiver and review")
        state = string_value(record["state"], "lifecycle state")
        revocation = object_value(record["revocation"], "lifecycle revocation")
        exact_keys(revocation, {"at", "reason"}, "lifecycle revocation")
        if state == "active":
            if (
                record["supersededBy"] is not None
                or revocation != {"at": None, "reason": None}
            ):
                raise ValidationError("active lifecycle has revocation or successor")
        elif state == "revoked":
            if (
                revocation["at"] is None
                or revocation["reason"] is None
                or record["supersededBy"] is not None
            ):
                raise ValidationError("revoked lifecycle lacks revocation authority")
        elif state == "superseded":
            successor = record["supersededBy"]
            if (
                not isinstance(successor, str)
                or successor == waiver["id"]
                or revocation != {"at": None, "reason": None}
            ):
                raise ValidationError("superseded lifecycle lacks a new waiver ID")
        else:
            raise ValidationError("unknown lifecycle state")
        if record["renewalOf"] is not None:
            renewal = object_value(record["renewalOf"], "renewal ancestor")
            exact_keys(
                renewal,
                {"waiverId", "lifecyclePath", "lifecycleSha256"},
                "renewal ancestor",
            )
            prior_id = string_value(renewal["waiverId"], "renewal ancestor ID")
            prior_path = repository_path(
                renewal["lifecyclePath"], "renewal ancestor lifecycle path"
            )
            if (
                prior_id == waiver["id"]
                or index != 0
                or hashlib.sha256(prior_path.read_bytes()).hexdigest()
                != renewal["lifecycleSha256"]
            ):
                raise ValidationError("renewal must use a new waiver and fresh ledger")
            prior = object_value(strict_json(prior_path), "renewal ancestor ledger")
            prior_records = array_value(prior.get("records"), "renewal records")
            if (
                prior.get("waiverId") != prior_id
                or not prior_records
                or prior.get("currentRecordId")
                != object_value(prior_records[-1], "renewal current record").get("id")
                or object_value(prior_records[-1], "renewal current record").get(
                    "state"
                )
                != "superseded"
                or object_value(prior_records[-1], "renewal current record").get(
                    "supersededBy"
                )
                != waiver["id"]
            ):
                raise ValidationError("renewal ancestor does not authorize successor")
        validate_bead_status(
            record["removalStatus"],
            string_value(
                object_value(waiver["removal"], "waiver removal")["bead"],
                "removal Bead",
            ),
            evaluation_at,
            record_id == ledger["currentRecordId"],
        )
        previous_id = record_id
        previous_hash = digest(record)
        if record_id == ledger["currentRecordId"]:
            current = record
    if current is None or current is not records[-1] or current["state"] != "active":
        raise ValidationError("current lifecycle authority is not the final active record")


def validate_waiver_instance(
    waiver: dict[str, object],
    categories: dict[str, dict[str, object]],
    evaluation_at: datetime,
) -> None:
    exact_keys(
        waiver,
        {
            "schemaVersion",
            "simulationOnly",
            "id",
            "boundaryId",
            "category",
            "reason",
            "owner",
            "review",
            "lifecycle",
            "createdAt",
            "expiresAt",
            "risk",
            "source",
            "scope",
            "evidence",
            "removal",
        },
        "waiver",
    )
    if waiver["schemaVersion"] != 1:
        raise ValidationError("waiver schema version changed")
    simulation_only = bool_value(waiver["simulationOnly"], "waiver simulationOnly")
    waiver_id = string_value(waiver["id"], "waiver id")
    if re.fullmatch(r"WPHX-UNSAFE-[0-9]{4}", waiver_id) is None:
        raise ValidationError("waiver ID is invalid")
    boundary_id = string_value(waiver["boundaryId"], "boundary ID")
    if re.fullmatch(r"UB-[A-Z0-9][A-Z0-9-]*", boundary_id) is None:
        raise ValidationError("boundary ID is invalid")
    category_id = string_value(waiver["category"], "waiver category")
    category = categories.get(category_id)
    if category is None or category["waiverRequired"] is not True:
        raise ValidationError("waiver category is unknown or does not use waivers")
    string_value(waiver["reason"], "waiver reason")
    owner = string_value(waiver["owner"], "waiver owner")
    subject_sha256 = digest(waiver_subject(waiver))
    reviewed_at, review_sha256 = validate_review_receipt(
        waiver, owner, subject_sha256, simulation_only
    )
    created_at = parse_utc(waiver["createdAt"], "waiver createdAt")
    expires_at = parse_utc(waiver["expiresAt"], "waiver expiresAt")
    if not (
        created_at <= reviewed_at <= evaluation_at < expires_at
        and expires_at - created_at <= timedelta(days=90)
    ):
        raise ValidationError("waiver timestamps are invalid or non-current")

    risk = object_value(waiver["risk"], "waiver risk")
    exact_keys(risk, {"severity", "threat", "mitigation"}, "waiver risk")
    if risk["severity"] not in {"low", "medium"}:
        raise ValidationError("high or critical risk cannot be waived")
    string_value(risk["threat"], "waiver threat")
    string_value(risk["mitigation"], "waiver mitigation")

    source = object_value(waiver["source"], "waiver source")
    exact_keys(
        source, {"path", "sha256", "startLine", "endLine"}, "waiver source"
    )
    source_path = repository_path(source["path"], "waiver source path")
    source_hash = string_value(source["sha256"], "waiver source SHA-256")
    if (
        SHA256.fullmatch(source_hash) is None
        or hashlib.sha256(source_path.read_bytes()).hexdigest() != source_hash
    ):
        raise ValidationError("waiver source digest drifted")
    start_line = integer_value(source["startLine"], "waiver source startLine")
    end_line = integer_value(source["endLine"], "waiver source endLine")
    source_line_count = len(source_path.read_text(encoding="utf-8").splitlines())
    if not (1 <= start_line <= end_line <= source_line_count):
        raise ValidationError("waiver source line range is invalid")

    scope = object_value(waiver["scope"], "waiver scope")
    exact_keys(
        scope, {"package", "layer", "profiles", "targets"}, "waiver scope"
    )
    string_value(scope["package"], "waiver package")
    layer = string_value(scope["layer"], "waiver layer")
    if layer not in set(
        unique_strings(category["allowedScopes"], "category allowed scopes")
    ):
        raise ValidationError("waiver layer is outside the category scope")
    for field in ("profiles", "targets"):
        values = unique_strings(scope[field], f"waiver {field}")
        if values != sorted(values) or not values:
            raise ValidationError(f"waiver {field} must be sorted and non-empty")

    evidence_values = array_value(waiver["evidence"], "waiver evidence")
    if not evidence_values:
        raise ValidationError("waiver evidence is empty")
    evidence_paths: list[str] = []
    for index, raw_evidence in enumerate(evidence_values):
        evidence = object_value(raw_evidence, f"waiver evidence[{index}]")
        exact_keys(evidence, {"path", "sha256"}, f"waiver evidence[{index}]")
        evidence_path_text = string_value(
            evidence["path"], f"waiver evidence[{index}] path"
        )
        evidence_path = repository_path(
            evidence_path_text, f"waiver evidence[{index}] path"
        )
        evidence_hash = string_value(
            evidence["sha256"], f"waiver evidence[{index}] SHA-256"
        )
        if (
            SHA256.fullmatch(evidence_hash) is None
            or hashlib.sha256(evidence_path.read_bytes()).hexdigest()
            != evidence_hash
        ):
            raise ValidationError(f"waiver evidence[{index}] digest drifted")
        evidence_paths.append(evidence_path_text)
    if len(evidence_paths) != len(set(evidence_paths)):
        raise ValidationError("waiver evidence paths contain duplicates")

    removal = object_value(waiver["removal"], "waiver removal")
    exact_keys(
        removal, {"bead", "deadline", "successCondition"}, "waiver removal"
    )
    bead = string_value(removal["bead"], "waiver removal bead")
    if re.fullmatch(r"wordpresshx-[a-z0-9.-]+", bead) is None:
        raise ValidationError("waiver removal Bead ID is invalid")
    removal_deadline = parse_utc(
        removal["deadline"], "waiver removal deadline"
    )
    if removal_deadline > expires_at:
        raise ValidationError("waiver removal deadline exceeds expiry")
    if removal_deadline < max(created_at, reviewed_at, evaluation_at):
        raise ValidationError("waiver removal deadline has already passed")
    string_value(removal["successCondition"], "waiver removal success condition")
    validate_lifecycle(
        waiver,
        subject_sha256,
        review_sha256,
        created_at,
        reviewed_at,
        evaluation_at,
        expires_at,
        simulation_only,
    )


def validate_policy(policy: dict[str, object]) -> dict[str, dict[str, object]]:
    exact_keys(
        policy,
        {
            "schemaVersion",
            "decisionId",
            "status",
            "policyId",
            "authority",
            "categories",
            "prohibitedScopes",
            "waiverContract",
            "lifecycle",
            "inventoryContract",
            "reviewTriggers",
            "gatePolicy",
            "diagnostics",
            "claims",
        },
        "unsafe-boundary policy",
    )
    if policy["schemaVersion"] != 1 or policy["decisionId"] != "ADR-019":
        raise ValidationError("unsafe-boundary policy identity changed")
    if policy["status"] not in {
        "proposed-pending-independent-review",
        "accepted-after-independent-review",
    }:
        raise ValidationError("unsafe-boundary policy status is invalid")
    if policy["policyId"] != "wordpress-hx-unsafe-boundary-v1":
        raise ValidationError("unsafe-boundary policy ID changed")

    authority = object_value(policy["authority"], "authority")
    exact_keys(
        authority,
        {
            "defaultDisposition",
            "inventoryModel",
            "waiverEffect",
            "waiverMayOverridePublicApiProhibition",
            "waiverMayOverrideApplicationOrExampleHaxeStrictness",
            "waiverMayOverrideCriticalOrHighVulnerabilityStop",
            "waiverMayAuthorizeUnknownBoundary",
            "omittedDetectionAllowed",
            "clockAuthority",
            "sourceAndArtifactInventoriesSeparate",
            "generatedAndFinalArtifactScanRequired",
        },
        "authority",
    )
    expected_authority = {
        "defaultDisposition": "blocked",
        "inventoryModel": (
            "detector-declarations-reconciled-to-one-closed-inventory"
        ),
        "waiverEffect": (
            "temporary-visible-exception-not-safety-support-or-type-authority"
        ),
        "waiverMayOverridePublicApiProhibition": False,
        "waiverMayOverrideApplicationOrExampleHaxeStrictness": False,
        "waiverMayOverrideCriticalOrHighVulnerabilityStop": False,
        "waiverMayAuthorizeUnknownBoundary": False,
        "omittedDetectionAllowed": False,
        "clockAuthority": "explicit-utc-instant-recorded-by-gate",
        "sourceAndArtifactInventoriesSeparate": True,
        "generatedAndFinalArtifactScanRequired": True,
    }
    if authority != expected_authority:
        raise ValidationError("unsafe-boundary authority changed")

    categories = array_value(policy["categories"], "categories")
    category_ids: list[str] = []
    by_category: dict[str, dict[str, object]] = {}
    category_keys = {
        "id",
        "detectors",
        "allowedScopes",
        "waiverRequired",
        "decoderEvidenceRequired",
        "stableWithCurrentWaiverAllowed",
        "independentSecurityReviewRequired",
    }
    for index, raw_category in enumerate(categories):
        category = object_value(raw_category, f"category[{index}]")
        exact_keys(category, category_keys, f"category[{index}]")
        category_id = string_value(category["id"], f"category[{index}] id")
        detectors = unique_strings(
            category["detectors"], f"category {category_id} detectors"
        )
        scopes = unique_strings(
            category["allowedScopes"], f"category {category_id} scopes"
        )
        if detectors != sorted(detectors) or scopes != sorted(scopes):
            raise ValidationError(f"category {category_id} lists must be sorted")
        for field in (
            "waiverRequired",
            "decoderEvidenceRequired",
            "stableWithCurrentWaiverAllowed",
            "independentSecurityReviewRequired",
        ):
            bool_value(category[field], f"category {category_id} {field}")
        category_ids.append(category_id)
        by_category[category_id] = category
    expected_categories = [
        "generated-raw-target",
        "haxe-weak-type",
        "javascript-raw-segment",
        "php-raw-segment",
        "private-upstream-api",
        "profile-unsafe-entry",
        "typescript-any",
        "typescript-unknown",
        "unchecked-external-contract",
    ]
    if category_ids != expected_categories or len(by_category) != len(category_ids):
        raise ValidationError("category inventory changed or is not sorted/unique")
    if by_category["typescript-unknown"]["waiverRequired"] is not False:
        raise ValidationError("decoded TypeScript unknown boundary requires a waiver")
    if by_category["typescript-unknown"]["decoderEvidenceRequired"] is not True:
        raise ValidationError("TypeScript unknown lost decoder evidence")
    for category_id in (
        "private-upstream-api",
        "profile-unsafe-entry",
        "unchecked-external-contract",
    ):
        if by_category[category_id]["stableWithCurrentWaiverAllowed"] is not False:
            raise ValidationError(f"{category_id} became stable-release eligible")

    prohibited = unique_strings(policy["prohibitedScopes"], "prohibited scopes")
    if prohibited != [
        "application-source",
        "example-recommended-authoring",
        "public-api",
        "public-type-signature",
        "routine-hxx-expression",
    ]:
        raise ValidationError("prohibited scopes changed")

    waiver = object_value(policy["waiverContract"], "waiver contract")
    exact_keys(
        waiver,
        {
            "schema",
            "reviewReceiptSchema",
            "lifecycleSchema",
            "beadStatusSchema",
            "idPattern",
            "boundaryIdPattern",
            "sourceBinding",
            "requiredEvidenceCountMinimum",
            "ownerKind",
            "reviewerMustDifferFromOwner",
            "independentOracleReviewerAllowed",
            "reviewBinding",
            "simulationReceiptMayAuthorizeProduction",
            "selfApprovalAllowed",
            "maximumInitialLifetimeDays",
            "renewal",
            "vagueOrReleaseRelativeExpiryAllowed",
            "removalBeadRequired",
            "removalStatusAuthority",
            "removalDeadlineMayExceedExpiry",
        },
        "waiver contract",
    )
    if waiver != {
        "schema": "schemas/unsafe-boundary-waiver.schema.json",
        "reviewReceiptSchema": "schemas/unsafe-boundary-review.schema.json",
        "lifecycleSchema": "schemas/unsafe-boundary-lifecycle.schema.json",
        "beadStatusSchema": "schemas/unsafe-boundary-bead-status.schema.json",
        "idPattern": "^WPHX-UNSAFE-[0-9]{4}$",
        "boundaryIdPattern": "^UB-[A-Z0-9][A-Z0-9-]*$",
        "sourceBinding": (
            "repository-relative-path-full-file-sha256-and-line-range"
        ),
        "requiredEvidenceCountMinimum": 1,
        "ownerKind": "named-accountable-human-or-maintainer-role",
        "reviewerMustDifferFromOwner": True,
        "independentOracleReviewerAllowed": True,
        "reviewBinding": (
            "content-addressed-prompt-input-source-evidence-findings-decision-and-independence"
        ),
        "simulationReceiptMayAuthorizeProduction": False,
        "selfApprovalAllowed": False,
        "maximumInitialLifetimeDays": 90,
        "renewal": "new-waiver-id-review-and-source-binding-required",
        "vagueOrReleaseRelativeExpiryAllowed": False,
        "removalBeadRequired": True,
        "removalStatusAuthority": (
            "bd-show-after-dolt-pull-content-addressed-projection"
        ),
        "removalDeadlineMayExceedExpiry": False,
    }:
        raise ValidationError("waiver contract changed")

    lifecycle = object_value(policy["lifecycle"], "lifecycle")
    exact_keys(
        lifecycle,
        {
            "states",
            "activeConditions",
            "expiredWaiverEffect",
            "revokedWaiverEffect",
            "sourceDriftEffect",
            "scopeDriftEffect",
            "renewalCarriesPriorApproval",
            "historyMutable",
        },
        "lifecycle",
    )
    if unique_strings(lifecycle["states"], "lifecycle states") != [
        "active",
        "expired",
        "revoked",
        "superseded",
    ]:
        raise ValidationError("waiver lifecycle states changed")
    active_conditions = set(
        unique_strings(lifecycle["activeConditions"], "active conditions")
    )
    if active_conditions != {
        "approved-review",
        "current-additive-lifecycle-record",
        "evaluation-before-expiry",
        "source-binding-matches",
        "scope-matches",
        "category-matches",
        "removal-bead-open-or-in-progress",
        "authoritative-removal-bead-receipt-matches-live-dolt",
        "risk-below-high",
        "all-required-evidence-matches",
    }:
        raise ValidationError("active waiver conditions changed")
    for effect in (
        "expiredWaiverEffect",
        "revokedWaiverEffect",
        "sourceDriftEffect",
        "scopeDriftEffect",
    ):
        if lifecycle[effect] != "all-builds-fail":
            raise ValidationError(f"{effect} must fail all builds")
    if (
        lifecycle["renewalCarriesPriorApproval"] is not False
        or lifecycle["historyMutable"] is not False
    ):
        raise ValidationError("waiver renewal/history became mutable")

    inventory = object_value(policy["inventoryContract"], "inventory contract")
    exact_keys(
        inventory,
        {
            "schemaVersion",
            "closedFields",
            "requiredGrouping",
            "requiredRecordFields",
            "detectedWithoutRecord",
            "recordWithoutDetection",
            "duplicateBoundaryId",
            "duplicateSourceLocation",
            "unknownCategoryOrDetector",
            "typedUnknownDisposition",
            "falsePositiveDisposition",
            "sourceInventoryRequired",
            "generatedInventoryRequired",
            "finalArtifactInventoryRequired",
            "sourceToGeneratedBoundaryIdsRequired",
            "finalArtifactManifestCarriesWaiverIdsAndDigests",
        },
        "inventory contract",
    )
    if inventory["schemaVersion"] != 1 or inventory["closedFields"] is not True:
        raise ValidationError("inventory must remain closed")
    blocking_inventory = {
        "detectedWithoutRecord": "blocked",
        "recordWithoutDetection": "blocked-stale-record",
        "duplicateBoundaryId": "blocked",
        "duplicateSourceLocation": "blocked",
        "unknownCategoryOrDetector": "blocked",
    }
    for field, expected in blocking_inventory.items():
        if inventory[field] != expected:
            raise ValidationError(f"inventory {field} fail-closed rule changed")
    for field in (
        "sourceInventoryRequired",
        "generatedInventoryRequired",
        "finalArtifactInventoryRequired",
        "sourceToGeneratedBoundaryIdsRequired",
        "finalArtifactManifestCarriesWaiverIdsAndDigests",
    ):
        if inventory[field] is not True:
            raise ValidationError(f"inventory {field} must remain required")

    triggers = unique_strings(policy["reviewTriggers"], "review triggers")
    if len(triggers) != 10:
        raise ValidationError("review trigger inventory changed")
    required_trigger_fragments = (
        "boundary-added",
        "compiler-adds",
        "generated-inventory",
        "profile-or-provider",
        "public-api",
        "security-sensitive",
        "digest-drift",
        "fourteen-days",
        "renewal",
    )
    if not all(any(fragment in trigger for trigger in triggers) for fragment in required_trigger_fragments):
        raise ValidationError("required review trigger disappeared")

    gates = object_value(policy["gatePolicy"], "gate policy")
    exact_keys(gates, {"development", "package", "stableRelease"}, "gate policy")
    expected_gate_sizes = {"development": 4, "package": 4, "stableRelease": 7}
    for gate, expected_size in expected_gate_sizes.items():
        rules = unique_strings(gates[gate], f"{gate} gate")
        if len(rules) != expected_size:
            raise ValidationError(f"{gate} gate rule inventory changed")

    diagnostics = object_value(policy["diagnostics"], "diagnostics")
    exact_keys(
        diagnostics,
        {
            "missingInventory",
            "staleInventory",
            "missingWaiver",
            "expiredWaiver",
            "sourceDrift",
            "scopeMismatch",
            "prohibitedScope",
            "selfApproval",
            "invalidExpiry",
            "missingArtifactMapping",
            "riskReleaseStop",
            "reviewRequired",
        },
        "diagnostics",
    )
    diagnostic_values = [
        string_value(value, f"diagnostic {key}")
        for key, value in diagnostics.items()
    ]
    if (
        len(set(diagnostic_values)) != len(diagnostic_values)
        or diagnostic_values != [f"WPX19{index:02d}" for index in range(1, 13)]
    ):
        raise ValidationError("diagnostic codes changed or collide")

    claims = object_value(policy["claims"], "claims")
    if claims != {
        "architectureDecision": "proposed-pending-independent-review",
        "prototypePolicyValidator": "implemented",
        "productionSourceScanner": "not-tested",
        "productionGeneratedScanner": "not-tested",
        "productionArtifactInventory": "not-tested",
        "productionWaiverApi": "withheld",
        "stableReleaseAuthorized": False,
        "productionSupport": "not-tested",
    }:
        raise ValidationError("unsafe-boundary claims changed")
    return by_category


def scenario_decision(
    scenario: dict[str, object],
    categories: dict[str, dict[str, object]],
    prohibited_scopes: set[str],
    evaluation_at: datetime,
    maximum_lifetime_days: int,
) -> tuple[str, str | None]:
    category_id = string_value(scenario["category"], "scenario category")
    category = categories.get(category_id)
    if category is None:
        return ("blocked", "WPX1901")
    detected = bool_value(scenario["detected"], "scenario detected")
    inventoried = bool_value(scenario["inventoried"], "scenario inventoried")
    if detected and not inventoried:
        return ("blocked", "WPX1901")
    if inventoried and not detected:
        return ("blocked", "WPX1902")
    if not detected:
        return ("no-boundary", None)

    scope = string_value(scenario["scope"], "scenario scope")
    if scope in prohibited_scopes:
        return ("blocked", "WPX1907")
    allowed_scopes = set(
        unique_strings(category["allowedScopes"], f"{category_id} allowed scopes")
    )
    if scope not in allowed_scopes:
        return ("blocked", "WPX1906")
    if bool_value(scenario["scopeMatches"], "scenario scopeMatches") is not True:
        return ("blocked", "WPX1906")

    waiver_required = bool_value(
        scenario["waiverRequired"], "scenario waiverRequired"
    )
    if waiver_required is not category["waiverRequired"]:
        raise ValidationError("scenario waiver requirement differs from policy")
    waiver_present = bool_value(scenario["waiverPresent"], "scenario waiverPresent")
    if waiver_required and not waiver_present:
        return ("blocked", "WPX1903")
    if waiver_present:
        owner = string_value(scenario["owner"], "scenario owner")
        reviewer = string_value(scenario["reviewer"], "scenario reviewer")
        if owner == reviewer:
            return ("blocked", "WPX1908")
        created = parse_utc(scenario["createdAt"], "scenario createdAt")
        expires = parse_utc(scenario["expiresAt"], "scenario expiresAt")
        removal = parse_utc(
            scenario["removalDeadline"], "scenario removalDeadline"
        )
        if (
            expires <= created
            or expires - created > timedelta(days=maximum_lifetime_days)
            or removal > expires
        ):
            return ("blocked", "WPX1909")
        status = string_value(scenario["waiverStatus"], "scenario waiverStatus")
        if status != "active" or evaluation_at >= expires:
            return ("blocked", "WPX1904")
        if not bool_value(scenario["sourceMatches"], "scenario sourceMatches"):
            return ("blocked", "WPX1905")

    if (
        category["decoderEvidenceRequired"] is True
        and not bool_value(scenario["decoderEvidence"], "scenario decoderEvidence")
    ):
        return ("blocked", "WPX1912")
    if string_value(scenario["risk"], "scenario risk") in {"high", "critical"}:
        return ("blocked", "WPX1911")

    stable = bool_value(scenario["stableRelease"], "scenario stableRelease")
    if stable and not bool_value(
        scenario["generatedMapping"], "scenario generatedMapping"
    ):
        return ("blocked", "WPX1910")
    if stable and category["stableWithCurrentWaiverAllowed"] is not True:
        return ("blocked", "WPX1911")
    if (
        stable
        and category["independentSecurityReviewRequired"] is True
        and not bool_value(
            scenario["independentReview"], "scenario independentReview"
        )
    ):
        return ("blocked", "WPX1912")
    if waiver_required:
        return (
            "permit-stable-bounded-waiver"
            if stable
            else "permit-development-bounded-waiver",
            None,
        )
    return (
        "permit-stable-inventoried-decoded-boundary"
        if stable
        else "permit-development-inventoried-decoded-boundary",
        None,
    )


def validate_scenarios(
    document: dict[str, object],
    policy: dict[str, object],
    categories: dict[str, dict[str, object]],
) -> list[dict[str, object]]:
    exact_keys(
        document,
        {
            "schemaVersion",
            "scenarioSet",
            "simulationOnly",
            "evaluationAt",
            "scenarios",
        },
        "scenario document",
    )
    if document["schemaVersion"] != 1:
        raise ValidationError("scenario schema version changed")
    if document["scenarioSet"] != "adr019-unsafe-boundary-governance-v1":
        raise ValidationError("scenario set identity changed")
    if document["simulationOnly"] is not True:
        raise ValidationError("scenario document must remain simulation-only")
    evaluation_at = parse_utc(document["evaluationAt"], "scenario evaluationAt")
    scenarios = array_value(document["scenarios"], "scenarios")
    expected_keys = {
        "id",
        "category",
        "scope",
        "detected",
        "inventoried",
        "waiverRequired",
        "waiverPresent",
        "waiverStatus",
        "owner",
        "reviewer",
        "createdAt",
        "expiresAt",
        "removalDeadline",
        "sourceMatches",
        "scopeMatches",
        "decoderEvidence",
        "generatedMapping",
        "risk",
        "stableRelease",
        "independentReview",
        "expectedDecision",
        "diagnostic",
    }
    ids: list[str] = []
    results: list[dict[str, object]] = []
    prohibited = set(unique_strings(policy["prohibitedScopes"], "prohibited scopes"))
    waiver = object_value(policy["waiverContract"], "waiver contract")
    maximum_lifetime = integer_value(
        waiver["maximumInitialLifetimeDays"], "maximum waiver lifetime"
    )
    for index, raw_scenario in enumerate(scenarios):
        scenario = object_value(raw_scenario, f"scenario[{index}]")
        exact_keys(scenario, expected_keys, f"scenario[{index}]")
        scenario_id = string_value(scenario["id"], f"scenario[{index}] id")
        ids.append(scenario_id)
        decision, diagnostic = scenario_decision(
            scenario,
            categories,
            prohibited,
            evaluation_at,
            maximum_lifetime,
        )
        if decision != scenario["expectedDecision"] or diagnostic != scenario["diagnostic"]:
            raise ValidationError(
                f"scenario {scenario_id} expected "
                f"{scenario['expectedDecision']}/{scenario['diagnostic']}, "
                f"got {decision}/{diagnostic}"
            )
        results.append(
            {
                "id": scenario_id,
                "decision": decision,
                "diagnostic": diagnostic,
            }
        )
    if ids != sorted(ids) or len(ids) != len(set(ids)):
        raise ValidationError("scenario IDs must be sorted and unique")
    if len(ids) != 14:
        raise ValidationError("scenario inventory changed")
    return results


def expect_policy_failure(
    base: dict[str, object], label: str, mutate: object
) -> None:
    candidate = copy.deepcopy(base)
    if not callable(mutate):
        raise RuntimeError(f"{label}: mutation is not callable")
    mutate(candidate)
    try:
        validate_policy(candidate)
    except (ValidationError, KeyError):
        return
    raise AssertionError(f"policy mutation passed unexpectedly: {label}")


def run_policy_mutations(policy: dict[str, object]) -> int:
    def category(candidate: dict[str, object], category_id: str) -> dict[str, object]:
        for raw in array_value(candidate["categories"], "mutation categories"):
            value = object_value(raw, "mutation category")
            if value.get("id") == category_id:
                return value
        raise RuntimeError(f"missing mutation category {category_id}")

    mutations = [
        ("status", lambda value: value.__setitem__("status", "accepted")),
        (
            "default disposition",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "defaultDisposition", "warn"
            ),
        ),
        (
            "omitted detection",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "omittedDetectionAllowed", True
            ),
        ),
        (
            "public API override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverridePublicApiProhibition", True
            ),
        ),
        (
            "application strictness override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverrideApplicationOrExampleHaxeStrictness", True
            ),
        ),
        (
            "high vulnerability override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayOverrideCriticalOrHighVulnerabilityStop", True
            ),
        ),
        (
            "unknown boundary override",
            lambda value: object_value(value["authority"], "authority").__setitem__(
                "waiverMayAuthorizeUnknownBoundary", True
            ),
        ),
        (
            "remove category",
            lambda value: array_value(value["categories"], "categories").pop(),
        ),
        (
            "unknown loses decoder",
            lambda value: category(value, "typescript-unknown").__setitem__(
                "decoderEvidenceRequired", False
            ),
        ),
        (
            "private API stable",
            lambda value: category(value, "private-upstream-api").__setitem__(
                "stableWithCurrentWaiverAllowed", True
            ),
        ),
        (
            "public scope removed",
            lambda value: array_value(
                value["prohibitedScopes"], "prohibited scopes"
            ).remove("public-api"),
        ),
        (
            "self approval",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("selfApprovalAllowed", True),
        ),
        (
            "long waiver",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("maximumInitialLifetimeDays", 365),
        ),
        (
            "relative expiry",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("vagueOrReleaseRelativeExpiryAllowed", True),
        ),
        (
            "removal after expiry",
            lambda value: object_value(
                value["waiverContract"], "waiver contract"
            ).__setitem__("removalDeadlineMayExceedExpiry", True),
        ),
        (
            "renewal inherits",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "renewalCarriesPriorApproval", True
            ),
        ),
        (
            "mutable history",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "historyMutable", True
            ),
        ),
        (
            "source drift warns",
            lambda value: object_value(value["lifecycle"], "lifecycle").__setitem__(
                "sourceDriftEffect", "warning"
            ),
        ),
        (
            "unrecorded boundary warns",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("detectedWithoutRecord", "warning"),
        ),
        (
            "stale record allowed",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("recordWithoutDetection", "allowed"),
        ),
        (
            "generated inventory optional",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("generatedInventoryRequired", False),
        ),
        (
            "artifact mapping optional",
            lambda value: object_value(
                value["inventoryContract"], "inventory contract"
            ).__setitem__("sourceToGeneratedBoundaryIdsRequired", False),
        ),
        (
            "review trigger removed",
            lambda value: array_value(
                value["reviewTriggers"], "review triggers"
            ).pop(),
        ),
        (
            "stable gate shortened",
            lambda value: array_value(
                object_value(value["gatePolicy"], "gate policy")["stableRelease"],
                "stable gate",
            ).pop(),
        ),
        (
            "diagnostic collision",
            lambda value: object_value(
                value["diagnostics"], "diagnostics"
            ).__setitem__("staleInventory", "WPX1901"),
        ),
        (
            "stable release authorized",
            lambda value: object_value(value["claims"], "claims").__setitem__(
                "stableReleaseAuthorized", True
            ),
        ),
        (
            "production support claimed",
            lambda value: object_value(value["claims"], "claims").__setitem__(
                "productionSupport", "supported"
            ),
        ),
    ]
    for label, mutate in mutations:
        expect_policy_failure(policy, label, mutate)
    return len(mutations)


def run_schema_mutations(
    schema: dict[str, object], category_ids: list[str]
) -> int:
    def expect_failure(label: str, mutate: object) -> None:
        candidate = copy.deepcopy(schema)
        if not callable(mutate):
            raise RuntimeError(f"{label}: mutation is not callable")
        mutate(candidate)
        try:
            validate_schema(candidate, category_ids)
        except (ValidationError, KeyError):
            return
        raise AssertionError(f"schema mutation passed unexpectedly: {label}")

    def definitions(candidate: dict[str, object]) -> dict[str, object]:
        return object_value(candidate["$defs"], "schema definitions")

    def properties(candidate: dict[str, object]) -> dict[str, object]:
        return object_value(candidate["properties"], "schema properties")

    mutations = [
        (
            "open root",
            lambda value: value.__setitem__("additionalProperties", True),
        ),
        (
            "missing required owner",
            lambda value: array_value(value["required"], "required").remove("owner"),
        ),
        (
            "extra optional field",
            lambda value: properties(value).__setitem__(
                "comment", {"type": "string"}
            ),
        ),
        (
            "category removed",
            lambda value: array_value(
                object_value(
                    definitions(value)["category"], "category definition"
                )["enum"],
                "category enum",
            ).pop(),
        ),
        (
            "weak hash",
            lambda value: object_value(
                definitions(value)["sha256"], "sha definition"
            ).__setitem__("pattern", ".*"),
        ),
        (
            "absolute paths allowed",
            lambda value: object_value(
                definitions(value)["repositoryPath"], "path definition"
            ).__setitem__("pattern", ".+"),
        ),
        (
            "open review",
            lambda value: object_value(
                properties(value)["review"], "review property"
            ).__setitem__("additionalProperties", True),
        ),
        (
            "open source",
            lambda value: object_value(
                properties(value)["source"], "source property"
            ).__setitem__("additionalProperties", True),
        ),
        (
            "waiver ID pattern",
            lambda value: object_value(
                properties(value)["id"], "waiver ID property"
            ).__setitem__("pattern", ".*"),
        ),
        (
            "UTC instant pattern",
            lambda value: object_value(
                definitions(value)["utcInstant"], "UTC definition"
            ).__setitem__("pattern", ".*"),
        ),
        (
            "review receipt digest no longer required",
            lambda value: array_value(
                object_value(properties(value)["review"], "review property")[
                    "required"
                ],
                "review required",
            ).remove("sha256"),
        ),
        (
            "evidence cardinality",
            lambda value: object_value(
                properties(value)["evidence"], "evidence property"
            ).__setitem__("minItems", 0),
        ),
        (
            "source line type",
            lambda value: object_value(
                object_value(properties(value)["source"], "source property")[
                    "properties"
                ],
                "source properties",
            ).__setitem__("startLine", {"type": "string"}),
        ),
        (
            "review path ref",
            lambda value: object_value(
                object_value(properties(value)["review"], "review property")[
                    "properties"
                ],
                "review properties",
            ).__setitem__("path", {"type": "string"}),
        ),
    ]
    for label, mutate in mutations:
        expect_failure(label, mutate)
    return len(mutations)


def run_waiver_mutations(
    waiver: dict[str, object],
    categories: dict[str, dict[str, object]],
    evaluation_at: datetime,
) -> int:
    def expect_failure(label: str, mutate: object) -> None:
        candidate = copy.deepcopy(waiver)
        if not callable(mutate):
            raise RuntimeError(f"{label}: mutation is not callable")
        mutate(candidate)
        try:
            validate_waiver_instance(candidate, categories, evaluation_at)
        except (ValidationError, KeyError):
            return
        raise AssertionError(f"waiver mutation passed unexpectedly: {label}")

    def child(candidate: dict[str, object], key: str) -> dict[str, object]:
        return object_value(candidate[key], f"waiver {key}")

    mutations = [
        ("bad waiver ID", lambda value: value.__setitem__("id", "WAIVER-1")),
        ("bad boundary ID", lambda value: value.__setitem__("boundaryId", "x")),
        (
            "unknown category",
            lambda value: value.__setitem__("category", "unknown"),
        ),
        (
            "self approval",
            lambda value: child(value, "review").__setitem__(
                "reviewer", value["owner"]
            ),
        ),
        (
            "rejected review",
            lambda value: child(value, "review").__setitem__(
                "decision", "rejected"
            ),
        ),
        (
            "relative expiry",
            lambda value: value.__setitem__("expiresAt", "before-1.0"),
        ),
        (
            "overlong lifetime",
            lambda value: value.__setitem__("expiresAt", "2027-09-01T00:00:00Z"),
        ),
        (
            "high risk",
            lambda value: child(value, "risk").__setitem__("severity", "high"),
        ),
        (
            "absolute source path",
            lambda value: child(value, "source").__setitem__(
                "path", "/tmp/boundary.txt"
            ),
        ),
        (
            "source path traversal",
            lambda value: child(value, "source").__setitem__(
                "path", "../boundary.txt"
            ),
        ),
        (
            "source digest drift",
            lambda value: child(value, "source").__setitem__("sha256", "0" * 64),
        ),
        (
            "reversed line range",
            lambda value: child(value, "source").__setitem__("startLine", 4),
        ),
        (
            "scope mismatch",
            lambda value: child(value, "scope").__setitem__("layer", "public-api"),
        ),
        (
            "evidence removed",
            lambda value: value.__setitem__("evidence", []),
        ),
        (
            "review evidence detached",
            lambda value: child(value, "review").__setitem__(
                "evidenceSha256", "0" * 64
            ),
        ),
        (
            "removal after expiry",
            lambda value: child(value, "removal").__setitem__(
                "deadline", "2026-09-02T00:00:00Z"
            ),
        ),
    ]
    for label, mutate in mutations:
        expect_failure(label, mutate)
    return len(mutations)


def run_repository_path_mutations() -> int:
    fixture_root = ROOT / "fixtures" / "unsafe-boundary"
    temporary = Path(tempfile.mkdtemp(prefix=".path-confinement-", dir=fixture_root))
    external = Path(tempfile.mkdtemp(prefix="wordpresshx-adr019-external-"))
    try:
        outside_file = external / "outside.txt"
        outside_file.write_text("outside repository\n", encoding="utf-8")
        file_link = temporary / "file-link.txt"
        directory_link = temporary / "directory-link"
        file_link.symlink_to(outside_file)
        directory_link.symlink_to(external, target_is_directory=True)
        labels = [
            file_link.relative_to(ROOT).as_posix(),
            (directory_link / "outside.txt").relative_to(ROOT).as_posix(),
        ]
        for label in labels:
            try:
                repository_path(label, "adversarial path")
            except ValidationError:
                continue
            raise AssertionError(f"symbolic-link escape passed unexpectedly: {label}")
        return len(labels)
    finally:
        shutil.rmtree(temporary)
        shutil.rmtree(external)


def main() -> None:
    policy = object_value(strict_json(POLICY_PATH), "policy")
    schema = object_value(strict_json(SCHEMA_PATH), "schema")
    scenarios = object_value(strict_json(SCENARIOS_PATH), "scenarios")
    waiver = object_value(strict_json(WAIVER_PATH), "waiver")
    categories = validate_policy(policy)
    validate_schema(schema, list(categories))
    evaluation_at = parse_utc(scenarios["evaluationAt"], "scenario evaluationAt")
    validate_waiver_instance(waiver, categories, evaluation_at)
    results = validate_scenarios(scenarios, policy, categories)
    mutation_count = run_policy_mutations(policy) + run_schema_mutations(
        schema, list(categories)
    ) + run_waiver_mutations(
        waiver, categories, evaluation_at
    ) + run_repository_path_mutations()
    summary = {
        "categoryCount": len(categories),
        "mutationCount": mutation_count,
        "policyDigest": digest(policy),
        "scenarioCount": len(results),
        "scenarioDigest": digest(results),
        "waiverDigest": digest(waiver),
    }
    if not SHA256.fullmatch(summary["policyDigest"]) or not SHA256.fullmatch(
        summary["scenarioDigest"]
    ) or not SHA256.fullmatch(
        summary["waiverDigest"]
    ):
        raise AssertionError("summary digest generation failed")
    print(
        "ADR-019 unsafe-boundary policy passed: "
        f"{summary['categoryCount']} categories, "
        f"{summary['scenarioCount']} scenarios, "
        f"{summary['mutationCount']} fail-closed mutations"
    )
    print("UNSAFE_BOUNDARY_SUMMARY=" + json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
