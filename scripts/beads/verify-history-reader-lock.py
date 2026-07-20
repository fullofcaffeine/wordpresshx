#!/usr/bin/env python3
"""Validate the temporary Beads history-reader source/build lock."""

from __future__ import annotations

import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[2]
LOCK = ROOT / "tooling" / "beads" / "history-reader.lock.json"
SHA1 = re.compile(r"[0-9a-f]{40}\Z")


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

history_fix = document["historyFix"]
require(set(history_fix) == {"issue", "pullRequest", "commit"}, "historyFix keys are not closed")
require(history_fix["issue"] == 4867, "unexpected upstream issue")
require(history_fix["pullRequest"] == 4912, "unexpected upstream pull request")
require(SHA1.fullmatch(history_fix["commit"]) is not None, "fix commit is not a full SHA")

expected_files = document["expectedChangedFiles"]
require(expected_files == sorted(expected_files), "expected changed files must be sorted")
require(len(expected_files) == len(set(expected_files)) == 5, "expected exactly five unique changed files")
require(all(path.startswith("internal/storage/") for path in expected_files), "fix escapes storage packages")

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
require("4912" in scope["retireWhen"], "retirement trigger must name the upstream fix")

print("Beads history-reader lock passed")
