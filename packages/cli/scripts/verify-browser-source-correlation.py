#!/usr/bin/env python3
"""Independently verify SDK-034 packages, browser throws, and CLI results."""

from __future__ import annotations

import hashlib
import json
import runpy
import sys
import zipfile
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
EXPECTED_SOURCE = {
    "rootId": "project",
    "path": "packages/cli/test/browser-source-correlation/src/sdk034/fixture/Main.hx",
    "line": 12,
    "column": 8,
}
EXPECTED_FRAME = {
    "development": (319, 11, "mapped-composed"),
    "production": (1, 2976, "mapped-composed"),
    "two-stage": (1, 2976, "mapped-two-stage"),
}
EXPECTED_BROWSER_VERSIONS = {
    "linux/amd64": "145.0.7632.6",
    "linux/arm64": "145.0.7632.0",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def read_canonical(path: Path) -> dict:
    data = path.read_bytes()
    value = json.loads(data)
    if data != canonical(value) + b"\n":
        raise AssertionError(f"{path}: JSON is not canonical")
    return value


def verify_index(evidence: Path) -> dict:
    index = read_canonical(evidence / "source-index.json")
    helpers = runpy.run_path(
        str(
            REPOSITORY_ROOT
            / "scripts/source-correlation/validate-contracts.py"
        )
    )
    schema = json.loads(
        (
            REPOSITORY_ROOT
            / "schemas/source-correlation-index.schema.json"
        ).read_text(encoding="utf-8")
    )
    helpers["ClosedSchemaValidator"](schema).validate(index)
    files = index["files"]
    if [record["id"] for record in files] != sorted(
        {record["id"] for record in files}
    ):
        raise AssertionError("source-index file IDs are not sorted and unique")
    if index["artifactSetSha256"] != digest(canonical(files)):
        raise AssertionError("source-index artifact set is stale")
    files_by_id = {record["id"]: record for record in files}
    for record in files:
        if record["distribution"] == "external":
            if record["role"] != "source" or record["language"] != "haxe":
                raise AssertionError("external inventory contains a non-Haxe source")
            continue
        path = evidence / record["path"]
        data = path.read_bytes()
        data.decode("utf-8")
        if record["sha256"] != digest(data) or record["byteLength"] != len(data):
            raise AssertionError(f"indexed artifact is stale: {record['id']}")

    correlations = index["correlations"]
    if [value["id"] for value in correlations] != sorted(
        value["id"] for value in correlations
    ):
        raise AssertionError("browser correlations are not sorted")
    if [value["strategy"] for value in correlations] != [
        "browser-composed-v3",
        "browser-composed-v3",
        "browser-two-stage-v3",
    ]:
        raise AssertionError("browser strategy admission changed")
    for correlation in correlations:
        if correlation["status"] != "bounded-local" or correlation[
            "proofReceiptIds"
        ] != ["SDK-034-BROWSER-SOURCE-CORRELATION"]:
            raise AssertionError("browser proof identity changed")
        first = correlation["layers"][0]
        if first["generatedFileId"] != correlation["entryFileId"]:
            raise AssertionError("first browser layer lost runtime continuity")
        if files_by_id[first["mapFileId"]]["role"] != "source-map":
            raise AssertionError("browser layer lost its map record")
        if correlation["strategy"] == "browser-two-stage-v3":
            second = correlation["layers"][1]
            if second["generatedFileId"] not in first["sourceFileIds"]:
                raise AssertionError("two-stage intermediate continuity changed")
    return index


def verify_maps(evidence: Path) -> None:
    for map_path in sorted((evidence / "maps").glob("*.map")):
        document = read_canonical(map_path)
        if set(document) != {
            "file",
            "mappings",
            "names",
            "sourceRoot",
            "sources",
            "version",
        }:
            raise AssertionError(f"{map_path.name}: Source Map shape changed")
        if document["version"] != 3 or document["sourceRoot"] != "":
            raise AssertionError(f"{map_path.name}: not regular Source Map v3")
        if not document["mappings"] or not document["sources"]:
            raise AssertionError(f"{map_path.name}: empty map")
        if len(document["sources"]) != len(set(document["sources"])):
            raise AssertionError(f"{map_path.name}: duplicate source identities remain")
        if "sourcesContent" in document:
            raise AssertionError(f"{map_path.name}: source content was retained")
        for source in document["sources"]:
            if source.startswith("/") or "\\" in source or ":" in source:
                raise AssertionError(f"{map_path.name}: unsafe map source {source}")


def verify_packages(evidence: Path, index: dict) -> None:
    manifest = read_canonical(evidence / "packages/package-manifest.json")
    if manifest["binding"]["indexArtifactSetSha256"] != index[
        "artifactSetSha256"
    ]:
        raise AssertionError("package manifest lost source-index binding")
    if manifest["binding"]["mapsInProduction"] or manifest["binding"][
        "sourceContentIncluded"
    ]:
        raise AssertionError("package retention policy changed")
    production_zip = evidence / "packages/browser-production.zip"
    debug_zip = evidence / "packages/browser-debug-companion.zip"
    for receipt, path in (
        (manifest["production"], production_zip),
        (manifest["debugCompanion"], debug_zip),
    ):
        data = path.read_bytes()
        if receipt["sha256"] != digest(data) or receipt["byteLength"] != len(data):
            raise AssertionError(f"package ZIP receipt is stale: {path.name}")
        with zipfile.ZipFile(path) as archive:
            if archive.namelist() != receipt["entries"]:
                raise AssertionError(f"package ZIP entries drifted: {path.name}")
    if manifest["production"]["entries"] != ["runtime/production.js"]:
        raise AssertionError("production ZIP is not JS-only")
    if any(
        entry.endswith((".hx", ".map", ".json"))
        for entry in manifest["production"]["entries"]
    ):
        raise AssertionError("production ZIP retained debug content")
    if any(
        entry.endswith(".hx")
        for entry in manifest["debugCompanion"]["entries"]
    ):
        raise AssertionError("debug companion retained Haxe source")


def verify_browser_and_cli(evidence: Path, browser: Path) -> None:
    receipt = json.loads((browser / "browser-receipt.json").read_text())
    runtime_platform = receipt.get("runtimePlatform")
    if runtime_platform not in EXPECTED_BROWSER_VERSIONS:
        raise AssertionError(
            f"unsupported real-browser runtime platform: {runtime_platform}"
        )
    if receipt != {
        "schemaVersion": 1,
        "engine": "chromium",
        "runtimePlatform": runtime_platform,
        "browserVersion": EXPECTED_BROWSER_VERSIONS[runtime_platform],
        "playwright": "1.58.2",
        "host": "127.0.0.1",
        "port": 41734,
        "failures": [
            {"mode": mode, "stack": f"{mode}.stack", "replayStable": True}
            for mode in EXPECTED_FRAME
        ],
    }:
        raise AssertionError("real-browser receipt changed")

    mapped_sources = []
    for mode, (line, column, status) in EXPECTED_FRAME.items():
        stack_lines = (browser / f"{mode}.stack").read_text().splitlines()
        result = read_canonical(browser / f"{mode}.json")
        if result["command"] != "trace browser" or result["schemaVersion"] != 1:
            raise AssertionError(f"{mode}: browser trace identity changed")
        if [frame["native"] for frame in result["frames"]] != stack_lines:
            raise AssertionError(f"{mode}: native browser frames were rewritten")
        mapped = [frame for frame in result["frames"] if frame["status"] == status]
        if len(mapped) != 1:
            raise AssertionError(f"{mode}: expected one {status} frame")
        frame = mapped[0]
        if frame["frame"] != {
            "url": f"http://127.0.0.1:41734/runtime/{mode}.js",
            "path": f"runtime/{mode}.js",
            "line": line,
            "column": column,
        }:
            raise AssertionError(f"{mode}: parsed runtime frame changed")
        if frame["correlated"]["source"] != EXPECTED_SOURCE:
            raise AssertionError(f"{mode}: Haxe source token changed")
        if frame["correlated"]["correlationId"] != (
            f"correlation:browser:{mode}"
        ):
            raise AssertionError(f"{mode}: wrong browser correlation selected")
        layers = frame["correlated"]["layers"]
        if len(layers) != (2 if mode == "two-stage" else 1):
            raise AssertionError(f"{mode}: correlation layer count changed")
        if mode == "two-stage" and (
            layers[0]["line"],
            layers[0]["column"],
            layers[1]["line"],
            layers[1]["column"],
        ) != (11, 8, 12, 8):
            raise AssertionError("two-stage lookup lost exact intermediate continuity")
        if result["summary"] != {status: 1, "native-unmapped": 1}:
            raise AssertionError(f"{mode}: honest partial summary changed")
        mapped_sources.append(frame["correlated"]["source"])
        expected_text = (
            PACKAGE_ROOT / f"test/expected/browser-{mode}.text"
        ).read_text(encoding="utf-8")
        if (browser / f"{mode}.text").read_text(encoding="utf-8") != expected_text:
            raise AssertionError(f"{mode}: human trace snapshot changed")
    if mapped_sources != [EXPECTED_SOURCE] * 3:
        raise AssertionError("development/production/fallback disagree on Haxe token")

    development = (evidence / "runtime/development.js").read_text()
    production = (evidence / "runtime/production.js").read_text()
    two_stage = (evidence / "runtime/two-stage.js").read_text()
    if development.count("\n") < 20 or production.count("\n") > 1:
        raise AssertionError("development/minified runtime distinction changed")
    if production != two_stage:
        raise AssertionError("two-stage and composed minification changed runtime bytes")
    for value in (development, production, two_stage):
        if "sourceMappingURL" in value:
            raise AssertionError("runtime retained a source-map directive")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: verify-browser-source-correlation.py <evidence-root> <browser-root>"
        )
    evidence = Path(sys.argv[1]).resolve(strict=True)
    browser = Path(sys.argv[2]).resolve(strict=True)
    index = verify_index(evidence)
    verify_maps(evidence)
    verify_packages(evidence, index)
    verify_browser_and_cli(evidence, browser)
    print(
        "SDK-034 evidence passed: 3 real Chromium failures, 2 composed mappings, "
        "1 exact two-stage mapping, deterministic production/debug retention"
    )


if __name__ == "__main__":
    main()
