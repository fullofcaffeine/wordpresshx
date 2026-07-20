#!/usr/bin/env python3
"""Validate the closed Gate G0 product/toolchain baseline and its claim limits."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []

    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def read_json(self, relative: str, label: str) -> dict[str, Any]:
        path = self.root / relative
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self.errors.append(f"cannot read {label} at {relative}: {error}")
            return {}
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be a JSON object")
            return {}
        return value

    def read_text(self, relative: str, label: str) -> str:
        try:
            return (self.root / relative).read_text(encoding="utf-8")
        except OSError as error:
            self.errors.append(f"cannot read {label} at {relative}: {error}")
            return ""

    def sha256(self, relative: str) -> str:
        try:
            return hashlib.sha256((self.root / relative).read_bytes()).hexdigest()
        except OSError as error:
            self.errors.append(f"cannot hash {relative}: {error}")
            return ""

    def exact_keys(self, value: Any, expected: set[str], label: str) -> None:
        if not isinstance(value, dict):
            self.errors.append(f"{label} must be an object")
            return
        actual = set(value)
        if actual != expected:
            self.errors.append(
                f"{label} keys differ: expected {sorted(expected)}, got {sorted(actual)}"
            )


def nested(value: dict[str, Any], *keys: str) -> Any:
    current: Any = value
    for key in keys:
        if not isinstance(current, dict) or key not in current:
            return None
        current = current[key]
    return current


def manifest_paths(root: Path, names: set[str]) -> list[str]:
    ignored = {
        ".beads",
        ".git",
        ".haxelib",
        ".lix",
        "__pycache__",
        "build",
        "node_modules",
        "vendor",
    }
    found: list[str] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.name not in names:
            continue
        relative = path.relative_to(root)
        if any(part in ignored for part in relative.parts):
            continue
        found.append(relative.as_posix())
    return sorted(found)


def validate_subject_hashes(audit: Audit, receipt: dict[str, Any]) -> None:
    subject = receipt.get("subject", {})
    audit.exact_keys(subject, {"toolchainLock", "validator", "tests", "review"}, "G0 receipt subject")
    for name in ("toolchainLock", "validator", "tests", "review"):
        item = subject.get(name, {}) if isinstance(subject, dict) else {}
        audit.exact_keys(item, {"path", "sha256"}, f"G0 receipt subject {name}")
        path = item.get("path")
        digest = item.get("sha256")
        audit.check(isinstance(path, str) and bool(path), f"{name} path must be non-empty")
        audit.check(isinstance(digest, str) and bool(SHA256.fullmatch(digest)), f"{name} SHA-256 must be exact")
        if isinstance(path, str) and isinstance(digest, str):
            audit.check(audit.sha256(path) == digest, f"{name} SHA-256 does not match {path}")


def validate_toolchain(audit: Audit, toolchain: dict[str, Any]) -> None:
    audit.exact_keys(
        toolchain,
        {
            "schemaVersion",
            "lockId",
            "status",
            "authority",
            "scope",
            "compilers",
            "formatters",
            "runtimeImages",
            "dependencyGraphs",
            "profileInputs",
            "policy",
            "claims",
        },
        "toolchain lock",
    )
    audit.check(toolchain.get("schemaVersion") == 1, "toolchain schemaVersion must be 1")
    audit.check(toolchain.get("lockId") == "G0-TOOLCHAIN-BASELINE", "toolchain lockId must be G0-TOOLCHAIN-BASELINE")
    audit.check(toolchain.get("status") == "closed-g0-baseline", "toolchain status must be closed-g0-baseline")
    audit.check(toolchain.get("authority") == "wordpress-hx-sdk", "toolchain authority must be wordpress-hx-sdk")

    compilers = toolchain.get("compilers", {})
    audit.exact_keys(compilers, {"haxe", "genesTs", "reflaxePhp"}, "toolchain compilers")
    haxe = compilers.get("haxe", {}) if isinstance(compilers, dict) else {}
    audit.exact_keys(
        haxe,
        {"version", "repository", "tag", "commit", "tree", "hostedInstaller", "evidenceStatus"},
        "Haxe compiler lock",
    )
    audit.check(haxe.get("version") == "4.3.7", "Haxe compiler must be exactly 4.3.7")
    audit.check(haxe.get("tag") == "4.3.7", "Haxe source tag must be exactly 4.3.7")
    audit.check(haxe.get("commit") == "e0b355c6be312c1b17382603f018cf52522ec651", "Haxe source commit changed")
    audit.check(haxe.get("tree") == "55d2c4c59ed55c52fa0660e2fe385081a94b23d1", "Haxe source tree changed")
    audit.check(bool(SHA1.fullmatch(str(haxe.get("commit", "")))), "Haxe commit must be a full Git object ID")
    installer = haxe.get("hostedInstaller", {})
    audit.exact_keys(installer, {"repository", "version", "commit"}, "Haxe hosted installer")
    audit.check(installer.get("version") == "2.1.0", "setup-haxe version must be 2.1.0")
    audit.check(installer.get("commit") == "d93667502be3b4f31a94a3308a74388f2e178a8d", "setup-haxe commit changed")

    genes = compilers.get("genesTs", {}) if isinstance(compilers, dict) else {}
    audit.exact_keys(
        genes,
        {"version", "repository", "tag", "commit", "tree", "artifactSha256", "receiptId", "evidenceStatus"},
        "Genes compiler lock",
    )
    audit.check(genes.get("version") == "1.33.0", "Genes must be exactly 1.33.0")
    audit.check(genes.get("commit") == "7999b7cff09f78ebb8e09c3db6e221beb141b67b", "Genes commit changed")
    audit.check(genes.get("tree") == "5ec14a28160ae676d24e6092ace8f1d2a4ad6dc5", "Genes tree changed")
    audit.check(genes.get("artifactSha256") == "4bf2d2d1046ee5a99830ef31158a90033bfa521da12eb1d5ecd136b35b4fd145", "Genes release artifact changed")

    php = compilers.get("reflaxePhp", {}) if isinstance(compilers, dict) else {}
    audit.exact_keys(
        php,
        {"version", "path", "originRepository", "originCommit", "originTree", "packageContentSha256", "receiptId", "releaseEligible", "evidenceStatus"},
        "Reflaxe PHP compiler lock",
    )
    audit.check(php.get("version") == "0.0.0", "reflaxe.php must remain internal version 0.0.0")
    audit.check(php.get("path") == "compiler/reflaxe.php", "reflaxe.php path changed")
    audit.check(php.get("originCommit") == "20b9c974f141375b6cf191db6f25b115812e282c", "reflaxe.php origin commit changed")
    audit.check(php.get("originTree") == "1de1d4869f8cea49ebebc9e54295057c62dee011", "reflaxe.php origin tree changed")
    audit.check(php.get("packageContentSha256") == "cf0fc152f4fe09b8a9eb92f6b9f4c1f1591ab938531d6241c245ab11a75532f6", "reflaxe.php package content identity changed")
    audit.check(php.get("releaseEligible") is False, "reflaxe.php must not become release eligible at G0")

    formatters = toolchain.get("formatters", {})
    audit.exact_keys(formatters, {"haxeFormatter"}, "toolchain formatters")
    formatter = formatters.get("haxeFormatter", {}) if isinstance(formatters, dict) else {}
    audit.exact_keys(formatter, {"version", "repository", "commit", "tree", "artifact"}, "Haxe formatter lock")
    audit.check(formatter.get("version") == "1.18.0", "Haxe Formatter must be exactly 1.18.0")
    audit.check(formatter.get("commit") == "93ba289893d515614298f4ce7cee8619c31b420c", "Haxe Formatter commit changed")
    audit.check(nested(formatter, "artifact", "sha256") == "2d29c9b56e54b2643e07ee64003c3fc30a5bc133bdcb4cc15c48f09acda7a047", "Haxe Formatter artifact changed")

    runtime = toolchain.get("runtimeImages", {})
    audit.exact_keys(
        runtime,
        {"lock", "node", "playwright", "php"},
        "runtime image lock projection",
    )
    image_lock_ref = runtime.get("lock", {}) if isinstance(runtime, dict) else {}
    audit.exact_keys(image_lock_ref, {"path", "sha256"}, "runtime image source lock")
    audit.check(image_lock_ref.get("path") == "docker/images.lock.json", "runtime image lock path changed")
    audit.check(audit.sha256("docker/images.lock.json") == image_lock_ref.get("sha256"), "runtime image lock digest changed")
    node = runtime.get("node", {}) if isinstance(runtime, dict) else {}
    audit.exact_keys(node, {"version", "imageKey", "reference", "evidenceStatus"}, "Node runtime lock")
    audit.check(node.get("version") == "22.17.0", "Node runtime must be exactly 22.17.0")
    audit.check(node.get("reference") == "docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0", "Node must use the reviewed digest reference")
    playwright = runtime.get("playwright", {}) if isinstance(runtime, dict) else {}
    audit.exact_keys(
        playwright,
        {
            "version",
            "imageKey",
            "reference",
            "nodeVersion",
            "npmVersion",
            "platforms",
            "evidenceStatus",
        },
        "Playwright runtime lock",
    )
    audit.check(
        playwright.get("version") == "1.58.2",
        "Playwright runtime must be exactly 1.58.2",
    )
    audit.check(
        playwright.get("nodeVersion") == "24.13.0"
        and playwright.get("npmVersion") == "11.6.2"
        and playwright.get("platforms")
        == {
            "linux/amd64": {
                "manifestDigest": (
                    "sha256:65cefd09a5e943921ecd3a6e5414c603"
                    "db2eb161e9eb48f2e2ccc63486dc7dc0"
                ),
                "browserVersion": "145.0.7632.6",
            },
            "linux/arm64": {
                "manifestDigest": (
                    "sha256:68f1c3dca663d0e8331e8af4681b0b3"
                    "15eca7de1bd7fa934aac0accbeb9f8323"
                ),
                "browserVersion": "145.0.7632.0",
            },
        },
        "Playwright runtime-reported Node/npm/platform browser matrix changed",
    )
    audit.check(
        playwright.get("evidenceStatus") == "runtime-tested",
        "Playwright runtime evidence must remain runtime-tested",
    )
    php_images = runtime.get("php", {}) if isinstance(runtime, dict) else {}
    audit.exact_keys(php_images, {"syntaxFloor", "primaryCli", "wordpressRuntime"}, "PHP runtime locks")

    images = audit.read_json("docker/images.lock.json", "Docker image lock").get("images", {})
    for projection_name, expected_key in (
        ("syntaxFloor", "php74Floor"),
        ("primaryCli", "php84Cli"),
        ("wordpressRuntime", "wordpress70Php84"),
    ):
        projection = php_images.get(projection_name, {}) if isinstance(php_images, dict) else {}
        audit.check(projection.get("imageKey") == expected_key, f"{projection_name} image key changed")
        audit.check(projection.get("reference") == nested(images, expected_key, "reference"), f"{projection_name} image projection differs from docker lock")
    audit.check(node.get("reference") == nested(images, "node", "reference"), "Node image projection differs from docker lock")
    audit.check(
        playwright.get("imageKey") == "playwright"
        and playwright.get("reference")
        == nested(images, "playwright", "reference"),
        "Playwright image projection differs from docker lock",
    )

    graphs = toolchain.get("dependencyGraphs", {})
    audit.exact_keys(graphs, {"composer", "npm", "haxelib"}, "dependency graph locks")
    composer = graphs.get("composer", {}) if isinstance(graphs, dict) else {}
    audit.exact_keys(
        composer,
        {
            "status",
            "manifestPaths",
            "lockPaths",
            "lockSha256",
            "composer",
            "activePackages",
            "allowedComposerPlugins",
            "runtimePackages",
            "buildInputOnly",
            "publicationAuthorized",
            "receiptId",
        },
        "Composer graph",
    )
    audit.check(
        composer.get("status")
        == "bounded-build-only-generated-php-validation",
        "Composer graph must remain the admitted SDK-026 build-only graph",
    )
    expected_composer_manifests = ["tooling/php-quality/composer.json"]
    expected_composer_locks = ["tooling/php-quality/composer.lock"]
    audit.check(
        composer.get("manifestPaths") == expected_composer_manifests,
        "Composer manifest inventory changed",
    )
    audit.check(
        composer.get("lockPaths") == expected_composer_locks,
        "Composer lock inventory changed",
    )
    audit.check(
        manifest_paths(audit.root, {"composer.json"})
        == expected_composer_manifests,
        "unlocked Composer manifest found",
    )
    audit.check(
        manifest_paths(audit.root, {"composer.lock"})
        == expected_composer_locks,
        "unlocked Composer lock found",
    )
    audit.check(
        composer.get("lockSha256")
        == audit.sha256("tooling/php-quality/composer.lock"),
        "Composer quality lock SHA-256 changed",
    )
    audit.check(
        composer.get("composer")
        == {
            "version": "2.10.2",
            "artifactUrl": "https://getcomposer.org/download/2.10.2/composer.phar",
            "artifactSha256": "5ee7125f8a30a34d246cefdc0bc85b8a783b28f2aec968994118512350d28027",
        },
        "Composer executable lock changed",
    )
    active_composer_packages = composer.get("activePackages", [])
    active_composer_versions = {
        package.get("name"): package.get("version")
        for package in active_composer_packages
        if isinstance(package, dict)
    }
    audit.check(
        active_composer_versions
        == {
            "dealerdirect/phpcodesniffer-composer-installer": "1.2.1",
            "php-stubs/wordpress-stubs": "7.0.0",
            "phpcompatibility/php-compatibility": "9.3.5",
            "phpcompatibility/phpcompatibility-paragonie": "1.3.4",
            "phpcompatibility/phpcompatibility-wp": "2.1.8",
            "phpcsstandards/phpcsextra": "1.5.0",
            "phpcsstandards/phpcsutils": "1.2.2",
            "phpstan/phpstan": "2.2.5",
            "squizlabs/php_codesniffer": "3.13.5",
            "wp-coding-standards/wpcs": "3.4.0",
        },
        "Composer build package set changed",
    )
    audit.check(
        len(active_composer_packages) == len(active_composer_versions)
        and all(
            isinstance(package.get("sourceReference"), str)
            and bool(SHA1.fullmatch(package["sourceReference"]))
            for package in active_composer_packages
            if isinstance(package, dict)
        ),
        "Composer build packages require exact source references",
    )
    audit.check(
        composer.get("allowedComposerPlugins")
        == ["dealerdirect/phpcodesniffer-composer-installer@1.2.1"],
        "Composer plugin admission changed",
    )
    audit.check(
        composer.get("runtimePackages") == [],
        "Composer runtime package set must remain empty",
    )
    audit.check(
        composer.get("buildInputOnly") is True,
        "Composer quality graph must remain build-input-only",
    )
    audit.check(
        composer.get("publicationAuthorized") is False,
        "Composer quality graph cannot authorize publication",
    )
    audit.check(
        composer.get("receiptId") == "SDK-026-GENERATED-PHP-QUALITY",
        "Composer quality graph authority changed",
    )

    npm = graphs.get("npm", {}) if isinstance(graphs, dict) else {}
    audit.exact_keys(npm, {"status", "rootManifestPaths", "rootLockPaths", "activePackages", "externalGraphs"}, "npm graph")
    audit.check(npm.get("status") == "bounded-build-inputs", "npm graph status changed")
    audit.check(npm.get("rootManifestPaths") == [], "root npm manifests must be absent at G0")
    audit.check(npm.get("rootLockPaths") == [], "root npm locks must be absent at G0")
    external_graphs = npm.get("externalGraphs", [])
    graph_ids = {
        graph.get("id")
        for graph in external_graphs
        if isinstance(graph, dict) and isinstance(graph.get("id"), str)
    }
    audit.check(
        isinstance(external_graphs, list)
        and len(external_graphs) == 7
        and len(graph_ids) == 7,
        "npm external graph set changed",
    )
    graph_by_id = {
        graph["id"]: graph
        for graph in external_graphs
        if isinstance(graph, dict) and isinstance(graph.get("id"), str)
    }
    genes_graph = graph_by_id.get("genes-ts-v1.33.0-release-graph", {})
    sdk031_graph = graph_by_id.get("sdk-031-gutenberg-verification-graph", {})
    sdk032_graph = graph_by_id.get(
        "sdk-032-react-gutenberg-hxx-verification-graph", {}
    )
    sdk033_graph = graph_by_id.get(
        "sdk-033-wordpress-assets-verification-graph", {}
    )
    sdk063_graph = graph_by_id.get(
        "sdk-063-editor-plugin-verification-graph", {}
    )
    sdk034_graph = graph_by_id.get(
        "sdk-034-browser-source-correlation-verification-graph", {}
    )
    sdk025_graph = graph_by_id.get("sdk-025-php-trace-cli-graph", {})
    audit.check(
        genes_graph
        == {
            "id": "genes-ts-v1.33.0-release-graph",
            "authority": "immutable-release-artifact-and-source-manifest-digests",
            "receiptId": "SDK-030-GENES-TS-V1.33.0",
        },
        "Genes external npm graph changed",
    )
    audit.exact_keys(
        sdk031_graph,
        {
            "id",
            "authority",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "directPackages",
            "runtimeImage",
            "buildInputOnly",
            "receiptId",
        },
        "SDK-031 npm graph",
    )
    audit.check(
        sdk031_graph.get("id") == "sdk-031-gutenberg-verification-graph",
        "SDK-031 npm graph ID changed",
    )
    audit.check(
        sdk031_graph.get("authority")
        == "package-local-exact-lock-and-sdk-receipt",
        "SDK-031 npm graph authority changed",
    )
    sdk031_manifest = sdk031_graph.get("manifestPath")
    sdk031_lock = sdk031_graph.get("lockPath")
    audit.check(
        sdk031_manifest == "packages/gutenberg/tooling/package.json",
        "SDK-031 npm manifest path changed",
    )
    audit.check(
        sdk031_lock == "packages/gutenberg/tooling/package-lock.json",
        "SDK-031 npm lock path changed",
    )
    audit.check(
        manifest_paths(audit.root, {"package.json"})
        == sorted(
            [
                "packages/gutenberg/tooling/package.json",
                "packages/gutenberg/hxx-tooling/package.json",
                "packages/gutenberg/build-tooling/package.json",
                "packages/gutenberg/editor-tooling/package.json",
                "packages/cli/package.json",
                "packages/cli/browser-tooling/package.json",
            ]
        ),
        "unlocked package.json found",
    )
    audit.check(
        manifest_paths(
            audit.root,
            {"package-lock.json", "yarn.lock", "pnpm-lock.yaml"},
        )
        == sorted(
            [
                "packages/gutenberg/tooling/package-lock.json",
                "packages/gutenberg/hxx-tooling/package-lock.json",
                "packages/gutenberg/build-tooling/package-lock.json",
                "packages/gutenberg/editor-tooling/package-lock.json",
                "packages/cli/package-lock.json",
                "packages/cli/browser-tooling/package-lock.json",
            ]
        ),
        "unlocked package-manager lock found",
    )
    if isinstance(sdk031_manifest, str):
        audit.check(
            audit.sha256(sdk031_manifest) == sdk031_graph.get("manifestSha256"),
            "SDK-031 npm manifest digest changed",
        )
    if isinstance(sdk031_lock, str):
        audit.check(
            audit.sha256(sdk031_lock) == sdk031_graph.get("lockSha256"),
            "SDK-031 npm lock digest changed",
        )
    audit.check(
        sdk031_graph.get("directPackages")
        == ["esbuild@0.27.2", "typescript@5.9.3"],
        "SDK-031 direct npm package set changed",
    )
    audit.check(
        sdk031_graph.get("runtimeImage") == node.get("reference"),
        "SDK-031 npm runtime image differs from the Node lock",
    )
    audit.check(
        sdk031_graph.get("buildInputOnly") is True,
        "SDK-031 npm graph must remain a build input",
    )
    audit.check(
        sdk031_graph.get("receiptId") == "SDK-031-STRICT-BROWSER-PROFILE",
        "SDK-031 npm graph receipt changed",
    )
    audit.exact_keys(
        sdk032_graph,
        {
            "id",
            "authority",
            "profilePath",
            "profileSha256",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "directPackages",
            "runtimeImage",
            "buildInputOnly",
            "receiptId",
        },
        "SDK-032 npm graph",
    )
    audit.check(
        sdk032_graph.get("id")
        == "sdk-032-react-gutenberg-hxx-verification-graph",
        "SDK-032 npm graph ID changed",
    )
    audit.check(
        sdk032_graph.get("authority")
        == "exact-provider-source-profile-and-package-local-npm-lock",
        "SDK-032 npm graph authority changed",
    )
    sdk032_profile = sdk032_graph.get("profilePath")
    sdk032_manifest = sdk032_graph.get("manifestPath")
    sdk032_lock = sdk032_graph.get("lockPath")
    audit.check(
        sdk032_profile
        == (
            "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
            "wp70-release.browser-hxx.json"
        ),
        "SDK-032 browser-HXX profile path changed",
    )
    audit.check(
        sdk032_manifest == "packages/gutenberg/hxx-tooling/package.json",
        "SDK-032 npm manifest path changed",
    )
    audit.check(
        sdk032_lock == "packages/gutenberg/hxx-tooling/package-lock.json",
        "SDK-032 npm lock path changed",
    )
    for path, digest, label in (
        (sdk032_profile, sdk032_graph.get("profileSha256"), "profile"),
        (sdk032_manifest, sdk032_graph.get("manifestSha256"), "manifest"),
        (sdk032_lock, sdk032_graph.get("lockSha256"), "lock"),
    ):
        if isinstance(path, str):
            audit.check(
                audit.sha256(path) == digest,
                f"SDK-032 {label} digest changed",
            )
    audit.check(
        sdk032_graph.get("directPackages")
        == [
            "@testing-library/dom@10.4.1",
            "@testing-library/user-event@14.6.1",
            "@types/jsdom@21.1.7",
            "@types/node@22.15.30",
            "@types/react@18.3.27",
            "@types/react-dom@18.3.7",
            "@wordpress/components@32.2.0",
            "@wordpress/element@6.40.0",
            "axe-core@4.10.2",
            "esbuild@0.27.2",
            "jsdom@26.1.0",
            "react@18.3.1",
            "react-dom@18.3.1",
            "typescript@5.9.3",
        ],
        "SDK-032 direct npm package set changed",
    )
    audit.check(
        sdk032_graph.get("runtimeImage") == node.get("reference"),
        "SDK-032 npm runtime image differs from the Node lock",
    )
    audit.check(
        sdk032_graph.get("buildInputOnly") is True,
        "SDK-032 npm graph must remain a build input",
    )
    audit.check(
        sdk032_graph.get("receiptId") == "SDK-032-REACT-GUTENBERG-HXX",
        "SDK-032 npm graph receipt changed",
    )
    audit.exact_keys(
        sdk033_graph,
        {
            "id",
            "authority",
            "profilePath",
            "profileSha256",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "directPackages",
            "runtimeImage",
            "browserRuntimeImage",
            "lifecycleScriptsAllowed",
            "buildInputOnly",
            "advisoryFollowUp",
            "sourceCorrelationReceiptId",
            "receiptId",
        },
        "SDK-033 npm graph",
    )
    audit.check(
        sdk033_graph.get("id")
        == "sdk-033-wordpress-assets-verification-graph",
        "SDK-033 npm graph ID changed",
    )
    audit.check(
        sdk033_graph.get("authority")
        == "official-wordpress-build-tool-and-exact-provider-profile-lock",
        "SDK-033 npm graph authority changed",
    )
    sdk033_profile = sdk033_graph.get("profilePath")
    sdk033_manifest = sdk033_graph.get("manifestPath")
    sdk033_lock = sdk033_graph.get("lockPath")
    audit.check(
        sdk033_profile
        == (
            "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
            "wp70-release.browser-assets.json"
        ),
        "SDK-033 browser-assets profile path changed",
    )
    audit.check(
        sdk033_manifest == "packages/gutenberg/build-tooling/package.json",
        "SDK-033 npm manifest path changed",
    )
    audit.check(
        sdk033_lock == "packages/gutenberg/build-tooling/package-lock.json",
        "SDK-033 npm lock path changed",
    )
    for path, digest, label in (
        (sdk033_profile, sdk033_graph.get("profileSha256"), "profile"),
        (sdk033_manifest, sdk033_graph.get("manifestSha256"), "manifest"),
        (sdk033_lock, sdk033_graph.get("lockSha256"), "lock"),
    ):
        if isinstance(path, str):
            audit.check(
                audit.sha256(path) == digest,
                f"SDK-033 {label} digest changed",
            )
    audit.check(
        sdk033_graph.get("directPackages")
        == [
            "@babel/core@7.25.7",
            "@babel/plugin-transform-typescript@7.29.7",
            "@playwright/test@1.58.2",
            "@types/react@18.3.27",
            "@types/react-dom@18.3.7",
            "@wordpress/components@32.2.0",
            "@wordpress/dependency-extraction-webpack-plugin@6.40.0",
            "@wordpress/element@6.40.0",
            "@wordpress/i18n@6.13.0",
            "@wordpress/scripts@31.5.0",
            "react@18.3.1",
            "react-dom@18.3.1",
            "typescript@5.9.3",
            "webpack@5.108.4",
        ],
        "SDK-033 direct npm package set changed",
    )
    audit.check(
        sdk033_graph.get("runtimeImage") == node.get("reference"),
        "SDK-033 npm runtime image differs from the Node lock",
    )
    audit.check(
        sdk033_graph.get("browserRuntimeImage")
        == playwright.get("reference"),
        "SDK-033 browser runtime image differs from the Playwright lock",
    )
    audit.check(
        sdk033_graph.get("lifecycleScriptsAllowed") is False,
        "SDK-033 npm lifecycle scripts must remain disabled",
    )
    audit.check(
        sdk033_graph.get("buildInputOnly") is True,
        "SDK-033 npm graph must remain a build input",
    )
    audit.check(
        sdk033_graph.get("advisoryFollowUp") == "wordpresshx-g2.3",
        "SDK-033 advisory follow-up changed",
    )
    audit.check(
        sdk033_graph.get("sourceCorrelationReceiptId")
        == "G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION",
        "SDK-033 source-correlation receipt changed",
    )
    audit.check(
        sdk033_graph.get("receiptId")
        == "SDK-033-WORDPRESS-ASSET-METADATA",
        "SDK-033 npm graph receipt changed",
    )
    audit.exact_keys(
        sdk063_graph,
        {
            "id",
            "authority",
            "profilePath",
            "profileSha256",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "directPackages",
            "runtimeImage",
            "browserRuntimeImage",
            "wordpressRuntimeImage",
            "lifecycleScriptsAllowed",
            "buildInputOnly",
            "advisoryFollowUp",
            "receiptId",
        },
        "SDK-063 npm graph",
    )
    audit.check(
        sdk063_graph.get("authority")
        == "exact-provider-editor-overlay-package-lock-and-real-wordpress-runtime",
        "SDK-063 npm graph authority changed",
    )
    sdk063_profile = sdk063_graph.get("profilePath")
    sdk063_manifest = sdk063_graph.get("manifestPath")
    sdk063_lock = sdk063_graph.get("lockPath")
    audit.check(
        sdk063_profile
        == (
            "packages/gutenberg/src/wordpress/hx/gutenberg/profile/"
            "wp70-release.editor-plugin.browser-hxx.json"
        ),
        "SDK-063 editor profile path changed",
    )
    audit.check(
        sdk063_manifest == "packages/gutenberg/editor-tooling/package.json",
        "SDK-063 npm manifest path changed",
    )
    audit.check(
        sdk063_lock == "packages/gutenberg/editor-tooling/package-lock.json",
        "SDK-063 npm lock path changed",
    )
    for path, digest, label in (
        (sdk063_profile, sdk063_graph.get("profileSha256"), "profile"),
        (sdk063_manifest, sdk063_graph.get("manifestSha256"), "manifest"),
        (sdk063_lock, sdk063_graph.get("lockSha256"), "lock"),
    ):
        if isinstance(path, str):
            audit.check(
                audit.sha256(path) == digest,
                f"SDK-063 {label} digest changed",
            )
    audit.check(
        sdk063_graph.get("directPackages")
        == [
            "@babel/core@7.25.7",
            "@babel/plugin-transform-typescript@7.29.7",
            "@playwright/test@1.58.2",
            "@types/react@18.3.27",
            "@types/react-dom@18.3.7",
            "@wordpress/browserslist-config@6.40.0",
            "@wordpress/components@32.2.0",
            "@wordpress/data@10.40.0",
            "@wordpress/dependency-extraction-webpack-plugin@6.40.0",
            "@wordpress/editor@14.40.0",
            "@wordpress/element@6.40.0",
            "@wordpress/i18n@6.13.0",
            "@wordpress/plugins@7.40.0",
            "@wordpress/scripts@31.5.0",
            "axe-core@4.10.2",
            "react@18.3.1",
            "react-dom@18.3.1",
            "typescript@5.9.3",
            "webpack@5.108.4",
        ],
        "SDK-063 direct npm package set changed",
    )
    audit.check(
        sdk063_graph.get("runtimeImage") == node.get("reference"),
        "SDK-063 runtime image differs from the Node lock",
    )
    audit.check(
        sdk063_graph.get("browserRuntimeImage") == playwright.get("reference"),
        "SDK-063 browser image differs from the Playwright lock",
    )
    audit.check(
        sdk063_graph.get("wordpressRuntimeImage")
        == nested(images, "wordpress70Php84", "reference"),
        "SDK-063 WordPress image differs from the image lock",
    )
    audit.check(
        sdk063_graph.get("lifecycleScriptsAllowed") is False,
        "SDK-063 npm lifecycle scripts must remain disabled",
    )
    audit.check(
        sdk063_graph.get("buildInputOnly") is True,
        "SDK-063 npm graph must remain a build input",
    )
    audit.check(
        sdk063_graph.get("advisoryFollowUp") == "wordpresshx-g2.3",
        "SDK-063 advisory follow-up changed",
    )
    audit.check(
        sdk063_graph.get("receiptId") == "SDK-063-EDITOR-PLUGIN-SLOTFILL",
        "SDK-063 npm graph receipt changed",
    )
    audit.exact_keys(
        sdk034_graph,
        {
            "id",
            "authority",
            "profilePath",
            "profileSha256",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "dependencyLockPath",
            "dependencyLockSha256",
            "directPackages",
            "buildImage",
            "runtimeImage",
            "lifecycleScriptsAllowed",
            "buildInputOnly",
            "publicationAuthorized",
            "officialWordpressScriptsFollowUp",
            "receiptId",
        },
        "SDK-034 browser correlation npm graph",
    )
    audit.check(
        sdk034_graph.get("id")
        == "sdk-034-browser-source-correlation-verification-graph",
        "SDK-034 npm graph ID changed",
    )
    audit.check(
        sdk034_graph.get("authority")
        == "exact-genes-map-esbuild-lock-and-real-chromium-runtime",
        "SDK-034 npm graph authority changed",
    )
    sdk034_profile = sdk034_graph.get("profilePath")
    sdk034_manifest = sdk034_graph.get("manifestPath")
    sdk034_lock = sdk034_graph.get("lockPath")
    sdk034_dependency_lock = sdk034_graph.get("dependencyLockPath")
    audit.check(
        sdk034_profile == "packages/cli/profiles/browser-correlation.hxml",
        "SDK-034 browser correlation profile path changed",
    )
    audit.check(
        sdk034_manifest == "packages/cli/browser-tooling/package.json",
        "SDK-034 npm manifest path changed",
    )
    audit.check(
        sdk034_lock == "packages/cli/browser-tooling/package-lock.json",
        "SDK-034 npm lock path changed",
    )
    audit.check(
        sdk034_dependency_lock == "packages/cli/dependency-lock.json",
        "SDK-034 Haxe dependency lock path changed",
    )
    for path, digest, label in (
        (sdk034_profile, sdk034_graph.get("profileSha256"), "profile"),
        (sdk034_manifest, sdk034_graph.get("manifestSha256"), "manifest"),
        (sdk034_lock, sdk034_graph.get("lockSha256"), "npm lock"),
        (
            sdk034_dependency_lock,
            sdk034_graph.get("dependencyLockSha256"),
            "Haxe dependency lock",
        ),
    ):
        if isinstance(path, str):
            audit.check(
                audit.sha256(path) == digest,
                f"SDK-034 {label} digest changed",
            )
    audit.check(
        sdk034_graph.get("directPackages")
        == ["esbuild@0.27.2", "playwright-core@1.58.2"],
        "SDK-034 direct npm package set changed",
    )
    audit.check(
        sdk034_graph.get("buildImage") == node.get("reference"),
        "SDK-034 build image differs from the Node lock",
    )
    audit.check(
        sdk034_graph.get("runtimeImage") == playwright.get("reference"),
        "SDK-034 runtime image differs from the Playwright lock",
    )
    audit.check(
        sdk034_graph.get("lifecycleScriptsAllowed") is False,
        "SDK-034 npm lifecycle scripts must remain disabled",
    )
    audit.check(
        sdk034_graph.get("buildInputOnly") is True,
        "SDK-034 npm graph must remain a build input",
    )
    audit.check(
        sdk034_graph.get("publicationAuthorized") is False,
        "SDK-034 npm graph must not authorize publication",
    )
    audit.check(
        sdk034_graph.get("officialWordpressScriptsFollowUp")
        == "wordpresshx-g2.4",
        "SDK-034 official WordPress source-map follow-up changed",
    )
    audit.check(
        sdk034_graph.get("receiptId")
        == "SDK-034-BROWSER-SOURCE-CORRELATION",
        "SDK-034 npm graph receipt changed",
    )
    audit.exact_keys(
        sdk025_graph,
        {
            "id",
            "authority",
            "manifestPath",
            "manifestSha256",
            "lockPath",
            "lockSha256",
            "dependencyLockPath",
            "dependencyLockSha256",
            "directPackages",
            "runtimeImage",
            "lifecycleScriptsAllowed",
            "runtimeTool",
            "publicationAuthorized",
            "receiptId",
        },
        "SDK-025 CLI npm graph",
    )
    audit.check(
        sdk025_graph.get("id") == "sdk-025-php-trace-cli-graph",
        "SDK-025 CLI graph ID changed",
    )
    audit.check(
        sdk025_graph.get("authority")
        == "package-local-empty-npm-lock-and-exact-haxe-dependency-lock",
        "SDK-025 CLI graph authority changed",
    )
    sdk025_manifest = sdk025_graph.get("manifestPath")
    sdk025_lock = sdk025_graph.get("lockPath")
    sdk025_dependency_lock = sdk025_graph.get("dependencyLockPath")
    audit.check(
        sdk025_manifest == "packages/cli/package.json",
        "SDK-025 CLI manifest path changed",
    )
    audit.check(
        sdk025_lock == "packages/cli/package-lock.json",
        "SDK-025 CLI npm lock path changed",
    )
    audit.check(
        sdk025_dependency_lock == "packages/cli/dependency-lock.json",
        "SDK-025 Haxe dependency lock path changed",
    )
    for path, digest, label in (
        (sdk025_manifest, sdk025_graph.get("manifestSha256"), "manifest"),
        (sdk025_lock, sdk025_graph.get("lockSha256"), "npm lock"),
        (
            sdk025_dependency_lock,
            sdk025_graph.get("dependencyLockSha256"),
            "Haxe dependency lock",
        ),
    ):
        if isinstance(path, str):
            audit.check(
                audit.sha256(path) == digest,
                f"SDK-025 CLI {label} digest changed",
            )
    audit.check(
        sdk025_graph.get("directPackages") == [],
        "SDK-025 CLI npm graph must remain dependency-free",
    )
    audit.check(
        sdk025_graph.get("runtimeImage") == node.get("reference"),
        "SDK-025 CLI runtime image differs from the Node lock",
    )
    audit.check(
        sdk025_graph.get("lifecycleScriptsAllowed") is False,
        "SDK-025 CLI npm lifecycle scripts must remain disabled",
    )
    audit.check(
        sdk025_graph.get("runtimeTool") is True,
        "SDK-025 CLI graph must remain a host runtime tool",
    )
    audit.check(
        sdk025_graph.get("publicationAuthorized") is False,
        "SDK-025 CLI graph must not authorize publication",
    )
    audit.check(
        sdk025_graph.get("receiptId") == "SDK-025-PHP-SOURCE-CORRELATION",
        "SDK-025 CLI graph receipt changed",
    )
    active_npm = npm.get("activePackages", [])
    audit.check(isinstance(active_npm, list) and len(active_npm) == 1, "exactly one direct npm build package is expected")
    lix = active_npm[0] if isinstance(active_npm, list) and active_npm else {}
    audit.check(lix.get("name") == "lix" and lix.get("version") == "15.12.4", "Lix must be exactly 15.12.4")
    audit.check(lix.get("artifactSha256") == "4f2257276aba9f552b1b35237d33fbc1a0898039d8105ed6e8d1468e6c53a2fa", "Lix artifact changed")

    haxelib = graphs.get("haxelib", {}) if isinstance(graphs, dict) else {}
    audit.exact_keys(haxelib, {"status", "manifestPaths", "internalPackages", "toolPackages", "parserClosure"}, "Haxelib graph")
    audit.check(haxelib.get("manifestPaths") == ["compiler/reflaxe.php/haxelib.json"], "Haxelib manifest projection changed")
    audit.check(manifest_paths(audit.root, {"haxelib.json"}) == haxelib.get("manifestPaths"), "unlocked Haxelib manifest found")
    parser = haxelib.get("parserClosure", {})
    audit.exact_keys(parser, {"path", "sha256", "rootPackage", "transitiveCount", "compileTimeOnly"}, "HXX parser closure projection")
    audit.check(parser.get("path") == "packages/hxx/dependency-lock.json", "HXX dependency lock path changed")
    audit.check(audit.sha256("packages/hxx/dependency-lock.json") == parser.get("sha256"), "HXX dependency lock digest changed")
    audit.check(parser.get("rootPackage") == "tink_hxx@0.25.1", "HXX parser root changed")
    audit.check(parser.get("transitiveCount") == 5, "HXX transitive count changed")
    audit.check(parser.get("compileTimeOnly") is True, "HXX closure must remain compile-time-only")

    profile_inputs = toolchain.get("profileInputs", {})
    audit.exact_keys(profile_inputs, {"upstreamLock", "profiles"}, "toolchain profile inputs")
    upstream_ref = profile_inputs.get("upstreamLock", {}) if isinstance(profile_inputs, dict) else {}
    audit.exact_keys(upstream_ref, {"path", "sha256"}, "upstream lock projection")
    audit.check(upstream_ref.get("path") == "manifests/upstream.lock.json", "upstream lock path changed")
    audit.check(audit.sha256("manifests/upstream.lock.json") == upstream_ref.get("sha256"), "upstream lock digest changed")
    audit.check(profile_inputs.get("profiles") == ["wp70-release", "gutenberg-forward-23.4"], "G0 profile set changed")

    policy = toolchain.get("policy", {})
    audit.exact_keys(policy, {"floatingVersionsAllowed", "mutableSiblingCheckoutAsBuildInputAllowed", "fullPortInternalPathOrImportAllowed", "omittedFutureInputTreatment", "newInputRequiresExactIdentityAndReceipt"}, "toolchain policy")
    audit.check(policy.get("floatingVersionsAllowed") is False, "floating toolchain versions must be forbidden")
    audit.check(policy.get("mutableSiblingCheckoutAsBuildInputAllowed") is False, "mutable sibling build inputs must be forbidden")
    audit.check(policy.get("fullPortInternalPathOrImportAllowed") is False, "full-port internal dependencies must be forbidden")
    audit.check(policy.get("omittedFutureInputTreatment") == "unresolved-not-implied", "omitted inputs must remain unresolved")
    audit.check(policy.get("newInputRequiresExactIdentityAndReceipt") is True, "new inputs must require exact identities and receipts")
    audit.check(toolchain.get("claims") == {
        "g0ToolchainCoverage": "locked",
        "browserSdkCompatibility": "not-tested",
        "wordpressSdkCompatibility": "not-tested",
        "publicPackagePublicationAuthorized": False,
        "productionSupport": "not-tested",
    }, "toolchain claims changed or broadened")


def validate_cross_evidence(audit: Audit, receipt: dict[str, Any], toolchain: dict[str, Any]) -> None:
    gate = receipt.get("gateContract", {})
    audit.exact_keys(gate, {"path", "sha256", "section", "licensingDecisionDeadline", "laterExperimentalWorkAllowed"}, "G0 gate contract")
    audit.check(gate.get("path") == "wordpress-hx-sdk-product-requirements.md", "G0 gate contract path changed")
    audit.check(audit.sha256("wordpress-hx-sdk-product-requirements.md") == gate.get("sha256"), "G0 PRD digest changed")
    audit.check(gate.get("section") == "Gate G0 — Product authority and baseline lock", "G0 PRD section changed")
    audit.check(gate.get("licensingDecisionDeadline") == "before-any-public-release", "licensing deadline must remain before public release")
    audit.check(gate.get("laterExperimentalWorkAllowed") is True, "G0 must preserve the PRD experimental-work rule")

    acceptance = receipt.get("acceptance", {})
    audit.exact_keys(acceptance, {"repositoryAuthority", "acceptedDecisions", "profiles", "toolchain", "apiClassification", "fullPortBoundary"}, "G0 acceptance evidence")
    expected_decisions = ["ADR-001", "ADR-002", "ADR-003", "ADR-004", "ADR-008", "ADR-021"]
    audit.check(acceptance.get("acceptedDecisions") == expected_decisions, "G0 accepted-decision set changed")
    audit.check(
        acceptance.get("toolchain")
        == {
            "lockId": "G0-TOOLCHAIN-BASELINE",
            "status": "closed-g0-baseline",
            "covers": [
                "haxe",
                "haxe-formatter",
                "genes-ts",
                "reflaxe.php",
                "node-image",
                "php-images",
                "composer-runtime-empty-sdk-026-build-graph",
                "npm-build-inputs",
                "haxelib-build-inputs",
            ],
        },
        "G0 aggregate toolchain coverage changed",
    )
    decision_paths = {
        "ADR-001": "docs/adr/001-product-and-repository-boundary.md",
        "ADR-002": "docs/adr/002-exact-compatibility-profiles.md",
        "ADR-003": "docs/adr/003-package-topology-and-lockstep-versioning.md",
        "ADR-004": "docs/adr/004-generic-php-compiler-home.md",
        "ADR-008": "docs/adr/008-profile-generation-and-api-classification.md",
        "ADR-021": "docs/adr/021-release-and-support-policy.md",
    }
    for decision, path in decision_paths.items():
        text = audit.read_text(path, decision)
        audit.check("- Status: accepted" in text[:500], f"{decision} must remain accepted")

    repository = audit.read_json("manifests/evidence/sdk-004-canonical-repository.json", "repository receipt")
    repository_acceptance = acceptance.get("repositoryAuthority", {})
    audit.check(repository_acceptance.get("receiptId") == repository.get("receiptId") == "SDK-004-CANONICAL-REPOSITORY", "repository receipt identity changed")
    audit.check(repository_acceptance.get("nameWithOwner") == nested(repository, "repository", "nameWithOwner"), "repository authority changed")
    audit.check(repository_acceptance.get("visibility") == nested(repository, "repository", "visibility") == "public", "repository visibility evidence changed")
    audit.check(nested(repository, "prePublicationSecurity", "gitHistoryOutcome") == "passed", "repository history security evidence must pass")
    audit.check(nested(repository, "transport", "beadsRef") == "refs/dolt/data", "Beads data ref changed")

    upstream = audit.read_json("manifests/upstream.lock.json", "upstream lock")
    wp_receipt = audit.read_json("manifests/evidence/sdk-010-wp70-release.json", "wp70 source receipt")
    forward_receipt = audit.read_json("manifests/evidence/sdk-011-gutenberg-forward-23.4.json", "forward source receipt")
    generator = audit.read_json("manifests/evidence/sdk-013-profile-generator.json", "profile generator receipt")
    profiles = acceptance.get("profiles", [])
    audit.check(isinstance(profiles, list) and [item.get("profileId") for item in profiles] == ["wp70-release", "gutenberg-forward-23.4"], "G0 profile evidence must contain the two exact peer profiles")
    generated_profiles = {item.get("profileId"): item for item in generator.get("profiles", []) if isinstance(item, dict)}
    for item in profiles if isinstance(profiles, list) else []:
        profile_id = item.get("profileId")
        generated = generated_profiles.get(profile_id, {})
        audit.check(item.get("catalogDigest") == nested(generated, "catalog", "catalogDigest"), f"{profile_id} catalog digest differs from generator receipt")
        catalog_path = nested(generated, "catalog", "path")
        catalog_file_sha = nested(generated, "catalog", "fileSha256")
        if isinstance(catalog_path, str):
            audit.check(audit.sha256(catalog_path) == catalog_file_sha, f"{profile_id} catalog bytes differ from receipt")
    audit.check(
        nested(upstream, "entries", "wp70-release", "testReceiptIds")
        == [
            wp_receipt.get("receiptId"),
            "SDK-032-REACT-GUTENBERG-HXX",
            "SDK-033-WORDPRESS-ASSET-METADATA",
            "SDK-034-BROWSER-SOURCE-CORRELATION",
            "SDK-035-CLASSIC-GENES-DIFFERENTIAL",
            "SDK-063-EDITOR-PLUGIN-SLOTFILL",
            "G2.4-WORDPRESS-SCRIPTS-SOURCE-CORRELATION",
        ],
        "wp70 upstream/source receipt link changed",
    )
    audit.check(nested(upstream, "entries", "gutenberg-forward-23.4", "testReceiptIds") == [forward_receipt.get("receiptId")], "forward upstream/source receipt link changed")

    classification = audit.read_json("profiles/classification-decision-lock.json", "classification decision lock")
    api = acceptance.get("apiClassification", {})
    audit.check(api.get("decision") == classification.get("decision") == "ADR-008", "classification authority changed")
    audit.check(api.get("classificationAndEvidenceSeparate") is True, "classification and evidence must remain separate")
    audit.check(api.get("broadDynamicFallbackAllowed") is False, "broad Dynamic fallback must remain forbidden")
    audit.check(nested(classification, "evidenceAuthority", "broadDynamicFallbackAllowed") is False, "classification lock permits broad Dynamic fallback")

    provenance = audit.read_json("compiler/reflaxe.php/provenance.json", "PHP compiler provenance")
    php_receipt = audit.read_json("manifests/evidence/sdk-021-php-ir-printer.json", "PHP compiler receipt")
    boundary = acceptance.get("fullPortBoundary", {})
    audit.check(boundary == {
        "originProvenanceRecorded": True,
        "sourceOrPathRuntimeDependency": False,
        "coreLinkerImported": False,
        "mutableSiblingBuildInput": False,
        "sourceScan": "passed",
    }, "full-port boundary claims changed")
    audit.check(nested(provenance, "destination", "path") == "compiler/reflaxe.php", "PHP compiler destination changed")
    audit.check(nested(provenance, "origin", "commit") == nested(toolchain, "compilers", "reflaxePhp", "originCommit"), "PHP compiler provenance/toolchain origin differs")
    audit.check(nested(php_receipt, "subject", "packageContentSha256") == nested(toolchain, "compilers", "reflaxePhp", "packageContentSha256"), "PHP compiler package digest differs")
    audit.check(nested(php_receipt, "boundary", "sourcePortRuntimeDependency") is False, "PHP compiler receipt reports a port runtime dependency")
    audit.check(nested(php_receipt, "boundary", "wordpressProfileImported") is False, "generic PHP compiler imported the WordPress profile")

    forbidden = ("wordpresshx-port", "wphx.compiler", "src/wphx", "../wordpresshx-port")
    scan_roots = [audit.root / "compiler/reflaxe.php/src", audit.root / "packages"]
    for scan_root in scan_roots:
        if not scan_root.exists():
            audit.errors.append(f"source scan root missing: {scan_root.relative_to(audit.root)}")
            continue
        for path in sorted(scan_root.rglob("*.hx")):
            text = path.read_text(encoding="utf-8")
            for pattern in forbidden:
                audit.check(pattern not in text, f"full-port coupling pattern {pattern!r} found in {path.relative_to(audit.root)}")

    artifacts = receipt.get("referenceArtifacts", [])
    expected_artifacts = {
        "wordpress-7.0-distribution-tree": ("fc90e36ee34bb3bb50147222c3b281d4fcc06a3837b3aaca5516a13e3b1ec857", "SDK-010-WP70-RELEASE-SOURCE"),
        "gutenberg-23.4-release-zip": ("988334d3142a776be911888e6128ef3f45ee1f1e1831aa1ed43f0a28d042733a", "SDK-011-GUTENBERG-FORWARD-23.4"),
        "genes-ts-1.33.0-submit-zip": ("4bf2d2d1046ee5a99830ef31158a90033bfa521da12eb1d5ecd136b35b4fd145", "SDK-030-GENES-TS-V1.33.0"),
        "reflaxe-php-package-content": ("cf0fc152f4fe09b8a9eb92f6b9f4c1f1591ab938531d6241c245ab11a75532f6", "SDK-021-PHP-IR-PRINTER"),
        "wp70-release-catalog-v1": ("530a1581d07e7509fb68f7da5b53575009ed4a94280513efd82a8c99622d9d61", "SDK-013-PROFILE-GENERATOR"),
        "gutenberg-forward-23.4-catalog-v1": ("66bcac1aba265913c0a541c5f1ab7c58c5431404b3274e43fa415d1e137d0404", "SDK-013-PROFILE-GENERATOR"),
    }
    audit.check(isinstance(artifacts, list) and len(artifacts) == len(expected_artifacts), "G0 reference artifact ledger must contain exactly six entries")
    artifact_map = {item.get("id"): item for item in artifacts if isinstance(item, dict)}
    audit.check(set(artifact_map) == set(expected_artifacts), "G0 reference artifact IDs changed")
    for artifact_id, (digest, receipt_id) in expected_artifacts.items():
        item = artifact_map.get(artifact_id, {})
        audit.exact_keys(item, {"id", "sha256", "method", "receiptId"}, f"reference artifact {artifact_id}")
        audit.check(item.get("sha256") == digest, f"reference artifact {artifact_id} digest changed")
        audit.check(item.get("receiptId") == receipt_id, f"reference artifact {artifact_id} receipt changed")
        audit.check(isinstance(item.get("method"), str) and len(item.get("method", "")) >= 30, f"reference artifact {artifact_id} lacks snapshot methodology")


def validate_receipt_state(audit: Audit, receipt: dict[str, Any]) -> None:
    audit.exact_keys(
        receipt,
        {
            "schemaVersion",
            "receiptId",
            "bead",
            "status",
            "gateContract",
            "subject",
            "acceptance",
            "referenceArtifacts",
            "localVerification",
            "implementation",
            "hostedWorkflow",
            "publicationBoundary",
            "claims",
        },
        "G0 receipt",
    )
    audit.check(receipt.get("schemaVersion") == 1, "G0 receipt schemaVersion must be 1")
    audit.check(receipt.get("receiptId") == "G0-PRODUCT-AUTHORITY-BASELINE", "G0 receipt ID changed")
    audit.check(receipt.get("bead") == "wordpresshx-g0", "G0 receipt bead changed")
    audit.check(receipt.get("status") in {"implemented-hosted-pending", "verified"}, "G0 receipt status is invalid")
    audit.check(receipt.get("localVerification") == {
        "commands": [
            "python3 scripts/gates/test-g0-baseline.py",
            "bash scripts/check-repository.sh",
            "bash scripts/hooks/test.sh",
        ],
        "outcome": "passed",
    }, "G0 local verification record changed")

    implementation = receipt.get("implementation", {})
    audit.exact_keys(implementation, {"baseCommit", "commit"}, "G0 implementation record")
    audit.check(implementation.get("baseCommit") == "9dd2b389c172a9446c0b73ffbcb05a468d53be7b", "G0 implementation base commit changed")
    audit.check(implementation.get("commit") is None or bool(SHA1.fullmatch(str(implementation.get("commit")))), "G0 implementation commit must be null or a full commit ID")

    hosted = receipt.get("hostedWorkflow", {})
    audit.exact_keys(hosted, {"workflow", "runId", "commit", "status", "fullMatrixStatus", "jobCount"}, "G0 hosted workflow record")
    publication = receipt.get("publicationBoundary", {})
    audit.check(publication == {
        "adr020Status": "proposed",
        "sdk002RequiredBeforeRelease": True,
        "g0BlocksOnQualifiedLicenseReview": False,
        "publicationGate": "blocked",
        "publicPackagePublicationAuthorized": False,
    }, "G0 licensing/publication boundary changed")
    adr020 = audit.read_text("docs/adr/020-licensing-and-generated-output.md", "ADR-020")
    audit.check("- Status: proposed" in adr020[:500], "ADR-020 must remain proposed in the G0 receipt")
    license_policy = audit.read_json("LICENSES/policy.json", "provisional license policy")
    audit.check(license_policy.get("status") == "provisional-no-license-grant", "license policy must remain provisional")
    audit.check(nested(license_policy, "publication", "allowed") is False, "license policy unexpectedly authorizes publication")
    audit.check(nested(license_policy, "publication", "gateExitCode") == 3, "publication gate must remain fail-closed with exit 3")

    expected_claims = {
        "g0ProductAuthorityAndBaseline": "implemented-hosted-pending",
        "profileCapabilities": "inventoried",
        "nativePhpBoundary": "not-tested-by-g0",
        "browserBoundary": "not-tested-by-g0",
        "publicPackagePublication": "blocked",
        "productionSupport": "not-tested",
    }
    if receipt.get("status") == "implemented-hosted-pending":
        audit.check(implementation.get("commit") is None, "pending G0 receipt must not claim an implementation commit")
        audit.check(hosted == {
            "workflow": "repository.yml",
            "runId": None,
            "commit": None,
            "status": "pending",
            "fullMatrixStatus": "pending",
            "jobCount": 10,
        }, "pending G0 hosted record is not exact")
    else:
        expected_claims["g0ProductAuthorityAndBaseline"] = "verified"
        audit.check(isinstance(hosted.get("runId"), int) and hosted.get("runId", 0) > 0, "verified G0 receipt needs a hosted run ID")
        audit.check(hosted.get("commit") == implementation.get("commit"), "G0 hosted and implementation commits differ")
        audit.check(hosted.get("status") == "passed", "G0 hosted workflow did not pass")
        audit.check(hosted.get("fullMatrixStatus") == "passed", "G0 complete hosted matrix did not pass")
        audit.check(hosted.get("jobCount") == 10, "G0 hosted matrix must contain 10 jobs")
    audit.check(receipt.get("claims") == expected_claims, "G0 receipt claims changed or broadened")


def validate(root: Path) -> Audit:
    audit = Audit(root.resolve())
    receipt = audit.read_json("manifests/evidence/g0-product-baseline.json", "G0 receipt")
    toolchain = audit.read_json("manifests/toolchain.lock.json", "G0 toolchain lock")
    validate_receipt_state(audit, receipt)
    validate_subject_hashes(audit, receipt)
    validate_toolchain(audit, toolchain)
    validate_cross_evidence(audit, receipt, toolchain)
    return audit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="repository root (defaults to the validator's repository)",
    )
    args = parser.parse_args()
    audit = validate(args.root)
    if audit.errors:
        for error in audit.errors:
            print(f"[g0-baseline] ERROR: {error}", file=sys.stderr)
        return 1
    receipt = audit.read_json("manifests/evidence/g0-product-baseline.json", "G0 receipt")
    print(
        "G0 baseline passed: independent authority and exact toolchain/profile "
        f"baseline {receipt.get('status')}; publication blocked"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
