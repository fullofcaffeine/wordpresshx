#!/usr/bin/env python3
"""Validate target separation, shared syntax, spans, and committed snapshots."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: verify-snapshots.py "
            "EXPECTED_SERVER EXPECTED_BROWSER ACTUAL_SERVER ACTUAL_BROWSER"
        )

    expected_server, expected_browser, actual_server, actual_browser = map(
        load, sys.argv[1:]
    )
    assert actual_server == expected_server
    assert actual_browser == expected_browser
    assert actual_server["schemaVersion"] == actual_browser["schemaVersion"] == 1
    assert actual_server["target"] == "server"
    assert actual_browser["target"] == "browser"
    assert actual_server["semanticDigest"] == actual_browser["semanticDigest"]
    assert actual_server["rootSpan"] == actual_browser["rootSpan"]
    assert actual_server["entries"] == actual_browser["entries"]
    assert actual_server["entryCount"] == len(actual_server["entries"])

    kinds = {entry["kind"] for entry in actual_server["entries"]}
    assert {
        "attribute",
        "attribute-spread",
        "child-spread",
        "component",
        "element",
        "expression",
        "fragment",
        "if",
        "slot",
    }.issubset(kinds)
    expression_types = {
        entry["type"]
        for entry in actual_server["entries"]
        if entry["kind"] in {"attribute", "expression", "if"}
    }
    assert {"Bool", "Int", "String"}.issubset(expression_types)

    root = actual_server["rootSpan"]
    assert root == {"start": 0, "end": root["end"]}
    assert root["end"] > 0
    for entry in actual_server["entries"]:
        span = entry["span"]
        assert 0 <= span["start"] <= span["end"] <= root["end"], entry
        assert span["end"] > span["start"], entry

    print("SDK-080 server/browser HXX snapshots and source spans passed")


if __name__ == "__main__":
    main()
