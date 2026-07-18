#!/usr/bin/env python3
"""Verify the closed SDK-033 provider profile and npm build closure."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
PROFILE_PATH = (
    PACKAGE_ROOT
    / "src/wordpress/hx/gutenberg/profile/wp70-release.browser-assets.json"
)
ENTRY_PLAN_PATH = PACKAGE_ROOT / "test/assets-runtime/entry-plan.json"
CATALOG_PATH = (
    REPOSITORY_ROOT / "generated/wp70-release/catalog-v1/catalog.json"
)
TOOLCHAIN_PATH = REPOSITORY_ROOT / "manifests/toolchain.lock.json"
MANIFEST_PATH = PACKAGE_ROOT / "build-tooling/package.json"
LOCK_PATH = PACKAGE_ROOT / "build-tooling/package-lock.json"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
NPM_INTEGRITY = re.compile(r"sha512-[A-Za-z0-9+/]+={0,2}\Z")


def load(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict), f"{path} must contain an object"
    return value


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    assert set(value) == expected, f"{label} fields drifted"


def main() -> None:
    profile = load(PROFILE_PATH)
    exact_keys(
        profile,
        {
            "schemaVersion",
            "profileId",
            "catalogRevision",
            "provider",
            "build",
            "mappingSource",
            "mappings",
            "policy",
        },
        "browser-assets profile",
    )
    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogRevision"] == "wp70-release/catalog-v1"
    assert profile["provider"] == {
        "wordpressVersion": "7.0.0",
        "wordpressCommit": "26b68024931348d267b70e2a29910e1320d0094f",
        "gutenbergCommit": "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd",
        "gutenbergTree": "8bd91d6b490d79ef991d388409705b5cd06fdc94",
    }
    assert profile["build"] == {
        "adapter": "@wordpress/scripts",
        "adapterVersion": "31.5.0",
        "dependencyExtraction": (
            "@wordpress/dependency-extraction-webpack-plugin"
        ),
        "dependencyExtractionVersion": "6.40.0",
        "externalizedReportOption": True,
    }
    mapping_source = profile["mappingSource"]
    assert isinstance(mapping_source, dict)
    assert mapping_source == {
        "path": "packages/dependency-extraction-webpack-plugin/lib/util.js",
        "blob": "11211cf0f2ef9d8c106c104c57226dac735f4205",
        "sha256": (
            "3f6a43e202b158297dc95da9d8a40127118469a856d8eae94459cb89528c7367"
        ),
    }
    assert profile["policy"] == {
        "scriptModules": False,
        "manualAssetPhpEditingAllowed": False,
        "finalBundleIsAuthority": True,
        "developmentProductionDependencySetParityRequired": True,
        "translationsAttachToFinalHandle": True,
    }

    expected_mappings = {
        "@wordpress/blocks": (
            "wp-blocks",
            "gutenberg.package.@wordpress/blocks",
            "wordpress.script-handle.wp-blocks",
        ),
        "@wordpress/components": (
            "wp-components",
            "gutenberg.package.@wordpress/components",
            "wordpress.script-handle.wp-components",
        ),
        "@wordpress/data": (
            "wp-data",
            "gutenberg.package.@wordpress/data",
            "wordpress.script-handle.wp-data",
        ),
        "@wordpress/element": (
            "wp-element",
            "gutenberg.package.@wordpress/element",
            "wordpress.script-handle.wp-element",
        ),
        "@wordpress/i18n": (
            "wp-i18n",
            "gutenberg.package.@wordpress/i18n",
            "wordpress.script-handle.wp-i18n",
        ),
        "react": (
            "react",
            None,
            "wordpress.script-handle.react",
        ),
        "react-dom": (
            "react-dom",
            None,
            "wordpress.script-handle.react-dom",
        ),
        "react/jsx-runtime": (
            "react-jsx-runtime",
            None,
            "wordpress.script-handle.react-jsx-runtime",
        ),
    }
    mappings = profile["mappings"]
    assert isinstance(mappings, list)
    assert [item["request"] for item in mappings] == list(expected_mappings)

    catalog = load(CATALOG_PATH)
    capabilities = {
        item["capabilityId"]: item
        for item in catalog["catalog"]["capabilities"]
    }
    for mapping in mappings:
        exact_keys(
            mapping,
            {
                "request",
                "handle",
                "packageCapability",
                "handleCapability",
            },
            f"mapping {mapping['request']}",
        )
        expected = expected_mappings[mapping["request"]]
        assert (
            mapping["handle"],
            mapping["packageCapability"],
            mapping["handleCapability"],
        ) == expected
        handle_capability = capabilities[mapping["handleCapability"]]
        assert handle_capability["kind"] == "script-handle"
        assert handle_capability["classification"] == "public"
        assert handle_capability["evidenceStatus"] == "inventoried"
        package_capability_id = mapping["packageCapability"]
        if package_capability_id is not None:
            package_capability = capabilities[package_capability_id]
            assert package_capability["kind"] == "gutenberg-package"
            assert package_capability["classification"] == "public"
            assert package_capability["evidenceStatus"] == "inventoried"

    entry_plan = load(ENTRY_PLAN_PATH)
    exact_keys(
        entry_plan,
        {
            "schemaVersion",
            "profileId",
            "entryId",
            "sourceEntry",
            "scriptFilename",
            "scriptHandle",
            "textDomain",
            "translationRelativePath",
            "browserExportId",
            "plugin",
        },
        "entry plan",
    )
    assert entry_plan["schemaVersion"] == 1
    assert entry_plan["profileId"] == profile["profileId"]
    assert entry_plan["sourceEntry"] == "src/editor.tsx"
    assert entry_plan["scriptFilename"] == "editor.js"
    assert entry_plan["scriptHandle"] == "wordpresshx-sdk033-editor"
    assert entry_plan["textDomain"] == "wordpresshx-sdk033"
    assert entry_plan["translationRelativePath"] == "languages"
    assert entry_plan["browserExportId"] == (
        "wordpresshx.sdk033.editor-panel"
    )
    assert entry_plan["plugin"] == {
        "slug": "wordpresshx-sdk033-assets",
        "name": "WordPressHx SDK-033 Asset Proof",
        "version": "0.0.0",
        "requiresWordPress": "7.0",
        "requiresPhp": "7.4",
    }

    manifest = load(MANIFEST_PATH)
    lock = load(LOCK_PATH)
    assert manifest["private"] is True
    assert manifest["packageManager"] == "npm@10.9.2"
    assert manifest["engines"] == {"node": "22.17.0", "npm": "10.9.2"}
    assert "scripts" not in manifest
    assert lock["lockfileVersion"] == 3
    assert lock["requires"] is True
    assert lock["packages"][""]["devDependencies"] == manifest[
        "devDependencies"
    ]
    for package_path, package in lock["packages"].items():
        if not package_path:
            continue
        assert NPM_INTEGRITY.fullmatch(package["integrity"]), package_path
        assert package["resolved"].startswith(
            "https://registry.npmjs.org/"
        ), package_path

    toolchain = load(TOOLCHAIN_PATH)
    graphs = toolchain["dependencyGraphs"]["npm"]["externalGraphs"]
    asset_graph = next(
        item
        for item in graphs
        if item["id"] == "sdk-033-wordpress-assets-verification-graph"
    )
    assert asset_graph["profileSha256"] == digest(PROFILE_PATH)
    assert asset_graph["manifestSha256"] == digest(MANIFEST_PATH)
    assert asset_graph["lockSha256"] == digest(LOCK_PATH)
    assert asset_graph["runtimeImage"] == toolchain["runtimeImages"]["node"][
        "reference"
    ]
    assert asset_graph["lifecycleScriptsAllowed"] is False
    assert asset_graph["buildInputOnly"] is True
    assert asset_graph["advisoryFollowUp"] == "wordpresshx-g2.3"
    assert asset_graph["receiptId"] == "SDK-033-WORDPRESS-ASSET-METADATA"
    assert SHA256.fullmatch(asset_graph["lockSha256"])

    print(
        "SDK-033 assets profile passed: official mapping, 8 exact handles, "
        f"{len(lock['packages']) - 1} integrity-locked build packages"
    )


if __name__ == "__main__":
    main()
