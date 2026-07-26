#!/usr/bin/env python3
"""Validate an independent G1 WordPress/PHP readability review receipt."""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
REVIEW_ROOT = REPOSITORY_ROOT / "review" / "g1-php-readability"
PACKET_ROOT = REVIEW_ROOT / "packet"
MANIFEST_PATH = PACKET_ROOT / "packet-manifest.json"
SCHEMA_PATH = REPOSITORY_ROOT / "schemas" / "php-readability-review.schema.json"
SHA1 = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
FINDING_ID = re.compile(r"^g1-finding-[0-9]{3}$")
REQUIRED_CATEGORIES = (
    "ordinary-php-naming-and-shape",
    "wordpress-conventions",
    "control-flow-and-bootstrap",
    "adapters-and-private-boundary",
    "errors-and-native-stack-frames",
    "haxe-source-correlation",
)
PLACEHOLDER = re.compile(
    r"(?:replace|placeholder|todo|tbd|unknown|unassigned|0000-00-00)",
    re.IGNORECASE,
)
class ReviewError(ValueError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def require_keys(
    value: object,
    expected: set[str],
    label: str,
) -> dict[str, object]:
    if not isinstance(value, dict):
        raise ReviewError(f"{label} must be an object")
    actual = set(value)
    if actual != expected:
        raise ReviewError(
            f"{label} fields differ: missing={sorted(expected - actual)}, "
            f"unknown={sorted(actual - expected)}"
        )
    return value


def require_string(
    value: object,
    label: str,
    minimum: int,
    *,
    placeholders_allowed: bool = False,
) -> str:
    if not isinstance(value, str) or len(value.strip()) < minimum:
        raise ReviewError(f"{label} must contain at least {minimum} characters")
    if not placeholders_allowed and PLACEHOLDER.search(value):
        raise ReviewError(f"{label} still contains a placeholder")
    return value.strip()


def safe_path(value: object, label: str) -> str:
    path_text = require_string(value, label, 1)
    path = PurePosixPath(path_text)
    if (
        path.is_absolute()
        or "\\" in path_text
        or ":" in path_text
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise ReviewError(f"{label} is not a safe packet-relative path")
    if not PACKET_ROOT.joinpath(*path.parts).is_file():
        raise ReviewError(f"{label} does not exist in the packet: {path_text}")
    return path_text


def unique_strings(value: object, label: str) -> list[str]:
    if not isinstance(value, list) or not all(
        isinstance(item, str) for item in value
    ):
        raise ReviewError(f"{label} must be an array of strings")
    if len(value) != len(set(value)):
        raise ReviewError(f"{label} must not contain duplicates")
    return value


def load_manifest() -> dict[str, object]:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    require_keys(
        manifest,
        {
            "schemaVersion",
            "packetId",
            "implementationCommit",
            "implementationTree",
            "files",
            "packetDigestAlgorithm",
            "packetDigest",
            "reviewPolicy",
        },
        "packet manifest",
    )
    if manifest["schemaVersion"] != 1:
        raise ReviewError("packet manifest schema version changed")
    if manifest["packetId"] != "wordpresshx-g1-php-readability-v1":
        raise ReviewError("packet identity changed")
    if not isinstance(manifest["implementationCommit"], str) or not SHA1.fullmatch(
        manifest["implementationCommit"]
    ):
        raise ReviewError("packet implementation commit is invalid")
    if not isinstance(manifest["implementationTree"], str) or not SHA1.fullmatch(
        manifest["implementationTree"]
    ):
        raise ReviewError("packet implementation tree is invalid")
    if not isinstance(manifest["files"], list) or not manifest["files"]:
        raise ReviewError("packet file inventory is empty")

    records = manifest["files"]
    paths: list[str] = []
    for index, record_value in enumerate(records):
        record = require_keys(
            record_value,
            {"path", "role", "bytes", "lines", "sha256"},
            f"packet file {index}",
        )
        path_text = safe_path(record["path"], f"packet file {index}.path")
        paths.append(path_text)
        data = PACKET_ROOT.joinpath(*PurePosixPath(path_text).parts).read_bytes()
        if record["bytes"] != len(data):
            raise ReviewError(f"{path_text}: byte count is stale")
        if record["lines"] != len(data.splitlines()):
            raise ReviewError(f"{path_text}: line count is stale")
        if record["sha256"] != digest(data):
            raise ReviewError(f"{path_text}: SHA-256 is stale")
    if paths != sorted(set(paths)):
        raise ReviewError("packet file inventory must be sorted and unique")
    actual_paths = sorted(
        path.relative_to(PACKET_ROOT).as_posix()
        for path in PACKET_ROOT.rglob("*")
        if path.is_file() and path.name != "packet-manifest.json"
    )
    if paths != actual_paths:
        raise ReviewError("packet file inventory is incomplete")

    identity = {
        "packetId": manifest["packetId"],
        "implementationCommit": manifest["implementationCommit"],
        "implementationTree": manifest["implementationTree"],
        "files": manifest["files"],
    }
    if manifest["packetDigest"] != digest(canonical(identity)):
        raise ReviewError("packet digest is stale")
    policy = require_keys(
        manifest["reviewPolicy"],
        {
            "independentReviewerRequired",
            "ineligibleReviewerNames",
            "requiredCategories",
            "blockingFindingsMustBeResolved",
            "publicationAuthorized",
            "productionSupportClaimed",
        },
        "packet review policy",
    )
    if policy["requiredCategories"] != list(REQUIRED_CATEGORIES):
        raise ReviewError("packet review categories changed")
    if (
        policy["independentReviewerRequired"] is not True
        or policy["blockingFindingsMustBeResolved"] is not True
        or policy["publicationAuthorized"] is not False
        or policy["productionSupportClaimed"] is not False
    ):
        raise ReviewError("packet review policy weakened")
    unique_strings(policy["ineligibleReviewerNames"], "ineligible reviewer names")
    return manifest


def validate_schema_contract() -> None:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    if schema.get("$id") != (
        "https://wordpress-hx.dev/schemas/php-readability-review.schema.json"
    ):
        raise ReviewError("review schema identity changed")
    category_enum = (
        schema.get("$defs", {})
        .get("category", {})
        .get("properties", {})
        .get("id", {})
        .get("enum")
    )
    if category_enum != list(REQUIRED_CATEGORIES):
        raise ReviewError("review schema category inventory changed")
    if schema.get("additionalProperties") is not False:
        raise ReviewError("review schema must remain closed")


def receipt_digest(receipt: dict[str, object]) -> str:
    unsigned = {
        key: value for key, value in receipt.items() if key != "receiptDigest"
    }
    return digest(canonical(unsigned))


def validate_packet_reference(
    value: object,
    manifest: dict[str, object],
) -> None:
    packet = require_keys(
        value,
        {
            "packetId",
            "implementationCommit",
            "manifestSha256",
            "packetDigest",
        },
        "receipt packet",
    )
    if packet["packetId"] != manifest["packetId"]:
        raise ReviewError("receipt packet ID is stale")
    if packet["implementationCommit"] != manifest["implementationCommit"]:
        raise ReviewError("receipt implementation commit is stale")
    if packet["manifestSha256"] != digest(MANIFEST_PATH.read_bytes()):
        raise ReviewError("receipt packet manifest SHA-256 is stale")
    if packet["packetDigest"] != manifest["packetDigest"]:
        raise ReviewError("receipt packet digest is stale")


def validate_template(
    receipt: dict[str, object],
    manifest: dict[str, object],
) -> None:
    validate_receipt_shape(receipt)
    validate_packet_reference(receipt["packet"], manifest)
    if receipt["decision"] != "pending" or receipt["receiptDigest"] is not None:
        raise ReviewError("review template must remain pending and unsigned")
    reviewer = receipt["reviewer"]
    if not any(
        PLACEHOLDER.search(str(reviewer[field]))
        for field in ("name", "role", "wordpressPhpExperience")
    ):
        raise ReviewError("review template lost its visible reviewer placeholders")
    if receipt["reviewedAt"] != "0000-00-00":
        raise ReviewError("review template date placeholder changed")
    categories = receipt["categories"]
    if [category["id"] for category in categories] != list(REQUIRED_CATEGORIES):
        raise ReviewError("review template category inventory changed")
    if any(category["outcome"] != "pending" for category in categories):
        raise ReviewError("review template category must remain pending")
    for category in categories:
        for path in category["evidencePaths"]:
            safe_path(path, f"{category['id']} evidence path")
    if receipt["findings"] != []:
        raise ReviewError("review template must begin with no invented findings")


def validate_receipt_shape(receipt: object) -> dict[str, object]:
    document = require_keys(
        receipt,
        {
            "schema",
            "schemaVersion",
            "receiptId",
            "packet",
            "reviewer",
            "reviewedAt",
            "decision",
            "categories",
            "findings",
            "confirmation",
            "receiptDigest",
        },
        "review receipt",
    )
    if (
        document["schema"] != "wordpress-hx.php-readability-review.v1"
        or document["schemaVersion"] != 1
    ):
        raise ReviewError("review receipt contract identity changed")
    if not isinstance(document["receiptId"], str) or not re.fullmatch(
        r"g1-php-readability-[a-z0-9][a-z0-9.-]*",
        document["receiptId"],
    ):
        raise ReviewError("review receipt ID is invalid")
    if not isinstance(document["categories"], list):
        raise ReviewError("review categories must be an array")
    if not isinstance(document["findings"], list):
        raise ReviewError("review findings must be an array")
    return document


def validate_final(
    receipt: dict[str, object],
    manifest: dict[str, object],
) -> None:
    validate_receipt_shape(receipt)
    validate_packet_reference(receipt["packet"], manifest)
    if receipt["decision"] not in {"accepted", "changes-required"}:
        raise ReviewError("completed review decision must not remain pending")
    try:
        dt.date.fromisoformat(str(receipt["reviewedAt"]))
    except ValueError as error:
        raise ReviewError("reviewedAt must be a real ISO calendar date") from error

    reviewer = require_keys(
        receipt["reviewer"],
        {
            "name",
            "role",
            "wordpressPhpExperience",
            "reviewContext",
            "independence",
        },
        "reviewer",
    )
    reviewer_name = require_string(reviewer["name"], "reviewer.name", 2)
    require_string(reviewer["role"], "reviewer.role", 8)
    require_string(
        reviewer["wordpressPhpExperience"],
        "reviewer.wordpressPhpExperience",
        24,
    )
    review_context = require_keys(
        reviewer["reviewContext"],
        {
            "kind",
            "provider",
            "model",
            "promptSha256",
            "repositorySnapshotSha256",
        },
        "reviewer.reviewContext",
    )
    if review_context["kind"] != "oracle-agent":
        raise ReviewError("independent review must use a separate Oracle agent")
    require_string(review_context["provider"], "reviewContext.provider", 2)
    require_string(review_context["model"], "reviewContext.model", 2)
    for field in ("promptSha256", "repositorySnapshotSha256"):
        if not isinstance(review_context[field], str) or not SHA256.fullmatch(
            review_context[field]
        ):
            raise ReviewError(f"reviewContext.{field} must be a SHA-256 digest")
    ineligible = {
        name.strip().casefold()
        for name in manifest["reviewPolicy"]["ineligibleReviewerNames"]
    }
    if reviewer_name.casefold() in ineligible:
        raise ReviewError("the implementation author cannot approve this packet")
    independence = require_keys(
        reviewer["independence"],
        {
            "implementedEmitter",
            "contributedToReviewedCommit",
            "preparedPacket",
            "statement",
        },
        "reviewer.independence",
    )
    for field in (
        "implementedEmitter",
        "contributedToReviewedCommit",
        "preparedPacket",
    ):
        if independence[field] is not False:
            raise ReviewError(f"reviewer independence requires {field}=false")
    require_string(
        independence["statement"],
        "reviewer.independence.statement",
        32,
    )

    categories = receipt["categories"]
    if len(categories) != len(REQUIRED_CATEGORIES):
        raise ReviewError("review must cover exactly six categories")
    category_by_id: dict[str, dict[str, object]] = {}
    for index, value in enumerate(categories):
        category = require_keys(
            value,
            {"id", "outcome", "notes", "evidencePaths", "findingIds"},
            f"category {index}",
        )
        category_id = category["id"]
        if category_id not in REQUIRED_CATEGORIES or category_id in category_by_id:
            raise ReviewError(f"invalid or duplicate review category: {category_id}")
        if category["outcome"] not in {"accepted", "changes-required"}:
            raise ReviewError(f"{category_id}: outcome must not remain pending")
        require_string(category["notes"], f"{category_id}.notes", 16)
        evidence_paths = unique_strings(
            category["evidencePaths"],
            f"{category_id}.evidencePaths",
        )
        if not evidence_paths:
            raise ReviewError(f"{category_id}: evidencePaths cannot be empty")
        for path in evidence_paths:
            safe_path(path, f"{category_id}.evidencePaths")
        finding_ids = unique_strings(
            category["findingIds"],
            f"{category_id}.findingIds",
        )
        if not all(FINDING_ID.fullmatch(finding) for finding in finding_ids):
            raise ReviewError(f"{category_id}: finding ID is invalid")
        category_by_id[category_id] = category
    if list(category_by_id) != list(REQUIRED_CATEGORIES):
        raise ReviewError("review categories must use the canonical order")

    findings_by_id: dict[str, dict[str, object]] = {}
    for index, value in enumerate(receipt["findings"]):
        finding = require_keys(
            value,
            {
                "id",
                "category",
                "severity",
                "summary",
                "evidencePaths",
                "resolution",
                "resolutionNotes",
                "resolutionEvidencePaths",
            },
            f"finding {index}",
        )
        finding_id = finding["id"]
        if (
            not isinstance(finding_id, str)
            or not FINDING_ID.fullmatch(finding_id)
            or finding_id in findings_by_id
        ):
            raise ReviewError(f"finding {index}: ID is invalid or duplicated")
        if finding["category"] not in category_by_id:
            raise ReviewError(f"{finding_id}: category is invalid")
        if finding["severity"] not in {
            "blocking",
            "non-blocking",
            "observation",
        }:
            raise ReviewError(f"{finding_id}: severity is invalid")
        require_string(finding["summary"], f"{finding_id}.summary", 16)
        evidence_paths = unique_strings(
            finding["evidencePaths"],
            f"{finding_id}.evidencePaths",
        )
        if not evidence_paths:
            raise ReviewError(f"{finding_id}: evidencePaths cannot be empty")
        for path in evidence_paths:
            safe_path(path, f"{finding_id}.evidencePaths")
        if finding["resolution"] not in {
            "open",
            "resolved",
            "accepted-non-blocking",
        }:
            raise ReviewError(f"{finding_id}: resolution is invalid")
        if (
            finding["severity"] == "blocking"
            and finding["resolution"] == "accepted-non-blocking"
        ):
            raise ReviewError(f"{finding_id}: blocking finding cannot be accepted")
        resolution_paths = unique_strings(
            finding["resolutionEvidencePaths"],
            f"{finding_id}.resolutionEvidencePaths",
        )
        for path in resolution_paths:
            safe_path(path, f"{finding_id}.resolutionEvidencePaths")
        if finding["resolution"] == "resolved":
            require_string(
                finding["resolutionNotes"],
                f"{finding_id}.resolutionNotes",
                16,
            )
            if not resolution_paths:
                raise ReviewError(
                    f"{finding_id}: resolved finding needs resolution evidence"
                )
        findings_by_id[finding_id] = finding

    referenced_findings: set[str] = set()
    for category_id, category in category_by_id.items():
        expected = sorted(
            finding_id
            for finding_id, finding in findings_by_id.items()
            if finding["category"] == category_id
        )
        if category["findingIds"] != expected:
            raise ReviewError(
                f"{category_id}: findingIds do not match classified findings"
            )
        referenced_findings.update(category["findingIds"])
    if referenced_findings != set(findings_by_id):
        raise ReviewError("one or more findings are not classified")

    confirmation = require_keys(
        receipt["confirmation"],
        {
            "allBlockingFindingsResolved",
            "publicationAuthorized",
            "productionSupportClaimed",
            "attestation",
        },
        "confirmation",
    )
    if (
        confirmation["publicationAuthorized"] is not False
        or confirmation["productionSupportClaimed"] is not False
    ):
        raise ReviewError("G1 review cannot authorize publication or support")
    require_string(
        confirmation["attestation"],
        "confirmation.attestation",
        32,
    )
    open_blocking = [
        finding_id
        for finding_id, finding in findings_by_id.items()
        if finding["severity"] == "blocking"
        and finding["resolution"] != "resolved"
    ]
    if receipt["decision"] == "accepted":
        if any(
            category["outcome"] != "accepted"
            for category in category_by_id.values()
        ):
            raise ReviewError("accepted review requires six accepted categories")
        if open_blocking:
            raise ReviewError(
                "accepted review has unresolved blocking findings: "
                + ", ".join(open_blocking)
            )
        if any(
            finding["resolution"] == "open"
            for finding in findings_by_id.values()
        ):
            raise ReviewError("accepted review cannot retain open findings")
        if confirmation["allBlockingFindingsResolved"] is not True:
            raise ReviewError(
                "accepted review must confirm all blocking findings resolved"
            )
    else:
        if not any(
            category["outcome"] == "changes-required"
            for category in category_by_id.values()
        ):
            raise ReviewError(
                "changes-required review needs a changes-required category"
            )
        if not open_blocking:
            raise ReviewError(
                "changes-required review needs an open blocking finding"
            )
        if confirmation["allBlockingFindingsResolved"] is not False:
            raise ReviewError(
                "changes-required review cannot claim blockers are resolved"
            )

    if not isinstance(receipt["receiptDigest"], str) or not SHA256.fullmatch(
        receipt["receiptDigest"]
    ):
        raise ReviewError("receiptDigest must be a lowercase SHA-256")
    if receipt["receiptDigest"] != receipt_digest(receipt):
        raise ReviewError("receiptDigest is stale")


def self_test(manifest: dict[str, object]) -> None:
    manifest_sha = digest(MANIFEST_PATH.read_bytes())
    packet = {
        "packetId": manifest["packetId"],
        "implementationCommit": manifest["implementationCommit"],
        "manifestSha256": manifest_sha,
        "packetDigest": manifest["packetDigest"],
    }
    categories = []
    evidence_by_category = {
        "ordinary-php-naming-and-shape": [
            "php/acme-books-adapters/includes/PublicAdapters.php"
        ],
        "wordpress-conventions": [
            "php/acme-books-adapters/acme-books-adapters.php"
        ],
        "control-flow-and-bootstrap": [
            "php/acme-books-adapters/includes/autoload.php"
        ],
        "adapters-and-private-boundary": [
            "php/source-correlation/includes/FailureCallbacks.php"
        ],
        "errors-and-native-stack-frames": [
            "traces/private.native.stack"
        ],
        "haxe-source-correlation": [
            "traces/private.correlated.json"
        ],
    }
    for category_id in REQUIRED_CATEGORIES:
        categories.append(
            {
                "id": category_id,
                "outcome": "accepted",
                "notes": "Independent fixture review found this category readable.",
                "evidencePaths": evidence_by_category[category_id],
                "findingIds": [],
            }
        )
    receipt = {
        "schema": "wordpress-hx.php-readability-review.v1",
        "schemaVersion": 1,
        "receiptId": "g1-php-readability-validator-fixture",
        "packet": packet,
        "reviewer": {
            "name": "Oracle",
            "role": "Senior WordPress and PHP reviewer",
            "wordpressPhpExperience": (
                "Maintains native WordPress plugins and reviews PHP APIs."
            ),
            "reviewContext": {
                "kind": "oracle-agent",
                "provider": "OpenAI",
                "model": "GPT-5.6",
                "promptSha256": "1" * 64,
                "repositorySnapshotSha256": "2" * 64,
            },
            "independence": {
                "implementedEmitter": False,
                "contributedToReviewedCommit": False,
                "preparedPacket": False,
                "statement": (
                    "I did not implement, contribute to, or prepare this packet."
                ),
            },
        },
        "reviewedAt": "2026-07-26",
        "decision": "accepted",
        "categories": categories,
        "findings": [],
        "confirmation": {
            "allBlockingFindingsResolved": True,
            "publicationAuthorized": False,
            "productionSupportClaimed": False,
            "attestation": (
                "I reviewed all six categories against the identified packet."
            ),
        },
        "receiptDigest": "",
    }
    receipt["receiptDigest"] = receipt_digest(receipt)
    validate_final(receipt, manifest)

    mutations = []

    def mutate(label: str, change) -> None:
        value = copy.deepcopy(receipt)
        change(value)
        if label != "stale-receipt-digest":
            value["receiptDigest"] = receipt_digest(value)
        mutations.append((label, value))

    mutate(
        "missing-oracle-context",
        lambda value: value["reviewer"]["reviewContext"].__setitem__(
            "kind", "implementation-turn"
        ),
    )
    mutate(
        "stale-oracle-input",
        lambda value: value["reviewer"]["reviewContext"].__setitem__(
            "repositorySnapshotSha256", "not-a-digest"
        ),
    )
    mutate(
        "implementation-author",
        lambda value: value["reviewer"].__setitem__(
            "name",
            manifest["reviewPolicy"]["ineligibleReviewerNames"][0],
        ),
    )
    mutate(
        "emitter-contributor",
        lambda value: value["reviewer"]["independence"].__setitem__(
            "implementedEmitter",
            True,
        ),
    )
    mutate(
        "missing-category",
        lambda value: value["categories"].pop(),
    )
    mutate(
        "missing-evidence",
        lambda value: value["categories"][0].__setitem__(
            "evidencePaths",
            ["php/missing.php"],
        ),
    )

    def add_open_blocker(value: dict[str, object]) -> None:
        finding = {
            "id": "g1-finding-001",
            "category": "ordinary-php-naming-and-shape",
            "severity": "blocking",
            "summary": "Fixture blocking finding remains unresolved.",
            "evidencePaths": [
                "php/acme-books-adapters/includes/PublicAdapters.php"
            ],
            "resolution": "open",
            "resolutionNotes": "",
            "resolutionEvidencePaths": [],
        }
        value["findings"].append(finding)
        value["categories"][0]["findingIds"] = ["g1-finding-001"]

    mutate("accepted-open-blocker", add_open_blocker)
    mutate(
        "stale-manifest",
        lambda value: value["packet"].__setitem__("manifestSha256", "0" * 64),
    )
    mutate(
        "stale-packet",
        lambda value: value["packet"].__setitem__("packetDigest", "0" * 64),
    )
    mutate(
        "support-claim",
        lambda value: value["confirmation"].__setitem__(
            "productionSupportClaimed",
            True,
        ),
    )
    mutate(
        "pending-decision",
        lambda value: value.__setitem__("decision", "pending"),
    )
    mutate(
        "unclassified-finding",
        lambda value: value["findings"].append(
            {
                "id": "g1-finding-002",
                "category": "wordpress-conventions",
                "severity": "observation",
                "summary": "Fixture observation must be classified by category.",
                "evidencePaths": [
                    "php/acme-books-adapters/acme-books-adapters.php"
                ],
                "resolution": "accepted-non-blocking",
                "resolutionNotes": "",
                "resolutionEvidencePaths": [],
            }
        ),
    )
    stale = copy.deepcopy(receipt)
    stale["reviewer"]["role"] = "Changed reviewer role"
    mutations.append(("stale-receipt-digest", stale))

    for label, mutation in mutations:
        try:
            validate_final(mutation, manifest)
        except ReviewError:
            continue
        raise ReviewError(f"validator mutation unexpectedly passed: {label}")
    print(
        "G1 PHP review validator self-test passed: "
        f"1 positive, {len(mutations)} fail-closed mutations"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("receipt", nargs="?")
    parser.add_argument("--template", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        validate_schema_contract()
        manifest = load_manifest()
        if args.self_test:
            self_test(manifest)
        if args.receipt is not None:
            receipt_path = Path(args.receipt)
            receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
            if args.template:
                validate_template(receipt, manifest)
                print("G1 PHP review template passed")
            else:
                validate_final(receipt, manifest)
                print(
                    "G1 PHP review receipt passed: "
                    f"{receipt['decision']} by {receipt['reviewer']['name']}"
                )
        elif not args.self_test:
            parser.error("receipt or --self-test is required")
    except (OSError, json.JSONDecodeError, ReviewError) as error:
        print(f"G1 PHP review validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
