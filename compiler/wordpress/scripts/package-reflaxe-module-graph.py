#!/usr/bin/env python3
"""Package an authenticated reflaxe.php module graph as a WordPress plugin."""

from __future__ import annotations

import argparse
import hashlib
import json
import stat
import zipfile
from pathlib import Path, PurePosixPath


FIXED_TIME = (1980, 1, 1, 0, 0, 0)
PLUGIN_SLUG = "wordpresshx-reflaxe-module-proof"
PLUGIN_ROOT = f"{PLUGIN_SLUG}/{PLUGIN_SLUG}.php"
APPLICATION_ROOT = f"{PLUGIN_SLUG}/includes/application"
FORBIDDEN_PATH_MARKERS = (b"/Users/", b"/home/", b"workspace/code")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def require_safe_path(value: str) -> None:
    path = PurePosixPath(value)
    require(
        bool(value)
        and not value.endswith("/")
        and "//" not in value
        and not path.is_absolute()
        and "\\" not in value
        and ":" not in value
        and all(part not in {"", ".", ".."} for part in path.parts),
        f"unsafe module-graph path: {value}",
    )


def plugin_root_source() -> bytes:
    return (
        "<?php\n"
        "/**\n"
        " * Plugin Name: WordPressHx reflaxe.php module graph proof\n"
        " * Description: Compiler-owned package-boundary tracer.\n"
        " * Version: 0.0.0\n"
        " * Requires at least: 7.0\n"
        " * Requires PHP: 7.4\n"
        " */\n"
        "if ( ! defined( 'ABSPATH' ) ) {\n"
        "    exit;\n"
        "}\n"
        "require_once __DIR__ . '/includes/application/bootstrap.php';\n"
    ).encode("utf-8")


def load_graph(graph_root: Path) -> tuple[dict, dict[str, bytes]]:
    manifest_path = graph_root / "reflaxe.php-artifacts.json"
    require(manifest_path.is_file(), "reflaxe.php artifact graph is missing")
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    require(
        manifest.get("format") == "reflaxe.php-artifact-graph.v1",
        "unexpected reflaxe.php artifact graph format",
    )
    require(
        manifest.get("profile")
        == {
            "id": "php74-modern-v1",
            "minimumPhpVersionId": 70400,
            "nativeIntTypes": True,
            "strictTypes": True,
        },
        "WordPress package requires the exact php74-modern-v1 profile",
    )
    entrypoint = manifest.get("entrypoint")
    require(isinstance(entrypoint, dict), "artifact graph entrypoint is missing")
    require(
        entrypoint.get("path") == "bootstrap.php",
        "artifact graph entrypoint must be bootstrap.php",
    )
    artifacts = manifest.get("artifacts")
    require(isinstance(artifacts, list) and artifacts, "artifact graph has no artifacts")
    artifact_by_path: dict[str, dict] = {}
    module_by_identity: dict[str, dict] = {}
    runtime_files: dict[str, bytes] = {}
    map_paths: set[str] = set()
    for artifact in artifacts:
        require(isinstance(artifact, dict), "artifact graph record is not an object")
        path = artifact.get("path")
        map_path = artifact.get("mapPath")
        require(isinstance(path, str), "artifact path is not text")
        require(isinstance(map_path, str), "artifact map path is not text")
        require_safe_path(path)
        require_safe_path(map_path)
        require(path.endswith(".php"), f"runtime artifact is not PHP: {path}")
        require(map_path == f"{path}.haxe-map.json", f"map path drifted for {path}")
        require(path not in artifact_by_path, f"duplicate artifact path: {path}")
        require(map_path not in map_paths, f"duplicate artifact map: {map_path}")
        php_bytes = (graph_root / path).read_bytes()
        map_bytes = (graph_root / map_path).read_bytes()
        require(artifact.get("sha256") == digest(php_bytes), f"stale PHP digest: {path}")
        require(
            artifact.get("mapSha256") == digest(map_bytes),
            f"stale source-map digest: {map_path}",
        )
        map_document = json.loads(map_bytes)
        require(
            map_document.get("generated", {}).get("path") == path,
            f"source map names a different PHP artifact: {map_path}",
        )
        require(
            map_document.get("generated", {}).get("sha256") == digest(php_bytes),
            f"source map is stale for {path}",
        )
        require(
            not any(marker in php_bytes or marker in map_bytes for marker in FORBIDDEN_PATH_MARKERS),
            f"machine-local path leaked through {path}",
        )
        artifact_by_path[path] = artifact
        runtime_files[path] = php_bytes
        map_paths.add(map_path)
        if artifact.get("kind") == "module":
            identity = artifact.get("identity")
            require(isinstance(identity, str) and identity, "module identity is missing")
            require(identity not in module_by_identity, f"duplicate module identity: {identity}")
            module_by_identity[identity] = artifact
    load_order = manifest.get("loadOrder")
    require(isinstance(load_order, list), "artifact graph load order is missing")
    module_paths = [artifact["path"] for artifact in module_by_identity.values()]
    require(
        len(load_order) == len(set(load_order)) and set(load_order) == set(module_paths),
        "artifact graph module load order drifted",
    )
    load_index = {path: index for index, path in enumerate(load_order)}
    for identity, artifact in module_by_identity.items():
        dependencies = artifact.get("dependencies")
        require(isinstance(dependencies, list), f"module dependencies are missing: {identity}")
        require(
            len(dependencies) == len(set(dependencies)),
            f"duplicate module dependency: {identity}",
        )
        for dependency in dependencies:
            require(
                dependency in module_by_identity,
                f"module dependency is missing from the graph: {dependency}",
            )
            require(
                load_index[module_by_identity[dependency]["path"]]
                < load_index[artifact["path"]],
                f"module dependency loads after its consumer: {identity}",
            )
    require(
        set(artifact_by_path) == set(module_paths) | {"bootstrap.php"},
        "artifact graph contains an unknown runtime role",
    )
    require(
        not any(marker in manifest_bytes for marker in FORBIDDEN_PATH_MARKERS),
        "machine-local path leaked into the artifact graph",
    )
    return manifest, runtime_files


