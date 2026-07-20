#!/usr/bin/env python3
"""Emit a native WordPress editor plugin from the SDK-063 asset plan."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path


HANDLE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
SEMVER = re.compile(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
VERSION = re.compile(r"[0-9a-f]{20}\Z")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    assert set(value) == expected, f"{label} fields drifted"


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


def validate(plan: dict[str, object]) -> None:
    exact_keys(
        plan,
        {
            "schemaVersion",
            "profileId",
            "editorCatalogRevision",
            "plugin",
            "editor",
            "source",
            "script",
            "translations",
            "lanes",
            "nativePlan",
            "policy",
        },
        "editor asset plan",
    )
    assert plan["schemaVersion"] == 1
    assert plan["profileId"] == "wp70-release"
    assert plan["editorCatalogRevision"] == "wp70-release/editor-plugin-v1"
    plugin = plan["plugin"]
    editor = plan["editor"]
    source = plan["source"]
    script = plan["script"]
    translations = plan["translations"]
    assert isinstance(plugin, dict)
    assert isinstance(editor, dict)
    assert isinstance(source, dict)
    assert isinstance(script, dict)
    assert isinstance(translations, dict)
    exact_keys(
        plugin,
        {"slug", "name", "version", "requiresWordPress", "requiresPhp"},
        "plugin",
    )
    exact_keys(
        editor,
        {"pluginName", "sidebarName", "supportedPostType"},
        "editor",
    )
    exact_keys(
        source,
        {"generatedTreeSha256", "haxeEntry", "sourceImports"},
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
    for identity in (
        plugin["slug"],
        editor["pluginName"],
        editor["sidebarName"],
        script["handle"],
        translations["domain"],
    ):
        assert isinstance(identity, str) and HANDLE.fullmatch(identity)
    assert editor["supportedPostType"] == "post"
    assert SEMVER.fullmatch(plugin["version"])
    assert SEMVER.fullmatch(plugin["requiresWordPress"])
    assert SEMVER.fullmatch(plugin["requiresPhp"])
    assert source["haxeEntry"] == (
        "test/editor-plugin-fixture/src/sdk063/fixture/Main.hx"
    )
    assert SHA256.fullmatch(source["generatedTreeSha256"])
    assert source["sourceImports"] == sorted(set(source["sourceImports"]))
    assert script["filename"] == "editor.js"
    assert script["assetMetadataFilename"] == "editor.asset.php"
    assert SHA256.fullmatch(script["productionBundleSha256"])
    assert VERSION.fullmatch(script["productionVersion"])
    assert script["dependencies"] == sorted(set(script["dependencies"]))
    assert all(HANDLE.fullmatch(item) for item in script["dependencies"])
    assert translations["finalHandle"] == script["handle"]
    assert translations["relativePath"] == "languages"
    assert translations["messages"] == sorted(set(translations["messages"]))
    assert plan["nativePlan"] == {
        "enqueueHook": "enqueue_block_editor_assets",
        "registerApi": "wp_register_script",
        "translationApi": "wp_set_script_translations",
    }
    assert plan["policy"] == {
        "manualJavaScriptEntryAllowed": False,
        "privateOrExperimentalApisAllowed": False,
        "postTypeGatingOwner": "typed-haxe-render-component",
    }


def plugin_php(plan: dict[str, object]) -> str:
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

// Generated from the WordPressHx SDK-063 editor plan. Do not edit.
defined( 'ABSPATH' ) || exit;

add_action(
\t'enqueue_block_editor_assets',
\tstatic function (): void {{
\t\t$asset = require __DIR__ . '/build/{script['assetMetadataFilename']}';
\t\tif ( ! is_array( $asset ) || ! isset( $asset['dependencies'], $asset['version'] ) ) {{
\t\t\tthrow new UnexpectedValueException( 'Invalid generated WordPressHx editor asset metadata.' );
\t\t}}
\t\twp_register_script(
\t\t\t'{script['handle']}',
\t\t\tplugins_url( 'build/{script['filename']}', __FILE__ ),
\t\t\t$asset['dependencies'],
\t\t\t$asset['version'],
\t\t\tarray( 'in_footer' => true )
\t\t);
\t\tif ( ! wp_set_script_translations(
\t\t\t'{script['handle']}',
\t\t\t'{translations['domain']}',
\t\t\t__DIR__ . '/{translations['relativePath']}'
\t\t) ) {{
\t\t\tthrow new RuntimeException( 'Unable to attach generated WordPressHx editor translations.' );
\t\t}}
\t\twp_enqueue_script( '{script['handle']}' );
\t}}
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
        "generator": "WordPressHx SDK-063 deterministic editor emitter",
        "source": plan["source"]["haxeEntry"],
        "domain": domain,
        "locale_data": {domain: messages},
    }


def emit(plan_path: Path, bundle_root: Path, output_root: Path) -> None:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    assert isinstance(plan, dict)
    validate(plan)
    assert not output_root.exists(), "output root already exists"
    assert bundle_root.is_dir(), "production bundle root is absent"
    script = plan["script"]
    source_bundle = bundle_root / script["filename"]
    source_asset = bundle_root / script["assetMetadataFilename"]
    assert source_bundle.is_file() and source_asset.is_file()
    assert digest(source_bundle) == script["productionBundleSha256"]
    assert parse_asset_php(source_asset) == {
        "dependencies": script["dependencies"],
        "version": script["productionVersion"],
    }

    build_root = output_root / "build"
    language_root = output_root / translations_relative(plan)
    build_root.mkdir(parents=True)
    language_root.mkdir(parents=True)
    shutil.copyfile(source_bundle, build_root / script["filename"])
    shutil.copyfile(source_asset, build_root / script["assetMetadataFilename"])
    (output_root / f"{plan['plugin']['slug']}.php").write_text(
        plugin_php(plan), encoding="utf-8"
    )
    translation_path = language_root / (
        f"{plan['translations']['domain']}-en_US-{script['handle']}.json"
    )
    translation_path.write_text(
        json.dumps(
            translation_document(plan),
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    files = {
        path.relative_to(output_root).as_posix(): digest(path)
        for path in sorted(output_root.rglob("*"))
        if path.is_file()
    }
    manifest = {
        "schemaVersion": 1,
        "generator": "wordpresshx-sdk063-editor-plugin-emitter-v1",
        "planSha256": digest(plan_path),
        "files": files,
    }
    (output_root / "generation-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def translations_relative(plan: dict[str, object]) -> str:
    value = plan["translations"]["relativePath"]
    assert value == "languages"
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    emit(args.plan.resolve(), args.bundle_root.resolve(), args.output_root.resolve())


if __name__ == "__main__":
    main()
