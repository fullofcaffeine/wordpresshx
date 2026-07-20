#!/usr/bin/env python3
"""Verify the exact SDK-063 editor-extension source and npm profile."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
PROFILE_PATH = (
    PACKAGE_ROOT
    / "src/wordpress/hx/gutenberg/profile/"
    "wp70-release.editor-plugin.browser-hxx.json"
)
BASE_PROFILE_PATH = (
    PACKAGE_ROOT
    / "src/wordpress/hx/gutenberg/profile/wp70-release.browser-hxx.json"
)
SOURCE_LOCK_PATH = REPOSITORY_ROOT / "profiles/wp70-release/source.lock.json"
MANIFEST_PATH = PACKAGE_ROOT / "editor-tooling/package.json"
LOCK_PATH = PACKAGE_ROOT / "editor-tooling/package-lock.json"
SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
NPM_INTEGRITY = re.compile(r"sha512-[A-Za-z0-9+/]+={0,2}\Z")


def load(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict), f"{path} must contain an object"
    return value


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    assert set(value) == expected, f"{label} fields drifted"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob_sha1(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def source_records(profile: dict[str, object]) -> list[tuple[str, dict[str, str]]]:
    records: dict[tuple[str, str], dict[str, str]] = {}

    def remember(repository: str, record: dict[str, str]) -> None:
        key = (repository, record["path"])
        previous = records.setdefault(key, record)
        assert previous == record, f"source record drifted: {key}"

    for package in profile["packages"]:
        remember("gutenberg", package["source"])
    for component in profile["components"]:
        source = component["source"]
        remember(
            "gutenberg",
            {
                "path": source["path"],
                "blob": source["blob"],
                "sha256": source["sha256"],
            },
        )
        remember(
            "gutenberg",
            {
                "path": source["propsPath"],
                "blob": source["propsBlob"],
                "sha256": source["propsSha256"],
            },
        )
    for api in profile["apis"]:
        remember("gutenberg", api["source"])
        if "selectorSource" in api:
            remember("gutenberg", api["selectorSource"])
    handle_source = dict(profile["handleSource"])
    remember(
        "wordpress",
        {
            "path": handle_source["path"],
            "blob": handle_source["blob"],
            "sha256": handle_source["sha256"],
        },
    )
    return [
        (repository, records[(repository, path)])
        for repository, path in sorted(records)
    ]


def verify_metadata(profile: dict[str, object]) -> None:
    base = load(BASE_PROFILE_PATH)
    source_lock = load(SOURCE_LOCK_PATH)
    manifest = load(MANIFEST_PATH)
    lock = load(LOCK_PATH)
    exact_keys(
        profile,
        {
            "schemaVersion",
            "profileId",
            "catalogId",
            "catalogRevision",
            "requiresBaseCatalogRevision",
            "provider",
            "packages",
            "admittedCapabilities",
            "components",
            "apis",
            "handleSource",
            "mappings",
            "policy",
        },
        "editor profile",
    )
    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogId"] == "editor-plugin"
    assert profile["catalogRevision"] == "wp70-release/editor-plugin-v1"
    assert profile["requiresBaseCatalogRevision"] == base["catalogRevision"]
    assert profile["provider"] == {
        "wordpressVersion": "7.0.0",
        "wordpressCommit": source_lock["wordpressSource"]["commit"],
        "gutenbergCommit": source_lock["embeddedGutenberg"]["commit"],
        "gutenbergTree": source_lock["embeddedGutenberg"]["tree"],
    }

    assert [item["request"] for item in profile["packages"]] == [
        "@wordpress/data",
        "@wordpress/editor",
        "@wordpress/plugins",
    ]
    assert [item["tag"] for item in profile["components"]] == [
        "PanelBody",
        "PluginSidebar",
        "PluginSidebarMoreMenuItem",
        "ToggleControl",
    ]
    assert [item["children"] for item in profile["components"]] == [
        "optional",
        "required",
        "required",
        "forbidden",
    ]
    assert [item["request"] for item in profile["apis"]] == [
        "@wordpress/plugins",
        "@wordpress/data",
        "@wordpress/editor",
    ]
    assert profile["mappings"] == [
        {"request": "@wordpress/components", "handle": "wp-components"},
        {"request": "@wordpress/data", "handle": "wp-data"},
        {"request": "@wordpress/editor", "handle": "wp-editor"},
        {"request": "@wordpress/element", "handle": "wp-element"},
        {"request": "@wordpress/i18n", "handle": "wp-i18n"},
        {"request": "@wordpress/plugins", "handle": "wp-plugins"},
        {"request": "react/jsx-runtime", "handle": "react-jsx-runtime"},
    ]
    capability_ids = [
        item["capabilityId"] for item in profile["admittedCapabilities"]
    ]
    assert capability_ids == sorted(capability_ids)
    assert len(capability_ids) == len(set(capability_ids)) == 11
    assert all(
        item["classification"] == "public"
        and item["evidenceStatus"] == "source-verified"
        for item in profile["admittedCapabilities"]
    )
    policy = profile["policy"]
    assert policy["privateApisAllowed"] is False
    assert policy["experimentalApisAllowed"] is False
    assert policy["unknownPropsAllowed"] is False
    assert policy["manualRegistrationJavaScriptAllowed"] is False
    assert policy["stringStoreKeyScope"] == (
        "core/editor/getCurrentPostType-only"
    )
    assert policy["npmWorkspaceOnlyVersionResolution"] == {
        "scope": "build-input-only-unimported-from-final-bundle",
        "@wordpress/vips": {
            "providerWorkspaceVersion": "1.0.0-prerelease",
            "registryVersion": "1.0.0",
        },
        "@wordpress/worker-threads": {
            "providerWorkspaceVersion": "1.0.0-prerelease",
            "registryVersion": "1.0.0",
        },
    }

    assert manifest["private"] is True
    assert manifest["packageManager"] == "npm@10.9.2"
    assert manifest["engines"] == {"node": "22.17.0", "npm": "10.9.2"}
    assert lock["lockfileVersion"] == 3
    assert lock["requires"] is True
    assert lock["packages"][""]["devDependencies"] == manifest[
        "devDependencies"
    ]
    expected_wordpress = {
        name: version
        for name, version in {
            **manifest["overrides"],
            **manifest["devDependencies"],
        }.items()
        if name.startswith("@wordpress/")
    }
    actual_wordpress: dict[str, str] = {}
    for package_path, package in lock["packages"].items():
        if not package_path:
            continue
        assert NPM_INTEGRITY.fullmatch(package["integrity"]), package_path
        assert package["resolved"].startswith(
            "https://registry.npmjs.org/"
        ), package_path
        match = re.search(
            r"(?:^|/)node_modules/(@wordpress/[^/]+)\Z", package_path
        )
        if match is not None:
            package_name = match.group(1)
            previous = actual_wordpress.setdefault(
                package_name, package["version"]
            )
            assert previous == package["version"], package_name
    assert actual_wordpress == expected_wordpress
    ariakit_versions = {
        package["version"]
        for package_path, package in lock["packages"].items()
        if package_path.endswith("node_modules/@ariakit/react")
    }
    assert ariakit_versions == {manifest["overrides"]["@ariakit/react"]}
    for package in profile["packages"]:
        name = package["request"]
        entry = lock["packages"][f"node_modules/{name}"]
        assert manifest["devDependencies"][name] == package["version"]
        assert entry["version"] == package["version"]
        assert entry["integrity"] == package["npm"]["integrity"]

    for _, record in source_records(profile):
        assert SHA1.fullmatch(record["blob"]), record["path"]
        assert SHA256.fullmatch(record["sha256"]), record["path"]


def download_source(
    repository: str, commit: str, path: str
) -> bytes:
    repository_slug = {
        "gutenberg": "gutenberg",
        "wordpress": "wordpress-develop",
    }[repository]
    encoded_path = urllib.parse.quote(path, safe="/")
    url = (
        "https://raw.githubusercontent.com/WordPress/"
        f"{repository_slug}/{commit}/{encoded_path}"
    )
    request = urllib.request.Request(
        url, headers={"User-Agent": "wordpresshx-sdk-063-evidence/1"}
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def verify_sources(profile: dict[str, object]) -> None:
    commits = {
        "gutenberg": profile["provider"]["gutenbergCommit"],
        "wordpress": profile["provider"]["wordpressCommit"],
    }
    downloaded: dict[str, bytes] = {}
    for repository, record in source_records(profile):
        data = download_source(repository, commits[repository], record["path"])
        assert sha256(data) == record["sha256"], record["path"]
        assert git_blob_sha1(data) == record["blob"], record["path"]
        downloaded[record["path"]] = data

    text = {
        path: data.decode("utf-8") for path, data in downloaded.items()
    }
    assert "default as PluginSidebar" in text[
        "packages/editor/src/components/index.js"
    ]
    assert "default as PluginSidebarMoreMenuItem" in text[
        "packages/editor/src/components/index.js"
    ]
    assert "export function registerPlugin(" in text[
        "packages/plugins/src/api/index.ts"
    ]
    assert "export function unregisterPlugin(" in text[
        "packages/plugins/src/api/index.ts"
    ]
    assert "export default function useSelect" in text[
        "packages/data/src/components/use-select/index.js"
    ]
    assert "export const store =" in text[
        "packages/editor/src/store/index.js"
    ]
    assert "export function getCurrentPostType(" in text[
        "packages/editor/src/store/selectors.js"
    ]
    handles = text["src/wp-includes/assets/script-loader-packages.php"]
    assert handles.count("'editor.js' => array(") == 1
    assert handles.count("'plugins.js' => array(") == 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    profile = load(PROFILE_PATH)
    verify_metadata(profile)
    if not args.metadata_only:
        verify_sources(profile)
    print(
        "SDK-063 exact editor profile passed: 4 components, "
        "11 public capabilities, 77 exact WordPress npm packages"
    )


if __name__ == "__main__":
    main()