def write_package(graph_root: Path, output_root: Path) -> None:
    manifest, runtime_files = load_graph(graph_root)
    entries: dict[str, bytes] = {PLUGIN_ROOT: plugin_root_source()}
    for path, data in runtime_files.items():
        entries[f"{APPLICATION_ROOT}/{path}"] = data
    for path in entries:
        require_safe_path(path)
    output_root.mkdir(parents=True, exist_ok=True)
    archive_path = output_root / f"{PLUGIN_SLUG}.zip"
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(entries):
            info = zipfile.ZipInfo(path, FIXED_TIME)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, entries[path])
    archive_bytes = archive_path.read_bytes()
    package_manifest = {
        "schemaVersion": 1,
        "format": "wordpresshx.reflaxe-module-package.v1",
        "classification": "compiler-package-boundary-proof",
        "plugin": {
            "slug": PLUGIN_SLUG,
            "rootPath": PLUGIN_ROOT,
            "requiresWordPress": "7.0",
            "requiresPhp": "7.4",
        },
        "sourceGraph": {
            "format": manifest["format"],
            "profileId": manifest["profile"]["id"],
            "entrypointIdentity": manifest["entrypoint"]["identity"],
            "manifestSha256": digest(
                (graph_root / "reflaxe.php-artifacts.json").read_bytes()
            ),
            "loadOrder": manifest["loadOrder"],
        },
        "package": {
            "path": archive_path.name,
            "sha256": digest(archive_bytes),
            "byteLength": len(archive_bytes),
            "entries": [
                {
                    "path": path,
                    "sha256": digest(entries[path]),
                    "byteLength": len(entries[path]),
                }
                for path in sorted(entries)
            ],
            "sourceMapsIncluded": False,
            "machinePathsAllowed": False,
        },
        "claims": {
            "deterministicPackage": True,
            "moduleGraphPreserved": True,
            "wordpressRuntimeCompatibility": "not-claimed",
            "publicationAuthorized": False,
        },
    }
    manifest_path = output_root / "wordpresshx-reflaxe-module-package.json"
    manifest_path.write_bytes(canonical(package_manifest) + b"\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    write_package(args.graph_root, args.output_root)


if __name__ == "__main__":
    main()
