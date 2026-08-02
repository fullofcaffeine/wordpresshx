#!/usr/bin/env python3
"""Validate the temporary Beads history-reader source/build lock."""

from __future__ import annotations

import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[2]
LOCK = ROOT / "tooling" / "beads" / "history-reader.lock.json"
TOOLCHAIN_PIN = ROOT / ".beads-toolchain"
SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SOURCE_COMMIT = "c3e600c940ad6ac082934ca5242f1ca1dde7ecb1"
HISTORY_FIX_COMMIT = "7eb428cde13c6d2c4743a76533be8df2d418aff5"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"history-reader lock invalid: {message}")


document = json.loads(LOCK.read_text(encoding="utf-8"))
require(set(document) == {
    "schemaVersion",
    "upstreamRepository",
    "baseTag",
    "baseCommit",
    "historyFix",
    "expectedChangedFiles",
    "repositoryCompatibility",
    "build",
    "scope",
}, "top-level keys are not closed")
require(document["schemaVersion"] == 1, "schemaVersion must be 1")
require(
    document["upstreamRepository"] == "https://github.com/gastownhall/beads.git",
    "unexpected upstream repository",
)
require(document["baseTag"] == "v1.1.0", "unexpected base tag")
require(SHA1.fullmatch(document["baseCommit"]) is not None, "base commit is not a full SHA")
require(document["baseCommit"] == SOURCE_COMMIT, "unexpected schema-compatible source commit")

history_fix = document["historyFix"]
require(
    set(history_fix) == {"issue", "pullRequest", "commit", "ancestorDistance"},
    "historyFix keys are not closed",
)
require(history_fix["issue"] == 4867, "unexpected upstream issue")
require(history_fix["pullRequest"] == 4912, "unexpected upstream pull request")
require(SHA1.fullmatch(history_fix["commit"]) is not None, "fix commit is not a full SHA")
require(history_fix["commit"] == HISTORY_FIX_COMMIT, "unexpected upstream history fix")
require(history_fix["ancestorDistance"] == 251, "unexpected source/fix ancestry distance")

expected_files = document["expectedChangedFiles"]
require(expected_files == sorted(expected_files), "expected changed files must be sorted")
require(len(expected_files) == len(set(expected_files)) == 4, "expected exactly four unique changed files")
require(all(path.startswith("internal/storage/") for path in expected_files), "fix escapes storage packages")

compatibility = document["repositoryCompatibility"]
require(
    set(compatibility) == {"toolchainPin", "databaseSchemaVersion", "clientIdentity"},
    "repositoryCompatibility keys are not closed",
)
require(compatibility["toolchainPin"] == ".beads-toolchain", "unexpected repository toolchain pin")
require(compatibility["databaseSchemaVersion"] == 62, "unexpected database schema version")
require(
    compatibility["clientIdentity"] == "bd version 1.1.0 (c3e600c94)",
    "unexpected client identity",
)

toolchain = {}
for line in TOOLCHAIN_PIN.read_text(encoding="utf-8").splitlines():
    if line and not line.startswith("#"):
        require("=" in line, "repository toolchain pin contains a malformed line")
        key, value = line.split("=", 1)
        require(key not in toolchain, f"repository toolchain pin repeats {key}")
        toolchain[key] = value
require(
    set(toolchain) == {"format", "client", "schema", "sha256", "identity"},
    "repository toolchain pin keys are not closed",
)
require(toolchain["format"] == "1", "repository toolchain pin format is not 1")
require(toolchain["client"] == f"main-{SOURCE_COMMIT[:12]}", "repository toolchain client differs from source lock")
require(toolchain["schema"] == str(compatibility["databaseSchemaVersion"]), "repository toolchain schema differs from source lock")
require(toolchain["identity"] == compatibility["clientIdentity"], "repository toolchain identity differs from source lock")

build = document["build"]
require(set(build) == {"cgoEnabled", "tags", "testPackage", "testName"}, "build keys are not closed")
require(build["cgoEnabled"] == "1", "embedded Dolt requires CGO")
require(build["tags"] == "gms_pure_go", "portable regex build tag is required")
require(build["testPackage"] == "./internal/storage/embeddeddolt", "unexpected regression package")
require(build["testName"] == "TestHistory_NullTextColumns", "unexpected regression test")

scope = document["scope"]
require(set(scope) == {
    "purpose",
    "liveDatabaseAccess",
    "temporaryDatabaseCopyRequired",
    "retireWhen",
}, "scope keys are not closed")
require(scope["liveDatabaseAccess"] == "forbidden", "live database access must remain forbidden")
require(scope["temporaryDatabaseCopyRequired"] is True, "temporary copy must be required")
require(
    scope["retireWhen"] == "The repository no longer requires independent historical issue-state verification",
    "unexpected retirement trigger",
)

print("Beads history-reader lock passed")
