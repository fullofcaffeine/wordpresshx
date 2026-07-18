#!/usr/bin/env python3
"""Verify stable PHP trace output without weakening native-frame preservation."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = "compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx"
EXPECTED = {
    "hook": ("fixture:source-correlation:throw:hook", 6),
    "rest": ("fixture:source-correlation:throw:rest", 14),
    "render": ("fixture:source-correlation:throw:render", 18),
    "private": ("fixture:source-correlation:throw:private", 26),
}


def canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def verify_result(stack_path: Path, result_path: Path, mode: str) -> dict[str, object]:
    raw = result_path.read_text(encoding="utf-8")
    result = json.loads(raw)
    if raw != canonical(result) + "\n":
        raise AssertionError(f"{result_path}: JSON output is not canonical")
    if set(result) != {
        "command",
        "frames",
        "packageIdentity",
        "schemaVersion",
        "summary",
    }:
        raise AssertionError(f"{result_path}: result fields changed")
    if result["command"] != "trace php" or result["schemaVersion"] != 1:
        raise AssertionError(f"{result_path}: trace contract identity changed")
    if result["packageIdentity"] != {
        "id": "source-correlation-fixture",
        "profileId": "wp70-release",
        "version": "0.0.0",
    }:
        raise AssertionError(f"{result_path}: package identity changed")

    native_lines = stack_path.read_text(encoding="utf-8").splitlines()
    frames = result["frames"]
    if [frame["native"] for frame in frames] != native_lines:
        raise AssertionError(f"{result_path}: native stack lines were hidden or rewritten")
    mapped = [frame for frame in frames if frame["status"] == "mapped-trace-anchor"]
    if len(mapped) != 1:
        raise AssertionError(f"{result_path}: expected one exact line anchor")
    expected_mapping, expected_line = EXPECTED[mode]
    correlated = mapped[0]["correlated"]
    if correlated["mappingId"] != expected_mapping:
        raise AssertionError(f"{result_path}: mapped the wrong semantic statement")
    if correlated["semanticNodeId"] != expected_mapping:
        raise AssertionError(f"{result_path}: semantic identity changed")
    if correlated["nodeKind"] != "statement":
        raise AssertionError(f"{result_path}: runtime anchor is not a statement")
    source = correlated["source"]
    if source != {
        "rootId": "project",
        "path": SOURCE_PATH,
        "start": {"line": expected_line, "columnUtf8": 2},
        "end": {
            "line": expected_line,
            "columnUtf8": {"hook": 43, "rest": 43, "render": 45, "private": 46}[mode],
        },
    }:
        raise AssertionError(f"{result_path}: logical source range changed: {source!r}")
    if any(value in canonical(correlated) for value in ("/repo", "/Users/", "\\repo")):
        raise AssertionError(f"{result_path}: correlated fields leaked a machine path")

    expected_summary = {
        "mapped-trace-anchor": 1,
        "native-unmapped": 2,
        "unmapped-no-layer": 1,
    }
    if mode == "private":
        expected_summary["unmapped-no-anchor"] = 1
    if result["summary"] != expected_summary:
        raise AssertionError(f"{result_path}: honest partial-coverage summary changed")
    return result


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify-php-trace.py <evidence-root>")
    evidence = Path(sys.argv[1]).resolve()
    results: dict[tuple[str, str], dict[str, object]] = {}
    for profile in ("development", "packaged-evidence"):
        for mode in EXPECTED:
            results[(profile, mode)] = verify_result(
                evidence / "stacks" / f"{profile}-{mode}.stack",
                evidence / "outputs" / f"{profile}-{mode}.json",
                mode,
            )

    for mode in EXPECTED:
        development = results[("development", mode)]
        packaged = results[("packaged-evidence", mode)]
        for result in (development, packaged):
            for frame in result["frames"]:
                frame.pop("native", None)
                if "frame" in frame:
                    frame["frame"].pop("file", None)
        if development != packaged:
            raise AssertionError(f"{mode}: packaged trace semantics differ from development")

    expected_text = (ROOT / "test/expected/private.text").read_text(encoding="utf-8")
    actual_text = (evidence / "outputs/development-private.text").read_text(
        encoding="utf-8"
    )
    if actual_text != expected_text:
        raise AssertionError("private human trace snapshot changed")

    basename = json.loads((evidence / "outputs/basename.json").read_text(encoding="utf-8"))
    statuses = [frame["status"] for frame in basename["frames"]]
    if statuses != ["unmapped-no-layer"]:
        raise AssertionError("basename-only native path was guessed")

    print(
        "PHP trace output passed: 8 native stacks, 8 exact anchors, "
        "2 honest private partial frames, stable text/JSON"
    )


if __name__ == "__main__":
    main()
