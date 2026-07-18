#!/usr/bin/env python3
"""Emit an inspectable native WordPress plugin from an SDK-033 asset plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path


HANDLE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
VERSION = re.compile(r"[0-9a-f]{20}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
SEMVER = re.compile(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?\Z")
SAFE_FILENAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\.(?:js|asset\.php)\Z")
BROWSER_EXPORT_ID = re.compile(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+\Z")
MODULE_PATH = re.compile(r"[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\Z")
SOURCE_ENTRY = re.compile(
    r"[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*\.[cm]?[jt]sx?\Z"
)
PACKAGE_REQUEST = re.compile(
    r"(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._/-]*\Z"
)


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    assert set(value) == expected, f"{label} fields drifted"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_asset_php(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8").strip()
    match = re.fullmatch(
        r"<\?php return array\('dependencies' => array\((.*)\), "
        r"'version' => '([0-9a-f]{20})'\);",
        text,
    )
    assert match is not None, "official asset PHP shape drifted"
    dependencies: list[str] = []
    if match.group(1):
        for value in match.group(1).split(", "):
            dependency = re.fullmatch(r"'([a-z0-9-]+)'", value)
            assert dependency is not None, f"invalid dependency: {value}"
            dependencies.append(dependency.group(1))
    return {"dependencies": dependencies, "version": match.group(2)}


def validate_plan(plan: dict[str, object]) -> None:
    exact_keys(
        plan,
        {
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
        },
        "asset plan",
    )
    assert plan["schemaVersion"] == 1
    assert plan["profileId"] == "wp70-release"
    plugin = plan["plugin"]
    source = plan["source"]
    script = plan["script"]
    translations = plan["translations"]
    lanes = plan["lanes"]
    assert isinstance(plugin, dict)
    assert isinstance(source, dict)
    assert isinstance(script, dict)
    assert isinstance(translations, dict)
    assert isinstance(lanes, dict)
    exact_keys(
        plugin,
        {"slug", "name", "version", "requiresWordPress", "requiresPhp"},
        "plugin",
    )
    exact_keys(
        source,
        {
            "browserExportId",
            "generatedModule",
            "generatedTreeSha256",
            "sourceEntry",
            "sourceImports",
        },
        "source",
    )
    exact_keys(
        script,
        {
            "assetMetadataFilename",
            "dependencies",
            "filename",
            "handle",
            "productionBundleSha256",
            "productionVersion",
        },
        "script",
    )
    exact_keys(
        translations,
        {"domain", "finalHandle", "messages", "relativePath"},
        "translations",
    )
    exact_keys(lanes, {"development", "production"}, "lanes")
    assert HANDLE.fullmatch(plan["entryId"])
    assert HANDLE.fullmatch(plugin["slug"])
    assert isinstance(plugin["name"], str)
    assert plugin["name"] == plugin["name"].strip() and plugin["name"]
    assert all(
        forbidden not in plugin["name"]
        for forbidden in ("\r", "\n", "\x00", "*/")
    )
    assert SEMVER.fullmatch(plugin["version"])
    assert SEMVER.fullmatch(plugin["requiresWordPress"])
    assert SEMVER.fullmatch(plugin["requiresPhp"])
    assert BROWSER_EXPORT_ID.fullmatch(source["browserExportId"])
    assert MODULE_PATH.fullmatch(source["generatedModule"])
    assert SHA256.fullmatch(source["generatedTreeSha256"])
    assert SOURCE_ENTRY.fullmatch(source["sourceEntry"])
    assert isinstance(source["sourceImports"], list)
    assert source["sourceImports"] == sorted(set(source["sourceImports"]))
    assert all(
        isinstance(request, str) and PACKAGE_REQUEST.fullmatch(request)
        for request in source["sourceImports"]
    )
    assert SAFE_FILENAME.fullmatch(script["filename"])
    assert SAFE_FILENAME.fullmatch(script["assetMetadataFilename"])
    assert script["assetMetadataFilename"] == script["filename"].replace(
        ".js", ".asset.php"
    )
    assert HANDLE.fullmatch(script["handle"])
    assert VERSION.fullmatch(script["productionVersion"])
    assert SHA256.fullmatch(script["productionBundleSha256"])
    assert isinstance(script["dependencies"], list)
    assert script["dependencies"] == sorted(set(script["dependencies"]))
    assert all(HANDLE.fullmatch(value) for value in script["dependencies"])
    assert HANDLE.fullmatch(translations["domain"])
    assert translations["finalHandle"] == script["handle"]
    assert translations["relativePath"] == "languages"
    assert isinstance(translations["messages"], list)
    assert translations["messages"] == sorted(set(translations["messages"]))
    assert all(
        isinstance(message, str) and message and "\x00" not in message
        for message in translations["messages"]
    )
    for lane_name in ("development", "production"):
        lane = lanes[lane_name]
        assert isinstance(lane, dict)
        exact_keys(
            lane,
            {
                "assetMetadataFile",
                "bundleSha256",
                "dependencies",
                "externalizedRequests",
                "version",
            },
            f"{lane_name} lane",
        )
        assert lane["assetMetadataFile"] == script["assetMetadataFilename"]
        assert SHA256.fullmatch(lane["bundleSha256"])
        assert lane["dependencies"] == script["dependencies"]
        assert isinstance(lane["externalizedRequests"], list)
        assert lane["externalizedRequests"] == sorted(
            set(lane["externalizedRequests"])
        )
        assert all(
            isinstance(request, str) and PACKAGE_REQUEST.fullmatch(request)
            for request in lane["externalizedRequests"]
        )
        assert VERSION.fullmatch(lane["version"])
    assert lanes["development"]["externalizedRequests"] == lanes[
        "production"
    ]["externalizedRequests"]
    assert set(source["sourceImports"]).issubset(
        set(lanes["production"]["externalizedRequests"])
    )
    assert plan["entryId"] == script["handle"]
    assert lanes["production"]["bundleSha256"] == script[
        "productionBundleSha256"
    ]
    assert lanes["production"]["version"] == script["productionVersion"]
    assert plan["nativePlan"] == {
        "enqueueApi": "wp_enqueue_script",
        "registerApi": "wp_register_script",
        "translationApi": "wp_set_script_translations",
    }
    assert plan["authority"] == {
        "dependencyExtraction": (
            "@wordpress/dependency-extraction-webpack-plugin@6.40.0"
        ),
        "dependencySource": "final-bundle",
        "developmentProductionDependencyParity": True,
        "manualAssetPhpEditingAllowed": False,
    }


def php_plugin(plan: dict[str, object]) -> str:
    plugin = plan["plugin"]
    script = plan["script"]
    translations = plan["translations"]
    return f"""<?php
