#!/usr/bin/env python3
"""Package the exact WordPress bundle with authenticated Haxe correlation."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import posixpath
import re
import shutil
import stat
import zipfile
from pathlib import Path, PurePosixPath


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
TOOLS_PATH = (
    REPOSITORY_ROOT
    / "scripts/source-correlation/source_map_v3.py"
)
TOOLS_SPEC = importlib.util.spec_from_file_location(
    "wordpresshx_source_map_v3", TOOLS_PATH
)
if TOOLS_SPEC is None or TOOLS_SPEC.loader is None:
    raise RuntimeError("unable to load shared Source Map v3 helpers")
TOOLS = importlib.util.module_from_spec(TOOLS_SPEC)
TOOLS_SPEC.loader.exec_module(TOOLS)

canonical = TOOLS.canonical
digest = TOOLS.digest
project_mappings = TOOLS.project_mappings
referenced_source_indexes = TOOLS.referenced_source_indexes
safe_logical_path = TOOLS.safe_logical_path

FIXED_TIME = (1980, 1, 1, 0, 0, 0)
STABLE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+\-]{0,255}$")
GENES_COMMIT = "c59ecb361fd91418584487c2138bae8d3d3a3961"
GENES_VERSION = "1.36.3"
PROOF_RECEIPT = "G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION"
WEBPACK_PREFIX = "webpack://@wordpress-hx/sdk-033-build-tooling/"


def require_stable_id(value: str) -> str:
    if not STABLE_ID.fullmatch(value):
        raise ValueError(f"unsafe stable ID: {value}")
    return value


def read_utf8(path: Path) -> bytes:
    data = path.read_bytes()
    data.decode("utf-8")
    if b"\x00" in data:
        raise ValueError(f"NUL byte in {path}")
    return data


def within(root: Path, candidate: Path) -> bool:
    try:
        candidate.relative_to(root)
        return True
    except ValueError:
        return False


def safe_join(root: Path, relative: str) -> Path:
    safe_logical_path(relative)
    candidate = root.joinpath(*PurePosixPath(relative).parts).resolve()
    if not within(root.resolve(), candidate):
        raise ValueError(f"logical path escapes output root: {relative}")
    return candidate


def write_zip(destination: Path, root: Path, entries: list[str]) -> dict:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        destination, "w", compression=zipfile.ZIP_STORED
    ) as archive:
        for relative in entries:
            safe_logical_path(relative)
            data = safe_join(root, relative).read_bytes()
            info = zipfile.ZipInfo(relative, FIXED_TIME)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, data)
    data = destination.read_bytes()
    return {
        "path": destination.name,
        "sha256": digest(data),
        "byteLength": len(data),
        "entries": entries,
    }


def extract_combined(
    production_zip: Path, debug_zip: Path, destination: Path
) -> None:
    if destination.exists() and any(destination.iterdir()):
        raise ValueError(f"combined extraction root is not empty: {destination}")
    destination.mkdir(parents=True, exist_ok=True)
    for archive_path in (production_zip, debug_zip):
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                safe_logical_path(info.filename)
                target = safe_join(destination, info.filename)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))


class PackageBuilder:
    def __init__(
        self,
        generated_root: Path,
        development_root: Path,
        production_root: Path,
        plugin_root: Path,
        plan_path: Path,
        output_root: Path,
        genes_root: Path,
        haxe_stdlib_root: Path,
    ) -> None:
        self.generated_root = generated_root.resolve(strict=True)
        self.development_root = development_root.resolve(strict=True)
        self.production_root = production_root.resolve(strict=True)
        self.plugin_root = plugin_root.resolve(strict=True)
        self.plan_path = plan_path.resolve(strict=True)
        self.output_root = output_root.resolve()
        self.genes_root = genes_root.resolve(strict=True)
        self.haxe_stdlib_root = haxe_stdlib_root.resolve(strict=True)
        self.plan = json.loads(read_utf8(self.plan_path))
        self.records: dict[str, dict[str, object]] = {}
        self.records_by_path: dict[str, dict[str, object]] = {}
        self.source_records: dict[tuple[str, str], dict[str, object]] = {}
        self.source_bytes: dict[str, bytes] = {}
        self.artifact_bytes: dict[str, bytes] = {}
        self.map_sources: dict[str, list[str]] = {}
        self.raw_layer_evidence: dict[str, dict[str, object]] = {}

        if self.output_root.exists() and any(self.output_root.iterdir()):
            raise ValueError(f"output root is not empty: {self.output_root}")
        self.output_root.mkdir(parents=True, exist_ok=True)
        self.validate_plan()

    def validate_plan(self) -> None:
        if not isinstance(self.plan, dict):
            raise ValueError("SDK-033 asset plan is not an object")
        expected = {
            "schemaVersion",
            "profileId",
            "entryId",
            "plugin",
            "source",
            "script",
            "translations",
            "lanes",
            "nativePlan",
            "authority",
        }
        if set(self.plan) != expected:
            raise ValueError("SDK-033 asset plan fields drifted")
        if (
            self.plan["schemaVersion"] != 1
            or self.plan["profileId"] != "wp70-release"
            or self.plan["entryId"] != "wordpresshx-sdk033-editor"
        ):
            raise ValueError("SDK-033 asset plan identity drifted")
        plugin = self.plan["plugin"]
        script = self.plan["script"]
        if not isinstance(plugin, dict) or not isinstance(script, dict):
            raise ValueError("SDK-033 plan plugin/script shape drifted")
        if plugin.get("slug") != "wordpresshx-sdk033-assets":
            raise ValueError("SDK-033 plugin slug drifted")
        if (
            script.get("filename") != "editor.js"
            or script.get("assetMetadataFilename") != "editor.asset.php"
        ):
            raise ValueError("SDK-033 final script identity drifted")

    def add_record(
        self,
        *,
        file_id: str,
        logical_path: str,
        role: str,
        language: str,
        distribution: str,
        data: bytes,
        source_identity: dict[str, str] | None = None,
    ) -> dict[str, object]:
        require_stable_id(file_id)
        safe_logical_path(logical_path)
        if file_id in self.records:
            existing = self.records[file_id]
            if (
                existing["path"] != logical_path
                or existing["sha256"] != digest(data)
            ):
                raise ValueError(f"file ID collision: {file_id}")
            return existing
        if logical_path in self.records_by_path:
            raise ValueError(f"logical file path collision: {logical_path}")
        record: dict[str, object] = {
            "id": file_id,
            "path": logical_path,
            "role": role,
            "language": language,
            "sha256": digest(data),
            "byteLength": len(data),
            "distribution": distribution,
        }
        if source_identity is not None:
            record["sourceIdentity"] = source_identity
        else:
            existing_bytes = self.artifact_bytes.get(logical_path)
            if existing_bytes is not None and existing_bytes != data:
                raise ValueError(f"artifact byte collision: {logical_path}")
            self.artifact_bytes[logical_path] = data
        self.records[file_id] = record
        self.records_by_path[logical_path] = record
        return record

    def add_source(
        self, root_id: str, logical_source_path: str, source_path: Path
    ) -> dict[str, object]:
        logical_source_path = safe_logical_path(logical_source_path)
        key = (root_id, logical_source_path)
        data = read_utf8(source_path)
        if key in self.source_records:
            record = self.source_records[key]
            if record["sha256"] != digest(data):
                raise ValueError(f"source identity changed during build: {key}")
            return record
        identity_hash = digest(f"{root_id}\0{logical_source_path}".encode())[:24]
        record = self.add_record(
            file_id=f"file:source:haxe:{root_id}:{identity_hash}",
            logical_path=f"sources/{root_id}/{logical_source_path}",
            role="source",
            language="haxe",
            distribution="external",
            data=data,
            source_identity={"rootId": root_id, "path": logical_source_path},
        )
        self.source_records[key] = record
        self.source_bytes[str(record["id"])] = data
        return record

    def classify_haxe_path(self, source_path: Path) -> dict[str, object]:
        resolved = source_path.resolve(strict=True)
        if within(REPOSITORY_ROOT, resolved):
            return self.add_source(
                "project",
                resolved.relative_to(REPOSITORY_ROOT).as_posix(),
                resolved,
            )
        if within(self.genes_root, resolved):
            return self.add_source(
                "genes", resolved.relative_to(self.genes_root).as_posix(), resolved
            )
        if within(self.haxe_stdlib_root, resolved):
            return self.add_source(
                "haxe-stdlib",
                resolved.relative_to(self.haxe_stdlib_root).as_posix(),
                resolved,
            )
        raise ValueError(f"map references an unadmitted Haxe root: {source_path}")

    def classify_genes_source(
        self, map_path: Path, source_reference: str
    ) -> dict[str, object]:
        if (
            not source_reference
            or source_reference.startswith("/")
            or "\\" in source_reference
            or ":" in source_reference
        ):
            raise ValueError(f"unsafe Genes source reference: {source_reference}")
        return self.classify_haxe_path(
            (map_path.parent / source_reference).resolve(strict=True)
        )

    def classify_webpack_source(
        self, _map_path: Path, source_reference: str
    ) -> dict[str, object] | None:
        if (
            not isinstance(source_reference, str)
            or not source_reference.startswith(WEBPACK_PREFIX)
            or "\\" in source_reference
            or any(
                ord(character) < 32 or ord(character) == 127
                for character in source_reference
            )
        ):
            raise ValueError(f"unsafe or foreign Webpack source: {source_reference}")
        payload = posixpath.normpath(source_reference[len(WEBPACK_PREFIX) :])
        genes_marker = (
            f"haxe/haxe_libraries/genes-ts/{GENES_VERSION}/github/"
            f"{GENES_COMMIT}/src/"
        )
        stdlib_marker = "haxe/versions/4.3.7/std/"
        if genes_marker in payload:
            relative = safe_logical_path(payload.split(genes_marker, 1)[1])
            return self.classify_haxe_path(
                self.genes_root / relative
            )
        if stdlib_marker in payload:
            relative = safe_logical_path(payload.split(stdlib_marker, 1)[1])
            return self.classify_haxe_path(
                self.haxe_stdlib_root / relative
            )
        for marker in ("test/assets-fixture/", "src/wordpress/"):
            if marker in payload:
                relative = safe_logical_path(payload.split(marker, 1)[1])
                return self.classify_haxe_path(
                    PACKAGE_ROOT / marker.rstrip("/") / relative
                )
        if source_reference.endswith(".hx"):
            raise ValueError(
                f"Webpack map contains an unclassified Haxe source: {source_reference}"
            )
        return None

    def normalize_map(
        self,
        *,
        raw_map_path: Path,
        logical_map_path: str,
        map_file_id: str,
        generated_basename: str,
        classifier,
        allow_non_haxe: bool,
        require_sources_content: bool,
    ) -> dict[str, object]:
        raw_bytes = read_utf8(raw_map_path)
        raw = json.loads(raw_bytes)
        expected_fields = {
            "version",
            "file",
            "sourceRoot",
            "sources",
            "sourcesContent",
            "names",
            "mappings",
        }
        if not require_sources_content:
            expected_fields.remove("sourcesContent")
        if set(raw) != expected_fields:
            raise ValueError(f"unsupported regular Source Map shape: {raw_map_path}")
        if (
            raw["version"] != 3
            or raw["file"] != generated_basename
            or raw["sourceRoot"] != ""
            or not isinstance(raw["mappings"], str)
            or not isinstance(raw["sources"], list)
            or not raw["sources"]
            or not isinstance(raw["names"], list)
            or not all(
                isinstance(name, str)
                and name
                and all(31 < ord(character) != 127 for character in name)
                for name in raw["names"]
            )
        ):
            raise ValueError(f"invalid regular Source Map v3: {raw_map_path}")
        contents: list[object]
        if require_sources_content:
            contents = raw["sourcesContent"]
            if not isinstance(contents, list) or len(contents) != len(
                raw["sources"]
            ):
                raise ValueError("Webpack sourcesContent inventory drifted")
        else:
            contents = [None] * len(raw["sources"])

        referenced = referenced_source_indexes(
            raw["mappings"], len(raw["sources"]), len(raw["names"])
        )
        records_by_old_index: list[dict[str, object] | None] = []
        embedded_verified = 0
        for index, source_reference in enumerate(raw["sources"]):
            if not isinstance(source_reference, str):
                raise ValueError("Source Map contains a non-string source")
            record = classifier(raw_map_path, source_reference)
            if record is None and not allow_non_haxe:
                raise ValueError(
                    f"Genes map source is not Haxe: {source_reference}"
                )
            if record is not None and contents[index] is not None:
                if not isinstance(contents[index], str):
                    raise ValueError("Source Map sourcesContent value is not text")
                expected_content = self.source_bytes[str(record["id"])].decode(
                    "utf-8"
                )
                if contents[index] != expected_content:
                    raise ValueError(
                        f"embedded source content is stale: {source_reference}"
                    )
                embedded_verified += 1
            records_by_old_index.append(record)

        unique_records: list[dict[str, object]] = []
        record_indexes: dict[str, int] = {}
        old_to_new: list[int | None] = []
        for old_index, record in enumerate(records_by_old_index):
            if old_index not in referenced or record is None:
                old_to_new.append(None)
                continue
            file_id = str(record["id"])
            if file_id not in record_indexes:
                record_indexes[file_id] = len(unique_records)
                unique_records.append(record)
            old_to_new.append(record_indexes[file_id])
        if not unique_records:
            raise ValueError("Source Map projection retained no Haxe sources")

        map_directory = posixpath.dirname(logical_map_path)
        normalized = {
            "version": 3,
            "file": generated_basename,
            "sourceRoot": "",
            "sources": [
                posixpath.relpath(str(record["path"]), map_directory)
                for record in unique_records
            ],
            "names": raw["names"],
            "mappings": project_mappings(raw["mappings"], old_to_new),
        }
        normalized_bytes = canonical(normalized) + b"\n"
        record = self.add_record(
            file_id=map_file_id,
            logical_path=logical_map_path,
            role="source-map",
            language="json",
            distribution="debug-companion",
            data=normalized_bytes,
        )
        self.map_sources[map_file_id] = [
            str(value["id"]) for value in unique_records
        ]
        fixture_id = next(
            (
                str(value["id"])
                for value in unique_records
                if value.get("sourceIdentity")
                == {
                    "rootId": "project",
                    "path": (
                        "packages/gutenberg/test/assets-fixture/src/"
                        "sdk033/fixture/EditorPanel.hx"
                    ),
                }
            ),
            None,
        )
        if fixture_id is None:
            raise ValueError("Source Map lost the exact EditorPanel Haxe source")
        self.raw_layer_evidence[map_file_id] = {
            "rawSha256": digest(raw_bytes),
            "normalizedSha256": digest(normalized_bytes),
            "rawSourceCount": len(raw["sources"]),
            "haxeSourceCount": len(unique_records),
            "embeddedHaxeSourceContentVerified": embedded_verified,
            "sourcesContentRemoved": "sourcesContent" not in normalized,
        }
        return record

    def copy_runtime(
        self,
        *,
        source: Path,
        logical_path: str,
        file_id: str,
        distribution: str,
    ) -> dict[str, object]:
        data = read_utf8(source)
        if b"sourceMappingURL" in data:
            raise ValueError(f"hidden-map runtime retained a map directive: {source}")
        return self.add_record(
            file_id=file_id,
            logical_path=logical_path,
            role="runtime",
            language="javascript",
            distribution=distribution,
            data=data,
        )

    def copy_plugin_tree(self) -> tuple[list[str], str]:
        slug = str(self.plan["plugin"]["slug"])
        entries: list[str] = []
        hash_input = bytearray()
        for source in sorted(self.plugin_root.rglob("*")):
            if source.is_symlink():
                raise ValueError(f"production plugin contains a symlink: {source}")
            if not source.is_file():
                continue
            relative = source.relative_to(self.plugin_root).as_posix()
            logical = safe_logical_path(f"{slug}/{relative}")
            data = source.read_bytes()
            self.scan_content(logical, data)
            self.artifact_bytes[logical] = data
            entries.append(logical)
            hash_input.extend(logical.encode())
            hash_input.extend(b"\0")
            hash_input.extend(data)
            hash_input.extend(b"\0")
        if not entries:
            raise ValueError("production plugin tree is empty")
        return entries, digest(bytes(hash_input))

    def validate_asset_preservation(self, plugin_runtime: bytes) -> dict:
        script = self.plan["script"]
        production_runtime = read_utf8(self.production_root / "editor.js")
        if production_runtime != plugin_runtime:
            raise ValueError("plugin runtime differs from the final production bundle")
        if digest(production_runtime) != script["productionBundleSha256"]:
            raise ValueError("final production bundle contradicts the SDK-033 plan")
        plugin_asset = read_utf8(self.plugin_root / "build/editor.asset.php")
        production_asset = read_utf8(self.production_root / "editor.asset.php")
        if plugin_asset != production_asset:
            raise ValueError("official asset.php bytes changed during packaging")
        development_report = read_utf8(
            self.development_root / "externalized-dependencies.json"
        )
        production_report = read_utf8(
            self.production_root / "externalized-dependencies.json"
        )
        if development_report != production_report:
            raise ValueError("development/production external reports drifted")
        expected_report = canonical(self.plan["lanes"]["production"]["externalizedRequests"])
        if production_report.rstrip(b"\n") != expected_report:
            raise ValueError("externalized dependency report contradicts asset plan")
        return {
            "assetPhpSha256": digest(plugin_asset),
            "externalizedReportSha256": digest(production_report),
            "dependencies": self.plan["script"]["dependencies"],
            "productionVersion": self.plan["script"]["productionVersion"],
        }

    def scan_content(self, logical_path: str, data: bytes) -> None:
        forbidden_paths = (
            b"/Us" + b"ers/",
            b"/ho" + b"me/runner/",
            b"/private/" + b"var/",
            b"workspace/" + b"code/",
            b"\\Us" + b"ers\\",
        )
        secret_patterns = (
            re.compile(rb"AKIA[0-9A-Z]{16}"),
            re.compile(rb"gh" + rb"p_[A-Za-z0-9]{20,}"),
            re.compile(rb"sk-[A-Za-z0-9]{20,}"),
        )
        if any(marker in data for marker in forbidden_paths):
            raise ValueError(f"machine path leaked into {logical_path}")
        if (b"-----BEGIN " + b"PRIVATE KEY-----") in data or any(
            pattern.search(data) for pattern in secret_patterns
        ):
            raise ValueError(f"secret-shaped content leaked into {logical_path}")

    def build(self, extract_root: Path | None) -> None:
        production_entries, production_tree_sha = self.copy_plugin_tree()
        slug = str(self.plan["plugin"]["slug"])
        production_runtime_path = f"{slug}/build/editor.js"
        production_runtime_bytes = self.artifact_bytes[production_runtime_path]
        asset_evidence = self.validate_asset_preservation(
            production_runtime_bytes
        )

        development_runtime = self.copy_runtime(
            source=self.development_root / "editor.js",
            logical_path="runtime/development/editor.js",
            file_id="file:runtime:wordpress-scripts:development",
            distribution="debug-companion",
        )
        production_runtime = self.add_record(
            file_id="file:runtime:wordpress-scripts:production",
            logical_path=production_runtime_path,
            role="runtime",
            language="javascript",
            distribution="production",
            data=production_runtime_bytes,
        )

        generated_path = self.generated_root / "src/sdk033/fixture/EditorPanel.tsx"
        generated_bytes = read_utf8(generated_path)
        directive = b"//# sourceMappingURL=EditorPanel.tsx.map"
        if not generated_bytes.rstrip().endswith(directive):
            raise ValueError("Genes EditorPanel source lost its exact map directive")
        generated_final = generated_bytes[: generated_bytes.rfind(directive)].rstrip() + b"\n"
        generated_record = self.add_record(
            file_id="file:generated:wordpress-scripts:editor-panel-tsx",
            logical_path="generated/sdk033/fixture/EditorPanel.tsx",
            role="generated-source",
            language="tsx",
            distribution="debug-companion",
            data=generated_final,
        )
        genes_map = self.normalize_map(
            raw_map_path=generated_path.with_suffix(".tsx.map"),
            logical_map_path="maps/genes-editor-panel.tsx.map",
            map_file_id="file:map:genes:wordpress-scripts-editor-panel",
            generated_basename="EditorPanel.tsx",
            classifier=self.classify_genes_source,
            allow_non_haxe=False,
            require_sources_content=False,
        )
        development_map = self.normalize_map(
            raw_map_path=self.development_root / "editor.js.map",
            logical_map_path="maps/wordpress-scripts-development.js.map",
            map_file_id="file:map:wordpress-scripts:development",
            generated_basename="editor.js",
            classifier=self.classify_webpack_source,
            allow_non_haxe=True,
            require_sources_content=True,
        )
        production_map = self.normalize_map(
            raw_map_path=self.production_root / "editor.js.map",
            logical_map_path="maps/wordpress-scripts-production.js.map",
            map_file_id="file:map:wordpress-scripts:production",
            generated_basename="editor.js",
            classifier=self.classify_webpack_source,
            allow_non_haxe=True,
            require_sources_content=True,
        )

        def correlation(
            mode: str,
            runtime: dict[str, object],
            source_map: dict[str, object],
        ) -> dict[str, object]:
            return {
                "id": f"correlation:browser:wordpress-scripts:{mode}",
                "entryFileId": runtime["id"],
                "target": "browser",
                "strategy": "browser-composed-v3",
                "status": "bounded-local",
                "layers": [
                    {
                        "order": 0,
                        "mapFileId": source_map["id"],
                        "format": "source-map-v3",
                        "generatedFileId": runtime["id"],
                        "generatedLanguage": "javascript",
                        "sourceLanguage": "haxe",
                        "sourceFileIds": self.map_sources[str(source_map["id"])],
                    }
                ],
                "proofReceiptIds": [PROOF_RECEIPT],
            }

        correlations = sorted(
            [
                correlation("development", development_runtime, development_map),
                correlation("production", production_runtime, production_map),
            ],
            key=lambda value: str(value["id"]),
        )
        files = sorted(self.records.values(), key=lambda value: str(value["id"]))
        build_inputs = {
            "adapter": "@wordpress/scripts@31.5.0",
            "webpack": "5.108.4",
            "profile": "wp70-release",
            "entry": "src/editor.tsx",
            "modes": ["development", "production"],
            "genes": {"version": GENES_VERSION, "commit": GENES_COMMIT},
            "assetPlanSha256": digest(read_utf8(self.plan_path)),
            "webpackConfigSha256": digest(
                read_utf8(PACKAGE_ROOT / "build-tooling/webpack.config.cjs")
            ),
            "haxeProfileSha256": digest(
                read_utf8(PACKAGE_ROOT / "profiles/assets-strict.hxml")
            ),
            "rawLayers": self.raw_layer_evidence,
        }
        index = {
            "schemaVersion": 1,
            "format": "wordpresshx.source-correlation-index.v1",
            "sdkVersion": "0.0.0+g2.4",
            "buildInputsSha256": digest(canonical(build_inputs)),
            "package": {
                "id": slug,
                "version": str(self.plan["plugin"]["version"]),
                "profileId": "wp70-release",
            },
            "retention": {
                "profile": "production-evidence",
                "indexDistribution": "debug-companion",
                "mapsInProduction": False,
                "inlineMapsInProduction": False,
                "sourceContentPolicy": "omitted",
                "machinePathsAllowed": False,
                "developmentHandler": "disabled",
                "secretScanRequiredForShipping": True,
            },
            "sourceRoots": [
                {
                    "id": "genes",
                    "kind": "dependency",
                    "resolution": "cli-root-argument",
                    "contentDistribution": "external",
                },
                {
                    "id": "haxe-stdlib",
                    "kind": "haxe-stdlib",
                    "resolution": "cli-root-argument",
                    "contentDistribution": "external",
                },
                {
                    "id": "project",
                    "kind": "project",
                    "resolution": "cli-root-argument",
                    "contentDistribution": "external",
                },
            ],
            "files": files,
            "artifactSetSha256": digest(canonical(files)),
            "correlations": correlations,
        }
        self.artifact_bytes["source-index.json"] = canonical(index) + b"\n"

        for logical_path, data in sorted(self.artifact_bytes.items()):
            self.scan_content(logical_path, data)
            destination = safe_join(self.output_root, logical_path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)

        debug_entries = sorted(
            ["source-index.json"]
            + [
                str(record["path"])
                for record in files
                if record["distribution"] == "debug-companion"
            ]
        )
        packages_root = self.output_root / "packages"
        production_zip = packages_root / f"{slug}.zip"
        debug_zip = packages_root / f"{slug}-debug-companion.zip"
        production_receipt = write_zip(
            production_zip, self.output_root, production_entries
        )
        debug_receipt = write_zip(debug_zip, self.output_root, debug_entries)
        if any(
            entry.endswith((".map", ".hx", ".ts", ".tsx"))
            or entry.endswith("source-index.json")
            for entry in production_entries
        ):
            raise ValueError("production WordPress ZIP retained debug artifacts")
        if any(entry.endswith(".hx") for entry in debug_entries):
            raise ValueError("debug companion retained Haxe source content")
        if production_runtime_path in debug_entries:
            raise ValueError("debug companion duplicated the production runtime")

        manifest = {
            "schemaVersion": 1,
            "format": "wordpresshx.g2.4-wordpress-source-correlation-packages.v1",
            "production": production_receipt,
            "debugCompanion": debug_receipt,
            "binding": {
                "profileId": "wp70-release",
                "adapter": "@wordpress/scripts@31.5.0",
                "entry": "src/editor.tsx",
                "modes": ["development", "production"],
                "strategy": "browser-composed-v3",
                "indexArtifactSetSha256": index["artifactSetSha256"],
                "assetPlanSha256": digest(read_utf8(self.plan_path)),
                "productionTreeSha256": production_tree_sha,
                "productionRuntimeSha256": production_runtime["sha256"],
                "developmentMapSha256": development_map["sha256"],
                "productionMapSha256": production_map["sha256"],
                "genesMapSha256": genes_map["sha256"],
                "genesGeneratedSha256": generated_record["sha256"],
                "mapsInProduction": False,
                "sourceContentIncluded": False,
                "assetEvidence": asset_evidence,
                "rawLayers": self.raw_layer_evidence,
            },
        }
        (packages_root / "package-manifest.json").write_bytes(
            canonical(manifest) + b"\n"
        )
        if extract_root is not None:
            extract_combined(production_zip, debug_zip, extract_root)
        print(
            "G2.4 packages passed: official WordPress plugin ZIP plus bound "
            "composed maps/index; no maps, Haxe sources, source content, secrets, "
            "or machine paths in production"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated-root", type=Path, required=True)
    parser.add_argument("--development-root", type=Path, required=True)
    parser.add_argument("--production-root", type=Path, required=True)
    parser.add_argument("--plugin-root", type=Path, required=True)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--genes-root", type=Path, required=True)
    parser.add_argument("--haxe-stdlib-root", type=Path, required=True)
    parser.add_argument("--extract-root", type=Path)
    args = parser.parse_args()
    PackageBuilder(
        args.generated_root,
        args.development_root,
        args.production_root,
        args.plugin_root,
        args.plan,
        args.output_root,
        args.genes_root,
        args.haxe_stdlib_root,
    ).build(args.extract_root)


if __name__ == "__main__":
    main()
