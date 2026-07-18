#!/usr/bin/env python3
"""Normalize SDK-034 maps and build deterministic production/debug packages."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
STABLE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+\-]{0,255}$")
GENES_COMMIT = "c59ecb361fd91418584487c2138bae8d3d3a3961"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def require_safe_path(value: str) -> str:
    path = PurePosixPath(value)
    if (
        not value
        or value.endswith("/")
        or "//" in value
        or path.is_absolute()
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
        or any(ord(character) < 32 or ord(character) == 127 for character in value)
    ):
        raise ValueError(f"unsafe logical path: {value}")
    return value


def require_stable_id(value: str) -> str:
    if not STABLE_ID.fullmatch(value):
        raise ValueError(f"unsafe stable ID: {value}")
    return value


def within(root: Path, candidate: Path) -> bool:
    try:
        candidate.relative_to(root)
        return True
    except ValueError:
        return False


def read_utf8(path: Path) -> bytes:
    data = path.read_bytes()
    data.decode("utf-8")
    if b"\x00" in data:
        raise ValueError(f"NUL byte in {path}")
    return data


def decode_vlq(value: str, offset: int) -> tuple[int, int]:
    accumulated = 0
    shift = 0
    while True:
        if offset >= len(value):
            raise ValueError("unterminated Source Map VLQ")
        digit = BASE64.find(value[offset])
        if digit < 0:
            raise ValueError("non-base64 Source Map VLQ digit")
        offset += 1
        accumulated += (digit & 31) << shift
        shift += 5
        if shift > 35 or accumulated > 2_147_483_647:
            raise ValueError("Source Map VLQ exceeds supported integer range")
        if not digit & 32:
            break
    magnitude = accumulated >> 1
    return (-magnitude if accumulated & 1 else magnitude), offset


def encode_vlq(value: int) -> str:
    encoded = ((-value) << 1 | 1) if value < 0 else value << 1
    output: list[str] = []
    while True:
        digit = encoded & 31
        encoded >>= 5
        if encoded:
            digit |= 32
        output.append(BASE64[digit])
        if not encoded:
            return "".join(output)


def decode_segment(value: str) -> list[int]:
    if not value:
        raise ValueError("empty Source Map segment")
    output: list[int] = []
    offset = 0
    while offset < len(value):
        decoded, offset = decode_vlq(value, offset)
        output.append(decoded)
    if len(output) not in {1, 4, 5}:
        raise ValueError("unsupported Source Map segment field count")
    if output[0] < 0:
        raise ValueError("negative Source Map generated-column delta")
    return output


def referenced_source_indexes(mappings: str, source_count: int) -> set[int]:
    previous_source = 0
    referenced: set[int] = set()
    for line in mappings.split(";"):
        for segment in line.split(",") if line else ():
            fields = decode_segment(segment)
            if len(fields) > 1:
                previous_source += fields[1]
                if not 0 <= previous_source < source_count:
                    raise ValueError("Source Map segment references an unknown source")
                referenced.add(previous_source)
    if not referenced:
        raise ValueError("Source Map has no mapped segments")
    return referenced


def remap_sources(mappings: str, old_to_new: list[int]) -> str:
    if not mappings:
        raise ValueError("empty Source Map mappings")
    previous_old_source = 0
    previous_new_source = 0
    mapped = 0
    referenced: set[int] = set()
    output_lines: list[str] = []
    for line in mappings.split(";"):
        output_segments: list[str] = []
        for segment in line.split(",") if line else ():
            fields = decode_segment(segment)
            if len(fields) > 1:
                previous_old_source += fields[1]
                if not 0 <= previous_old_source < len(old_to_new):
                    raise ValueError("Source Map segment references an unknown source")
                new_source = old_to_new[previous_old_source]
                if new_source < 0:
                    raise ValueError("Source Map used a source removed as unreferenced")
                fields[1] = new_source - previous_new_source
                previous_new_source = new_source
                referenced.add(new_source)
                mapped += 1
            output_segments.append("".join(encode_vlq(field) for field in fields))
        output_lines.append(",".join(output_segments))
    if not mapped:
        raise ValueError("Source Map has no mapped segments")
    if referenced != {value for value in old_to_new if value >= 0}:
        raise ValueError("normalized Source Map retains an unreferenced source")
    return ";".join(output_lines)


class PackageBuilder:
    def __init__(
        self,
        generated_root: Path,
        bundle_root: Path,
        output_root: Path,
        genes_root: Path,
        haxe_stdlib_root: Path,
    ) -> None:
        self.generated_root = generated_root.resolve(strict=True)
        self.bundle_root = bundle_root.resolve(strict=True)
        self.output_root = output_root.resolve()
        self.genes_root = genes_root.resolve(strict=True)
        self.haxe_stdlib_root = haxe_stdlib_root.resolve(strict=True)
        self.records: dict[str, dict[str, object]] = {}
        self.source_records: dict[tuple[str, str], dict[str, object]] = {}
        self.artifact_bytes: dict[str, bytes] = {}
        self.map_sources: dict[str, list[str]] = {}

        if self.output_root.exists() and any(self.output_root.iterdir()):
            raise ValueError(f"output root is not empty: {self.output_root}")
        self.output_root.mkdir(parents=True, exist_ok=True)

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
        require_safe_path(logical_path)
        if file_id in self.records:
            existing = self.records[file_id]
            if existing["path"] != logical_path or existing["sha256"] != digest(data):
                raise ValueError(f"file ID collision: {file_id}")
            return existing
        if any(record["path"] == logical_path for record in self.records.values()):
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
        self.records[file_id] = record
        if source_identity is None:
            self.artifact_bytes[logical_path] = data
        return record

    def add_source(
        self, root_id: str, logical_source_path: str, source_path: Path
    ) -> dict[str, object]:
        logical_source_path = require_safe_path(logical_source_path)
        key = (root_id, logical_source_path)
        data = read_utf8(source_path)
        if key in self.source_records:
            record = self.source_records[key]
            if record["sha256"] != digest(data):
                raise ValueError(f"source identity changed during packaging: {key}")
            return record
        identity_hash = digest(f"{root_id}\0{logical_source_path}".encode())[:24]
        record = self.add_record(
            file_id=f"file:source:{root_id}:{identity_hash}",
            logical_path=f"sources/{root_id}/{logical_source_path}",
            role="source",
            language="haxe",
            distribution="external",
            data=data,
            source_identity={"rootId": root_id, "path": logical_source_path},
        )
        self.source_records[key] = record
        return record

    def classify_haxe_path(self, source_path: Path) -> dict[str, object]:
        resolved = source_path.resolve(strict=True)
        if within(REPOSITORY_ROOT, resolved):
            return self.add_source(
                "project", resolved.relative_to(REPOSITORY_ROOT).as_posix(), resolved
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
        raise ValueError(f"Source Map references an unadmitted Haxe root: {source_path}")

    def classify_composed_source(self, source_reference: str) -> dict[str, object]:
        if (
            not source_reference
            or source_reference.startswith("/")
            or "\\" in source_reference
            or ":" in source_reference
        ):
            raise ValueError(f"unsafe composed source reference: {source_reference}")
        normalized = posixpath.normpath(source_reference)
        genes_marker = (
            f"haxe/haxe_libraries/genes-ts/1.36.3/github/{GENES_COMMIT}/src/"
        )
        stdlib_marker = "haxe/versions/4.3.7/std/"
        if genes_marker in normalized:
            logical = normalized.split(genes_marker, 1)[1]
            return self.classify_haxe_path(self.genes_root / logical)
        if stdlib_marker in normalized:
            logical = normalized.split(stdlib_marker, 1)[1]
            return self.classify_haxe_path(self.haxe_stdlib_root / logical)
        stripped = normalized
        while stripped.startswith("../"):
            stripped = stripped[3:]
        if stripped.startswith("test/"):
            return self.classify_haxe_path(PACKAGE_ROOT / stripped)
        raise ValueError(
            f"composed map source does not match an exact admitted compiler root: {source_reference}"
        )

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
        resolved = (map_path.parent / source_reference).resolve(strict=True)
        return self.classify_haxe_path(resolved)

    def classify_generated_source(
        self, raw_map_path: Path, source_reference: str
    ) -> dict[str, object]:
        if (
            not source_reference
            or source_reference.startswith("/")
            or "\\" in source_reference
            or ":" in source_reference
        ):
            raise ValueError(f"unsafe generated source reference: {source_reference}")
        resolved = (raw_map_path.parent / source_reference).resolve(strict=True)
        two_stage_root = (self.bundle_root / "two-stage-input").resolve(strict=True)
        if not within(two_stage_root, resolved):
            raise ValueError("two-stage bundle map escapes the finalized generated tree")
        relative = resolved.relative_to(two_stage_root).as_posix()
        data = read_utf8(resolved)
        identity_hash = digest(relative.encode())[:24]
        return self.add_record(
            file_id=f"file:generated:typescript:{identity_hash}",
            logical_path=f"generated/{relative}",
            role="generated-source",
            language="typescript",
            distribution="debug-companion",
            data=data,
        )

    def normalize_map(
        self,
        *,
        raw_map_path: Path,
        logical_map_path: str,
        map_file_id: str,
        generated_basename: str,
        classifier,
    ) -> dict[str, object]:
        raw_source = read_utf8(raw_map_path)
        raw = json.loads(raw_source)
        if set(raw) not in (
            {"version", "sources", "mappings", "names"},
            {"version", "file", "sourceRoot", "sources", "mappings", "names"},
        ):
            raise ValueError(f"unsupported regular Source Map shape: {raw_map_path}")
        if raw["version"] != 3 or not isinstance(raw["mappings"], str):
            raise ValueError(f"unsupported Source Map version: {raw_map_path}")
        if "sourceRoot" in raw and raw["sourceRoot"] != "":
            raise ValueError(f"non-empty Source Map sourceRoot: {raw_map_path}")
        if "file" in raw and raw["file"] != generated_basename:
            raise ValueError(f"Source Map generated file mismatch: {raw_map_path}")
        if not isinstance(raw["sources"], list) or not raw["sources"]:
            raise ValueError(f"Source Map has no sources: {raw_map_path}")
        if not isinstance(raw["names"], list) or not all(
            isinstance(name, str) and name for name in raw["names"]
        ):
            raise ValueError(f"Source Map has invalid names: {raw_map_path}")

        referenced_old_sources = referenced_source_indexes(
            raw["mappings"], len(raw["sources"])
        )
        unique_records: list[dict[str, object]] = []
        record_index: dict[str, int] = {}
        old_to_new: list[int] = []
        for source_index, source_reference in enumerate(raw["sources"]):
            if source_index not in referenced_old_sources:
                old_to_new.append(-1)
                continue
            if not isinstance(source_reference, str):
                raise ValueError(f"non-string Source Map source: {raw_map_path}")
            record = classifier(raw_map_path, source_reference)
            file_id = str(record["id"])
            if file_id not in record_index:
                record_index[file_id] = len(unique_records)
                unique_records.append(record)
            old_to_new.append(record_index[file_id])

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
            "mappings": remap_sources(raw["mappings"], old_to_new),
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
        self.map_sources[map_file_id] = [str(value["id"]) for value in unique_records]
        return record

    def copy_runtime(
        self, name: str, distribution: str
    ) -> dict[str, object]:
        data = read_utf8(self.bundle_root / f"{name}.js")
        if b"sourceMappingURL" in data:
            raise ValueError(f"finalized {name} runtime retained a source-map directive")
        return self.add_record(
            file_id=f"file:runtime:browser:{name}",
            logical_path=f"runtime/{name}.js",
            role="runtime",
            language="javascript",
            distribution=distribution,
            data=data,
        )

    def build(self, extract_root: Path | None) -> None:
        development = self.copy_runtime("development", "debug-companion")
        production = self.copy_runtime("production", "production")
        two_stage = self.copy_runtime("two-stage", "debug-companion")

        def composed_classifier(_: Path, reference: str) -> dict[str, object]:
            return self.classify_composed_source(reference)

        development_map = self.normalize_map(
            raw_map_path=self.bundle_root / "development.js.map",
            logical_map_path="maps/development.js.map",
            map_file_id="file:map:browser:development",
            generated_basename="development.js",
            classifier=composed_classifier,
        )
        production_map = self.normalize_map(
            raw_map_path=self.bundle_root / "production.js.map",
            logical_map_path="maps/production.js.map",
            map_file_id="file:map:browser:production",
            generated_basename="production.js",
            classifier=composed_classifier,
        )
        two_stage_map = self.normalize_map(
            raw_map_path=self.bundle_root / "two-stage.js.map",
            logical_map_path="maps/two-stage.js.map",
            map_file_id="file:map:browser:two-stage",
            generated_basename="two-stage.js",
            classifier=lambda map_path, reference: self.classify_generated_source(
                map_path, reference
            ),
        )
        generated_main = next(
            record
            for record in self.records.values()
            if record["path"] == "generated/sdk034/fixture/Main.ts"
        )
        genes_main_map_path = self.generated_root / "sdk034/fixture/Main.ts.map"
        genes_main_map = self.normalize_map(
            raw_map_path=genes_main_map_path,
            logical_map_path="maps/generated-main.ts.map",
            map_file_id="file:map:genes:main",
            generated_basename="Main.ts",
            classifier=lambda map_path, reference: self.classify_genes_source(
                map_path, reference
            ),
        )

        correlations = [
            self.composed_correlation(
                "development", development, development_map
            ),
            self.composed_correlation("production", production, production_map),
            {
                "id": "correlation:browser:two-stage",
                "entryFileId": two_stage["id"],
                "target": "browser",
                "strategy": "browser-two-stage-v3",
                "status": "bounded-local",
                "layers": [
                    {
                        "order": 0,
                        "mapFileId": two_stage_map["id"],
                        "format": "source-map-v3",
                        "generatedFileId": two_stage["id"],
                        "generatedLanguage": "javascript",
                        "sourceLanguage": "typescript",
                        "sourceFileIds": self.map_sources[str(two_stage_map["id"])],
                    },
                    {
                        "order": 1,
                        "mapFileId": genes_main_map["id"],
                        "format": "source-map-v3",
                        "generatedFileId": generated_main["id"],
                        "generatedLanguage": "typescript",
                        "sourceLanguage": "haxe",
                        "sourceFileIds": self.map_sources[str(genes_main_map["id"])],
                    },
                ],
                "proofReceiptIds": ["SDK-034-BROWSER-SOURCE-CORRELATION"],
            },
        ]
        correlations.sort(key=lambda value: str(value["id"]))
        files = sorted(self.records.values(), key=lambda value: str(value["id"]))
        toolchain = json.loads(read_utf8(self.bundle_root / "toolchain.json"))
        build_inputs = {
            "toolchain": toolchain,
            "genes": {"version": "1.36.3", "commit": GENES_COMMIT},
            "fixtureSha256": digest(
                read_utf8(
                    PACKAGE_ROOT
                    / "test/browser-source-correlation/src/sdk034/fixture/Main.hx"
                )
            ),
            "rawArtifacts": {
                path.name: digest(read_utf8(path))
                for path in sorted(self.bundle_root.glob("*.js*"))
            },
        }
        index = {
            "schemaVersion": 1,
            "format": "wordpresshx.source-correlation-index.v1",
            "sdkVersion": "0.0.0+sdk034",
            "buildInputsSha256": digest(canonical(build_inputs)),
            "package": {
                "id": "browser-source-correlation-fixture",
                "version": "0.0.0",
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
        index_bytes = canonical(index) + b"\n"
        self.artifact_bytes["source-index.json"] = index_bytes

        for logical_path, data in sorted(self.artifact_bytes.items()):
            destination = self.output_root.joinpath(
                *PurePosixPath(logical_path).parts
            )
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)

        production_entries = sorted(
            str(record["path"])
            for record in files
            if record["distribution"] == "production"
        )
        debug_entries = sorted(
            ["source-index.json"]
            + [
                str(record["path"])
                for record in files
                if record["distribution"] == "debug-companion"
            ]
        )
        packages_root = self.output_root / "packages"
        production_receipt = write_zip(
            packages_root / "browser-production.zip",
            self.output_root,
            production_entries,
        )
        debug_receipt = write_zip(
            packages_root / "browser-debug-companion.zip",
            self.output_root,
            debug_entries,
        )
        self.verify_retention(production_entries, debug_entries)
        manifest = {
            "schemaVersion": 1,
            "format": "wordpresshx.sdk034-browser-source-correlation-packages.v1",
            "production": production_receipt,
            "debugCompanion": debug_receipt,
            "binding": {
                "productionRuntimeSha256": production["sha256"],
                "productionMapSha256": production_map["sha256"],
                "indexArtifactSetSha256": index["artifactSetSha256"],
                "mapsInProduction": False,
                "sourceContentIncluded": False,
            },
        }
        (packages_root / "package-manifest.json").write_bytes(
            canonical(manifest) + b"\n"
        )
        self.scan_paths()
        if extract_root is not None:
            extract_combined(
                packages_root / "browser-production.zip",
                packages_root / "browser-debug-companion.zip",
                extract_root,
            )
        print(
            "SDK-034 packages passed: production JS only, separate bound maps/index, "
            "no Haxe source content or machine paths"
        )

    def composed_correlation(
        self, name: str, runtime: dict[str, object], source_map: dict[str, object]
    ) -> dict[str, object]:
        return {
            "id": f"correlation:browser:{name}",
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
            "proofReceiptIds": ["SDK-034-BROWSER-SOURCE-CORRELATION"],
        }

    def verify_retention(
        self, production_entries: list[str], debug_entries: list[str]
    ) -> None:
        if production_entries != ["runtime/production.js"]:
            raise ValueError("default production artifact is not exactly one JS runtime")
        if any(
            entry.endswith((".map", ".json", ".hx", ".ts"))
            for entry in production_entries
        ):
            raise ValueError("default production artifact retained debug metadata")
        if "runtime/production.js" in debug_entries:
            raise ValueError("debug companion duplicated the production runtime")
        if any(entry.endswith(".hx") for entry in debug_entries):
            raise ValueError("debug companion retained Haxe source content")

    def scan_paths(self) -> None:
        markers = (
            b"/Us" b"ers/",
            b"/ho" b"me/runner/",
            b"workspace/code",
            b"\\Us" b"ers\\",
        )
        for logical_path, data in self.artifact_bytes.items():
            if any(marker in data for marker in markers):
                raise ValueError(f"machine path leaked into {logical_path}")


def write_zip(destination: Path, source: Path, entries: list[str]) -> dict:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_STORED) as archive:
        for relative in entries:
            require_safe_path(relative)
            data = source.joinpath(*PurePosixPath(relative).parts).read_bytes()
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
                require_safe_path(info.filename)
                target = destination.joinpath(*PurePosixPath(info.filename).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generated-root", type=Path, required=True)
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--genes-root", type=Path, required=True)
    parser.add_argument("--haxe-stdlib-root", type=Path, required=True)
    parser.add_argument("--extract-root", type=Path)
    args = parser.parse_args()
    PackageBuilder(
        args.generated_root,
        args.bundle_root,
        args.output_root,
        args.genes_root,
        args.haxe_stdlib_root,
    ).build(args.extract_root)


if __name__ == "__main__":
    main()