/**
 * Plugin Name: {plugin['name']}
 * Version: {plugin['version']}
 * Requires at least: {plugin['requiresWordPress']}
 * Requires PHP: {plugin['requiresPhp']}
 * Text Domain: {translations['domain']}
 * Domain Path: /{translations['relativePath']}
 */

// Generated from the WordPressHx semantic asset plan. Do not edit.
defined( 'ABSPATH' ) || exit;

add_action(
	'wp_enqueue_scripts',
	static function (): void {{
		$asset = require __DIR__ . '/build/{script['assetMetadataFilename']}';
		if ( ! is_array( $asset ) || ! isset( $asset['dependencies'], $asset['version'] ) ) {{
			throw new UnexpectedValueException( 'Invalid generated WordPressHx asset metadata.' );
		}}
		wp_register_script(
			'{script['handle']}',
			plugins_url( 'build/{script['filename']}', __FILE__ ),
			$asset['dependencies'],
			$asset['version'],
			array( 'in_footer' => true )
		);
		if ( ! wp_set_script_translations(
			'{script['handle']}',
			'{translations['domain']}',
			__DIR__ . '/{translations['relativePath']}'
		) ) {{
			throw new RuntimeException( 'Unable to attach generated WordPressHx translations.' );
		}}
		wp_enqueue_script( '{script['handle']}' );
	}}
);
"""


def translation_document(plan: dict[str, object]) -> dict[str, object]:
    translations = plan["translations"]
    domain = translations["domain"]
    messages: dict[str, object] = {
        "": {
            "domain": domain,
            "lang": "en_US",
            "plural-forms": "nplurals=2; plural=(n != 1);",
        }
    }
    for message in translations["messages"]:
        messages[message] = [message]
    return {
        "translation-revision-date": "",
        "generator": "WordPressHx SDK-033 deterministic asset emitter",
        "source": plan["source"]["sourceEntry"],
        "domain": domain,
        "locale_data": {domain: messages},
    }


def emit(plan_path: Path, bundle_root: Path, output_root: Path) -> None:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    assert isinstance(plan, dict)
    validate_plan(plan)
    assert not output_root.exists(), "output root already exists"
    assert bundle_root.is_dir(), "production bundle root is absent"
    script = plan["script"]
    source_bundle = bundle_root / script["filename"]
    source_asset = bundle_root / script["assetMetadataFilename"]
    assert source_bundle.is_file() and source_asset.is_file()
    assert sha256(source_bundle) == script["productionBundleSha256"]
    asset = parse_asset_php(source_asset)
    assert asset == {
        "dependencies": script["dependencies"],
        "version": script["productionVersion"],
    }

    build_root = output_root / "build"
    language_root = output_root / plan["translations"]["relativePath"]
    build_root.mkdir(parents=True)
    language_root.mkdir(parents=True)
    target_bundle = build_root / script["filename"]
    target_asset = build_root / script["assetMetadataFilename"]
    shutil.copyfile(source_bundle, target_bundle)
    shutil.copyfile(source_asset, target_asset)

    plugin_file = output_root / f"{plan['plugin']['slug']}.php"
    plugin_file.write_text(php_plugin(plan), encoding="utf-8")
    translation_file = language_root / (
        f"{plan['translations']['domain']}-en_US-"
        f"{script['handle']}.json"
    )
    translation_file.write_text(
        json.dumps(
            translation_document(plan),
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    files = {}
    for path in sorted(output_root.rglob("*")):
        if path.is_file():
            files[path.relative_to(output_root).as_posix()] = sha256(path)
    manifest = {
        "schemaVersion": 1,
        "generator": "wordpresshx-sdk033-asset-plugin-emitter-v1",
        "planSha256": sha256(plan_path),
        "files": files,
    }
    (output_root / "generation-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    arguments = parser.parse_args()
    emit(
        arguments.plan.resolve(),
        arguments.bundle_root.resolve(),
        arguments.output_root.resolve(),
    )


if __name__ == "__main__":
    main()
