#!/usr/bin/env python3
"""Independently verify the exact G2.4 WordPress source-correlation proof."""

from __future__ import annotations

import hashlib
import json
import posixpath
import re
import runpy
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
EXPECTED_SOURCE = {
    "rootId": "project",
    "path": (
        "packages/gutenberg/test/assets-fixture/src/"
        "sdk033/fixture/EditorPanel.hx"
    ),
    "line": 12,
    "column": 8,
}
EXPECTED_FRAMES = {
    "development": {
        "path": "runtime/development/editor.js",
        "line": 421,
        "column": 11,
    },
    "production": {
        "path": "wordpresshx-sdk033-assets/build/editor.js",
        "line": 1,
        "column": 3000,
    },
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


def safe_path(value: str) -> None:
    path = PurePosixPath(value)
    if (
        not value
        or value.endswith("/")
        or "//" in value
        or path.is_absolute()
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise AssertionError(f"unsafe package path: {value}")


def scan(label: str, data: bytes) -> None:
    forbidden = (
        b"/Us" + b"ers/",
        b"/ho" + b"me/runner/",
        b"/private/" + b"var/",
        b"workspace/" + b"code/",
        b"\\Us" + b"ers\\",
        b"-----BEGIN " + b"PRIVATE KEY-----",
    )
    secret_patterns = (
        re.compile(rb"AKIA[0-9A-Z]{16}"),
        re.compile(rb"gh" + rb"p_[A-Za-z0-9]{20,}"),
        re.compile(rb"sk-[A-Za-z0-9]{20,}"),
    )
    if any(marker in data for marker in forbidden) or any(
        pattern.search(data) for pattern in secret_patterns
    ):
        raise AssertionError(f"{label}: path or private-key material leaked")


def verify_index(evidence: Path) -> tuple[dict, dict[str, dict]]:
    index = read_canonical(evidence / "source-index.json")
    helpers = runpy.run_path(
        str(REPOSITORY_ROOT / "scripts/source-correlation/validate-contracts.py")
    )
    schema = json.loads(
        (REPOSITORY_ROOT / "schemas/source-correlation-index.schema.json").read_text(
            encoding="utf-8"
        )
    )
    helpers["ClosedSchemaValidator"](schema).validate(index)
    if index["package"] != {
        "id": "wordpresshx-sdk033-assets",
        "version": "0.0.0",
        "profileId": "wp70-release",
    }:
        raise AssertionError("G2.4 package identity drifted")
    if index["retention"] != {
        "profile": "production-evidence",
        "indexDistribution": "debug-companion",
        "mapsInProduction": False,
        "inlineMapsInProduction": False,
        "sourceContentPolicy": "omitted",
        "machinePathsAllowed": False,
        "developmentHandler": "disabled",
        "secretScanRequiredForShipping": True,
    }:
        raise AssertionError("G2.4 retention contract drifted")
    files = index["files"]
    if [record["id"] for record in files] != sorted(
        {record["id"] for record in files}
    ):
        raise AssertionError("G2.4 file IDs are not sorted and unique")
    if index["artifactSetSha256"] != digest(canonical(files)):
        raise AssertionError("G2.4 artifact set is stale")
    files_by_id = {record["id"]: record for record in files}
    for record in files:
        if record["distribution"] == "external":
            if record["role"] != "source" or record["language"] != "haxe":
                raise AssertionError("G2.4 external inventory is not Haxe-only")
            continue
        artifact = evidence / record["path"]
        data = artifact.read_bytes()
        data.decode("utf-8")
        if record["sha256"] != digest(data) or record["byteLength"] != len(data):
            raise AssertionError(f"stale G2.4 artifact: {record['id']}")
        scan(record["path"], data)

    expected_correlations = [
        "correlation:browser:wordpress-scripts:development",
        "correlation:browser:wordpress-scripts:production",
    ]
    correlations = index["correlations"]
    if [value["id"] for value in correlations] != expected_correlations:
        raise AssertionError("G2.4 correlation admission drifted")
    for correlation in correlations:
        if (
            correlation["strategy"] != "browser-composed-v3"
            or correlation["status"] != "bounded-local"
            or correlation["proofReceiptIds"]
            != ["G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION"]
            or len(correlation["layers"]) != 1
        ):
            raise AssertionError("G2.4 composed proof shape drifted")
        layer = correlation["layers"][0]
        if (
            layer["generatedLanguage"] != "javascript"
            or layer["sourceLanguage"] != "haxe"
            or layer["generatedFileId"] != correlation["entryFileId"]
        ):
            raise AssertionError("G2.4 layer identity drifted")
        fixture_sources = [
            files_by_id[file_id].get("sourceIdentity")
            for file_id in layer["sourceFileIds"]
            if files_by_id[file_id].get("sourceIdentity", {}).get("path")
            == EXPECTED_SOURCE["path"]
        ]
        if fixture_sources != [
            {"rootId": "project", "path": EXPECTED_SOURCE["path"]}
        ]:
            raise AssertionError("G2.4 layer lost the exact Haxe fixture")
    return index, files_by_id


def verify_maps(evidence: Path, files_by_id: dict[str, dict]) -> None:
    source_map_helpers = runpy.run_path(
        str(REPOSITORY_ROOT / "scripts/source-correlation/source_map_v3.py")
    )
    referenced_source_indexes = source_map_helpers[
        "referenced_source_indexes"
    ]
    expected = {
        "genes-editor-panel.tsx.map": ("EditorPanel.tsx", 6),
        "wordpress-scripts-development.js.map": ("editor.js", 7),
        "wordpress-scripts-production.js.map": ("editor.js", 5),
    }
    map_paths = sorted((evidence / "maps").glob("*.map"))
    if [path.name for path in map_paths] != sorted(expected):
        raise AssertionError("G2.4 normalized map set drifted")
    for map_path in map_paths:
        document = read_canonical(map_path)
        if set(document) != {
            "file",
            "mappings",
            "names",
            "sourceRoot",
            "sources",
            "version",
        }:
            raise AssertionError(f"{map_path.name}: map shape drifted")
        expected_file, expected_source_count = expected[map_path.name]
        if (
            document["version"] != 3
            or document["file"] != expected_file
            or document["sourceRoot"] != ""
            or not document["mappings"]
            or len(document["sources"]) != expected_source_count
            or "sourcesContent" in document
        ):
            raise AssertionError(f"{map_path.name}: normalized map contract drifted")
        if not isinstance(document["names"], list) or not all(
            isinstance(name, str)
            and name
            and all(31 < ord(character) != 127 for character in name)
            for name in document["names"]
        ):
            raise AssertionError(f"{map_path.name}: unsafe Source Map names")
        referenced = referenced_source_indexes(
            document["mappings"],
            len(document["sources"]),
            len(document["names"]),
        )
        if referenced != set(range(len(document["sources"]))):
            raise AssertionError(
                f"{map_path.name}: source inventory is not fully referenced"
            )
        indexed_sources = {
            record["path"]
            for record in files_by_id.values()
            if record["role"] == "source"
            and record["language"] == "haxe"
            and record["distribution"] == "external"
        }
        resolved_sources: set[str] = set()
        for source in document["sources"]:
            if (
                not source
                or source.startswith("/")
                or "\\" in source
                or ":" in source
                or "//" in source
            ):
                raise AssertionError(
                    f"{map_path.name}: unsafe relative source reference"
                )
            resolved = posixpath.normpath(posixpath.join("maps", source))
            safe_path(resolved)
            if resolved not in indexed_sources:
                raise AssertionError(
                    f"{map_path.name}: source is not an indexed external Haxe file"
                )
            if resolved in resolved_sources:
                raise AssertionError(
                    f"{map_path.name}: duplicate resolved source"
                )
            resolved_sources.add(resolved)
            if not source.endswith(".hx"):
                raise AssertionError(
                    f"{map_path.name}: non-Haxe source survived projection"
                )
    map_records = [
        record for record in files_by_id.values() if record["role"] == "source-map"
    ]
    if len(map_records) != 3:
        raise AssertionError("G2.4 source index map inventory drifted")


def verify_zip(
    path: Path, receipt: dict, production: bool
) -> dict[str, bytes]:
    safe_path(receipt["path"])
    if path.name != receipt["path"]:
        raise AssertionError(f"ZIP receipt path does not match {path.name}")
    data = path.read_bytes()
    if receipt["sha256"] != digest(data) or receipt["byteLength"] != len(data):
        raise AssertionError(f"stale ZIP receipt: {path.name}")
    output: dict[str, bytes] = {}
    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        if [info.filename for info in infos] != receipt["entries"]:
            raise AssertionError(f"{path.name}: entry order drifted")
        for info in infos:
            safe_path(info.filename)
            if info.date_time != (1980, 1, 1, 0, 0, 0):
                raise AssertionError(f"{path.name}: nondeterministic timestamp")
            if info.compress_type != zipfile.ZIP_STORED:
                raise AssertionError(f"{path.name}: compression policy drifted")
            if (
                info.create_system != 3
                or info.external_attr >> 16 != stat.S_IFREG | 0o644
            ):
                raise AssertionError(f"{path.name}: file mode policy drifted")
            content = archive.read(info)
            scan(f"{path.name}:{info.filename}", content)
            output[info.filename] = content
    if production:
        forbidden = (".map", ".hx", ".ts", ".tsx")
        if any(
            name.endswith(forbidden) or name.endswith("source-index.json")
            for name in output
        ):
            raise AssertionError("production ZIP retained correlation metadata")
        for name, content in output.items():
            if name.endswith(".js") and b"sourceMappingURL" in content:
                raise AssertionError("production JS retained a map directive")
    elif any(name.endswith(".hx") for name in output):
        raise AssertionError("debug ZIP retained Haxe source content")
    return output


def verify_packages(evidence_package: Path, evidence: Path, index: dict, plan: dict) -> None:
    manifest = read_canonical(evidence_package / "packages/package-manifest.json")
    if set(manifest) != {
        "schemaVersion",
        "format",
        "production",
        "debugCompanion",
        "binding",
    } or manifest["schemaVersion"] != 1 or manifest["format"] != (
        "wordpresshx.g2.4-wordpress-source-correlation-packages.v1"
    ):
        raise AssertionError("G2.4 package manifest format drifted")
    for name in ("production", "debugCompanion"):
        if set(manifest[name]) != {
            "path",
            "sha256",
            "byteLength",
            "entries",
        }:
            raise AssertionError(f"G2.4 {name} ZIP receipt shape drifted")
    if (
        manifest["production"]["path"] != "wordpresshx-sdk033-assets.zip"
        or manifest["debugCompanion"]["path"]
        != "wordpresshx-sdk033-assets-debug-companion.zip"
    ):
        raise AssertionError("G2.4 ZIP identity drifted")
    binding = manifest["binding"]
    if set(binding) != {
        "profileId",
        "adapter",
        "entry",
        "modes",
        "strategy",
        "indexArtifactSetSha256",
        "assetPlanSha256",
        "productionTreeSha256",
        "productionRuntimeSha256",
        "developmentMapSha256",
        "productionMapSha256",
        "genesMapSha256",
        "genesGeneratedSha256",
        "mapsInProduction",
        "sourceContentIncluded",
        "assetEvidence",
        "rawLayers",
    }:
        raise AssertionError("G2.4 package binding shape drifted")
    if (
        binding["profileId"] != "wp70-release"
        or binding["adapter"] != "@wordpress/scripts@31.5.0"
        or binding["entry"] != "src/editor.tsx"
        or binding["modes"] != ["development", "production"]
        or binding["strategy"] != "browser-composed-v3"
        or binding["mapsInProduction"]
        or binding["sourceContentIncluded"]
        or binding["indexArtifactSetSha256"] != index["artifactSetSha256"]
    ):
        raise AssertionError("G2.4 package binding drifted")
    raw_layers = binding["rawLayers"]
    expected_counts = {
        "file:map:genes:wordpress-scripts-editor-panel": (6, 6, 0),
        "file:map:wordpress-scripts:development": (19, 7, 9),
        "file:map:wordpress-scripts:production": (10, 5, 0),
    }
    if set(raw_layers) != set(expected_counts):
        raise AssertionError("G2.4 raw layer inventory drifted")
    for layer_id, counts in expected_counts.items():
        layer = raw_layers[layer_id]
        if (
            (
                layer["rawSourceCount"],
                layer["haxeSourceCount"],
                layer["embeddedHaxeSourceContentVerified"],
            )
            != counts
            or layer["sourcesContentRemoved"] is not True
        ):
            raise AssertionError(f"{layer_id}: raw layer proof drifted")
    production = verify_zip(
        evidence_package / "packages" / manifest["production"]["path"],
        manifest["production"],
        True,
    )
    debug = verify_zip(
        evidence_package / "packages" / manifest["debugCompanion"]["path"],
        manifest["debugCompanion"],
        False,
    )
    expected_production = [
        "wordpresshx-sdk033-assets/build/editor.asset.php",
        "wordpresshx-sdk033-assets/build/editor.js",
        "wordpresshx-sdk033-assets/generation-manifest.json",
        (
            "wordpresshx-sdk033-assets/languages/"
            "wordpresshx-sdk033-en_US-wordpresshx-sdk033-editor.json"
        ),
        "wordpresshx-sdk033-assets/wordpresshx-sdk033-assets.php",
    ]
    if sorted(production) != expected_production:
        raise AssertionError("installable WordPress production ZIP shape drifted")
    expected_debug = {
        "generated/sdk033/fixture/EditorPanel.tsx",
        "maps/genes-editor-panel.tsx.map",
        "maps/wordpress-scripts-development.js.map",
        "maps/wordpress-scripts-production.js.map",
        "runtime/development/editor.js",
        "source-index.json",
    }
    if set(debug) != expected_debug:
        raise AssertionError("G2.4 debug companion shape drifted")
    production_js = production[
        "wordpresshx-sdk033-assets/build/editor.js"
    ]
    if digest(production_js) != plan["script"]["productionBundleSha256"]:
        raise AssertionError("production ZIP changed SDK-033 final JS bytes")
    if production_js != (
        evidence / "wordpresshx-sdk033-assets/build/editor.js"
    ).read_bytes():
        raise AssertionError("combined extraction changed production JS bytes")
    if debug["source-index.json"] != (evidence / "source-index.json").read_bytes():
        raise AssertionError("combined extraction changed the source index")
    if binding["assetEvidence"] != {
        "assetPhpSha256": digest(
            production[
                "wordpresshx-sdk033-assets/build/editor.asset.php"
            ]
        ),
        "externalizedReportSha256": (
            "4b7f8e017b2c027d52dc6809d7744984e29d9e7d9871c5fa3dbcc0d75964498c"
        ),
        "dependencies": [
            "react-jsx-runtime",
            "wp-components",
            "wp-element",
            "wp-i18n",
        ],
        "productionVersion": plan["script"]["productionVersion"],
    }:
        raise AssertionError("SDK-033 dependency/asset evidence drifted")


def verify_browser(browser: Path) -> None:
    receipt = read_canonical(browser / "browser-receipt.json")
    platform = receipt["runtimePlatform"]
    if (
        receipt["check"] != "wordpresshx-g2.4-real-browser-v1"
        or receipt["engine"] != "chromium"
        or receipt["playwright"] != "1.58.2"
        or receipt["browserVersion"] != EXPECTED_BROWSER_VERSIONS.get(platform)
        or receipt["host"] != "127.0.0.1"
        or receipt["port"] != 41735
    ):
        raise AssertionError("G2.4 browser runtime identity drifted")
    failures = receipt["failures"]
    if [failure["mode"] for failure in failures] != [
        "development",
        "production",
    ] or not all(failure["replayStable"] is True for failure in failures):
        raise AssertionError("G2.4 browser replay evidence drifted")
    for mode, expected_frame in EXPECTED_FRAMES.items():
        stack = (browser / f"{mode}.stack").read_text(encoding="utf-8")
        if (
            "G24_WORDPRESS_SCRIPTS_SOURCE_CORRELATION_FAILURE" not in stack
            or f"/{expected_frame['path']}:{expected_frame['line']}:{expected_frame['column']}"
            not in stack
        ):
            raise AssertionError(f"{mode}: native browser position drifted")
        result = read_canonical(browser / f"{mode}.json")
        correlated = [
            frame
            for frame in result["frames"]
            if frame["status"] == "mapped-composed"
        ]
        if len(correlated) != 1:
            raise AssertionError(f"{mode}: expected one composed Haxe frame")
        frame = correlated[0]
        if frame["correlated"]["source"] != EXPECTED_SOURCE:
            raise AssertionError(f"{mode}: Haxe correlation drifted")
        if frame["frame"] != {
            "url": f"http://127.0.0.1:41735/{expected_frame['path']}",
            **expected_frame,
        }:
            raise AssertionError(f"{mode}: authenticated runtime frame drifted")
        if len(frame["correlated"]["layers"]) != 1:
            raise AssertionError(f"{mode}: composed result gained an extra layer")


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: verify-source-correlation.py "
            "<package-root> <combined-evidence> <browser-output> <asset-plan>"
        )
    evidence_package = Path(sys.argv[1]).resolve(strict=True)
    evidence = Path(sys.argv[2]).resolve(strict=True)
    browser = Path(sys.argv[3]).resolve(strict=True)
    plan = json.loads(Path(sys.argv[4]).read_text(encoding="utf-8"))
    index, files_by_id = verify_index(evidence)
    verify_maps(evidence, files_by_id)
    verify_packages(evidence_package, evidence, index, plan)
    verify_browser(browser)
    package_manifest_path = evidence_package / "packages/package-manifest.json"
    package_manifest = read_canonical(package_manifest_path)
    browser_receipt_path = browser / "browser-receipt.json"
    browser_receipt = read_canonical(browser_receipt_path)
    summary = {
        "artifactSetSha256": index["artifactSetSha256"],
        "browserReceiptSha256": digest(browser_receipt_path.read_bytes()),
        "debugCompanionZipSha256": package_manifest["debugCompanion"][
            "sha256"
        ],
        "developmentStackSha256": digest(
            (browser / "development.stack").read_bytes()
        ),
        "developmentTraceJsonSha256": digest(
            (browser / "development.json").read_bytes()
        ),
        "packageManifestSha256": digest(package_manifest_path.read_bytes()),
        "productionStackSha256": digest(
            (browser / "production.stack").read_bytes()
        ),
        "productionTraceJsonSha256": digest(
            (browser / "production.json").read_bytes()
        ),
        "productionZipSha256": package_manifest["production"]["sha256"],
        "runtimePlatform": browser_receipt["runtimePlatform"],
        "sourceIndexSha256": digest((evidence / "source-index.json").read_bytes()),
    }
    print("G2.4_EVIDENCE_SUMMARY=" + canonical(summary).decode("utf-8"))
    print(
        "G2.4 verification passed: exact @wordpress/scripts development and "
        "minified Chromium throws map to EditorPanel.hx:12:8; production ZIP "
        "retains native assets and excludes maps/source content"
    )


if __name__ == "__main__":
    main()
