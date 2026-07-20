#!/usr/bin/env python3
"""Verify the exact WordPress 7.0 SDK-061 browser profile and lock closure."""

from __future__ import annotations

import json
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parent.parent
PROFILE_PATH = (
    PACKAGE_ROOT
    / "src/wordpress/hx/gutenberg/profile/wp70-release.static-block.browser-hxx.json"
)
MANIFEST_PATH = PACKAGE_ROOT / "editor-tooling/package.json"
LOCK_PATH = PACKAGE_ROOT / "editor-tooling/package-lock.json"


def load(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict), f"{path} must contain an object"
    return value


def exact(value: dict[str, object], keys: set[str], label: str) -> None:
    assert set(value) == keys, f"{label} fields drifted: {set(value) ^ keys}"


def main() -> None:
    profile = load(PROFILE_PATH)
    manifest = load(MANIFEST_PATH)
    lock = load(LOCK_PATH)
    exact(
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
            "mappings",
            "policy",
        },
        "static block profile",
    )
    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogId"] == "static-block"
    assert profile["catalogRevision"] == "wp70-release/static-block-v1"
    assert profile["requiresBaseCatalogRevision"] == "wp70-release/catalog-v1"
    assert profile["provider"] == {
        "wordpressVersion": "7.0.0",
        "wordpressCommit": "26b68024931348d267b70e2a29910e1320d0094f",
        "gutenbergCommit": "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd",
        "gutenbergTree": "8bd91d6b490d79ef991d388409705b5cd06fdc94",
    }
    assert profile["policy"] == {
        "privateApisAllowed": False,
        "experimentalApisAllowed": False,
        "componentCatalogGeneratedOrCurated": (
            "curated-exact-source-and-published-runtime"
        ),
        "unknownPropsAllowed": False,
        "manualRegistrationJavaScriptAllowed": False,
        "deprecationsOrderedAndImmutable": True,
    }

    expected_packages = {
        "@wordpress/block-editor": {
            "version": "15.13.0",
            "handle": "wp-block-editor",
            "integrity": (
                "sha512-84gio2OjIfcs/Kx/R3n+tEOXhTrdZ4YnwMA3p6Yya4m4kJR5Mdn4ysCGieMmQY3zbd2vR38O3mGdGOx47sIMCw=="
            ),
            "shasum": "fe9a272e9f5dcaef40a6f831849cc090c2c9e908",
        },
        "@wordpress/blocks": {
            "version": "15.13.0",
            "handle": "wp-blocks",
            "integrity": (
                "sha512-e1OEv472ZGi5zL154TWASO/wYxbH5845C42thbp9sBis1zB31bkUriIxpn2vqmJV22uFnh0L31uBLTkQAp5BiQ=="
            ),
            "shasum": "1bd3f815abc33bce0cff7be9755554ec418c132a",
        },
    }
    packages = profile["packages"]
    assert isinstance(packages, list)
    assert [entry["request"] for entry in packages] == sorted(expected_packages)
    lock_packages = lock["packages"]
    assert isinstance(lock_packages, dict)
    overrides = manifest["overrides"]
    assert isinstance(overrides, dict)
    for entry in packages:
        request = entry["request"]
        expected = expected_packages[request]
        assert entry["version"] == expected["version"]
        assert entry["wordpressHandle"] == expected["handle"]
        assert entry["npm"]["integrity"] == expected["integrity"]
        assert entry["npm"]["shasum"] == expected["shasum"]
        assert overrides[request] == expected["version"]
        locked = lock_packages[f"node_modules/{request}"]
        assert locked["version"] == expected["version"]
        assert locked["integrity"] == expected["integrity"]

    components = profile["components"]
    assert isinstance(components, list) and len(components) == 1
    assert components[0]["tag"] == "PlainText"
    assert components[0]["haxeType"] == "wordpress.hx.gutenberg.block.PlainText"
    assert components[0]["propsType"] == (
        "wordpress.hx.gutenberg.block.PlainTextProps"
    )
    assert components[0]["children"] == "forbidden"
    assert components[0]["request"] == "@wordpress/block-editor"
    assert components[0]["export"] == "PlainText"

    capabilities = profile["admittedCapabilities"]
    assert isinstance(capabilities, list)
    assert all(entry["classification"] == "public" for entry in capabilities)
    assert all(entry["evidenceStatus"] == "source-verified" for entry in capabilities)
    assert [entry["capabilityId"] for entry in capabilities] == sorted(
        entry["capabilityId"] for entry in capabilities
    )
    assert profile["mappings"] == [
        {"request": "@wordpress/block-editor", "handle": "wp-block-editor"},
        {"request": "@wordpress/blocks", "handle": "wp-blocks"},
        {"request": "@wordpress/element", "handle": "wp-element"},
        {"request": "react/jsx-runtime", "handle": "react-jsx-runtime"},
    ]
    print("SDK-061 exact static-block profile passed")


if __name__ == "__main__":
    main()
