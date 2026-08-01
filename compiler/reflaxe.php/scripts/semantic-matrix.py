#!/usr/bin/env python3
"""Generate and verify the typed reflaxe.php semantic capability matrix."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parent.parent
MATRIX_PATH = PACKAGE_ROOT / "semantic-capabilities.json"
SOURCE_PATH = PACKAGE_ROOT / "src/reflaxe/php/compiler/PhpSemanticCapabilities.hx"
EXPORT_COMMAND = "haxe -cp src -cp test/semantic-matrix/tool --run MatrixExport"
REQUIRED_CATEGORIES = {
    "module-type-layout",
    "values-collections",
    "control-flow",
    "calls-closures",
    "exceptions",
    "null-behavior",
    "runtime-stdlib",
    "diagnostics",
    "source-maps",
    "numeric",
    "string-unicode",
    "ordering",
    "path-environment-filesystem-network-timezone",
}
STATES = {"admitted", "unsupported-owned", "unverified-owned"}


class MatrixError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise MatrixError(message)


def digest(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def canonical(value: object) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def exported_records() -> list[dict[str, str]]:
    result = subprocess.run(
        ["haxe", "-cp", "src", "-cp", "test/semantic-matrix/tool", "--run", "MatrixExport"],
        cwd=PACKAGE_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(result.returncode == 0, "typed capability export failed:\n" + result.stderr)
    require(not result.stderr.strip(), "typed capability export wrote stderr:\n" + result.stderr)
    records: list[dict[str, str]] = []
    for line_number, line in enumerate(result.stdout.splitlines(), start=1):
        fields = line.split("\t")
        require(len(fields) == 5 and all(fields), f"invalid capability export line {line_number}")
        capability_id, category, state, evidence, owner = fields
        records.append(
            {
                "id": capability_id,
                "category": category,
                "state": state,
                "evidence": evidence,
                "owner": owner,
            }
        )
    require(records, "typed capability export was empty")
    return records


def build() -> dict[str, object]:
    records = exported_records()
    counts = {state: sum(1 for record in records if record["state"] == state) for state in sorted(STATES)}
    return {
        "schemaVersion": 1,
        "matrixId": "reflaxe-php-semantic-capabilities-v1",
        "status": "incremental-runtime-semantics-hosted-pending",
        "sourceAuthority": {
            "path": SOURCE_PATH.relative_to(PACKAGE_ROOT).as_posix(),
            "sha256": digest(SOURCE_PATH.read_bytes()),
            "exportCommand": EXPORT_COMMAND,
        },
        "summary": {
            "capabilityCount": len(records),
            "categoryCount": len({record["category"] for record in records}),
            "stateCounts": counts,
        },
        "capabilities": records,
        "claims": {
            "permitted": [
                "the exact admitted records passed their named local evidence owners",
                "unsupported and unverified records remain explicitly owned",
            ],
            "withheld": [
                "broad Haxe language compatibility",
                "complete runtime or standard-library support",
                "official Haxe target qualification",
                "WordPress compatibility",
                "publication or production support",
            ],
        },
    }


def validate_shape(model: dict[str, object]) -> None:
    require(
        set(model)
        == {"schemaVersion", "matrixId", "status", "sourceAuthority", "summary", "capabilities", "claims"},
        "semantic matrix keys drifted",
    )
    require(model["schemaVersion"] == 1, "semantic matrix schema changed")
    require(model["matrixId"] == "reflaxe-php-semantic-capabilities-v1", "semantic matrix identity changed")
    require(model["status"] == "incremental-runtime-semantics-hosted-pending", "semantic matrix status overstates evidence")
    records = model["capabilities"]
    require(isinstance(records, list) and records, "semantic matrix capabilities must be non-empty")
    typed_records = [record for record in records if isinstance(record, dict)]
    require(len(typed_records) == len(records), "semantic matrix contains a non-object capability")
    ids: list[str] = []
    categories: set[str] = set()
    state_counts = {state: 0 for state in sorted(STATES)}
    for record in typed_records:
        require(set(record) == {"id", "category", "state", "evidence", "owner"}, "capability keys drifted")
        require(all(isinstance(record[field], str) and record[field] for field in record), "capability fields must be non-empty strings")
        capability_id = str(record["id"])
        category = str(record["category"])
        state = str(record["state"])
        require(state in STATES, f"capability {capability_id} has an unknown state")
        require(record["owner"] == "reflaxe.php-runtime-semantics", f"capability {capability_id} lost its owner")
        if state == "admitted":
            require(str(record["evidence"]).startswith("bash compiler/reflaxe.php/scripts/test-"), f"admitted capability {capability_id} lacks executable evidence")
        ids.append(capability_id)
        categories.add(category)
        state_counts[state] += 1
    require(ids == sorted(ids) and len(ids) == len(set(ids)), "capability IDs are not unique and sorted")
    require(categories == REQUIRED_CATEGORIES, "semantic category inventory is incomplete")
    summary = model["summary"]
    require(isinstance(summary, dict), "semantic matrix summary must be an object")
    require(
        summary
        == {
            "capabilityCount": len(records),
            "categoryCount": len(categories),
            "stateCounts": state_counts,
        },
        "semantic matrix summary drifted",
    )
    claims = model["claims"]
    require(isinstance(claims, dict) and set(claims) == {"permitted", "withheld"}, "semantic claims changed")
    withheld = claims["withheld"]
    require(isinstance(withheld, list) and "official Haxe target qualification" in withheld, "official qualification was laundered")
    require("WordPress compatibility" in withheld and "publication or production support" in withheld, "cross-surface or release claim was laundered")


def validate(model: dict[str, object]) -> None:
    validate_shape(model)
    require(canonical(model) == canonical(build()), "semantic matrix is stale relative to its typed source authority")


def load() -> dict[str, object]:
    value = json.loads(MATRIX_PATH.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "semantic matrix root must be an object")
    return value


def self_test(model: dict[str, object]) -> None:
    mutations: list[tuple[str, dict[str, object]]] = []
    missing = copy.deepcopy(model)
    missing["capabilities"] = list(missing["capabilities"])[1:]
    mutations.append(("missing capability", missing))
    admitted_without_owner = copy.deepcopy(model)
    first = admitted_without_owner["capabilities"][0]
    first["owner"] = ""
    mutations.append(("admitted without owner", admitted_without_owner))
    invented_pass = copy.deepcopy(model)
    last = invented_pass["capabilities"][-1]
    last["state"] = "admitted"
    last["evidence"] = "generated output said it passed"
    mutations.append(("invented pass", invented_pass))
    overclaim = copy.deepcopy(model)
    overclaim["claims"]["withheld"].remove("official Haxe target qualification")
    mutations.append(("official qualification laundering", overclaim))
    stale_source = copy.deepcopy(model)
    stale_source["sourceAuthority"]["sha256"] = "0" * 64
    mutations.append(("stale source", stale_source))
    for label, mutation in mutations:
        try:
            validate(mutation)
        except MatrixError:
            continue
        raise MatrixError(f"mutation unexpectedly passed: {label}")
    print(f"reflaxe.php semantic matrix self-test passed: {len(mutations)} fail-closed mutations")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("generate", "validate", "self-test"))
    arguments = parser.parse_args()
    if arguments.command == "generate":
        MATRIX_PATH.write_text(canonical(build()), encoding="utf-8")
        print(f"wrote {MATRIX_PATH.relative_to(PACKAGE_ROOT)}")
        return
    model = load()
    if arguments.command == "validate":
        validate(model)
        print("reflaxe.php semantic capability matrix passed")
        return
    self_test(model)


if __name__ == "__main__":
    try:
        main()
    except MatrixError as error:
        raise SystemExit(f"semantic matrix error: {error}") from error
