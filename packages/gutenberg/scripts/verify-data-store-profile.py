#!/usr/bin/env python3
"""Verify the exact SDK-064 WordPress data-store source profile."""

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
    "wp70-release.data-store.browser-hxx.json"
)
EDITOR_PROFILE_PATH = (
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


def load(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict), f"{path} must contain an object"
    return value


def exact_keys(
    value: dict[str, object], expected: set[str], label: str
) -> None:
    assert set(value) == expected, f"{label} fields drifted"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def blob_identity(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def profile_sources(
    profile: dict[str, object],
) -> list[dict[str, str]]:
    records: dict[str, dict[str, str]] = {}

    def remember(record: dict[str, str]) -> None:
        previous = records.setdefault(record["path"], record)
        assert previous == record, f"source record drifted: {record['path']}"

    remember(profile["package"]["source"])
    for api in profile["apis"]:
        remember(api["source"])
        for source in api["exportSources"]:
            remember(
                {
                    "path": source["path"],
                    "blob": source["blob"],
                    "sha256": source["sha256"],
                }
            )
    return [records[path] for path in sorted(records)]


def verify_metadata(profile: dict[str, object]) -> None:
    base = load(BASE_PROFILE_PATH)
    editor = load(EDITOR_PROFILE_PATH)
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
            "componentCatalogSource",
            "provider",
            "package",
            "admittedCapabilities",
            "components",
            "apis",
            "mappings",
            "policy",
        },
        "data-store profile",
    )
    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogId"] == "data-store"
    assert profile["catalogRevision"] == "wp70-release/data-store-v1"
    assert profile["requiresBaseCatalogRevision"] == base["catalogRevision"]
    assert profile["provider"] == {
        "wordpressVersion": "7.0.0",
        "wordpressCommit": source_lock["wordpressSource"]["commit"],
        "gutenbergCommit": source_lock["embeddedGutenberg"]["commit"],
        "gutenbergTree": source_lock["embeddedGutenberg"]["tree"],
    }

    editor_bytes = EDITOR_PROFILE_PATH.read_bytes()
    assert profile["componentCatalogSource"] == {
        "catalogId": editor["catalogId"],
        "catalogRevision": editor["catalogRevision"],
        "path": EDITOR_PROFILE_PATH.relative_to(
            REPOSITORY_ROOT
        ).as_posix(),
        "sha256": digest(editor_bytes),
    }
    assert profile["components"] == editor["components"]
    assert profile["mappings"] == editor["mappings"]
    assert profile["package"] == editor["packages"][0]

    capability_ids = [
        item["capabilityId"] for item in profile["admittedCapabilities"]
    ]
    assert capability_ids == sorted(capability_ids)
    assert len(capability_ids) == len(set(capability_ids)) == 9
    assert all(
        item["classification"] == "public"
        and item["evidenceStatus"] == "source-verified"
        for item in profile["admittedCapabilities"]
    )
    assert profile["apis"] == [
        {
            **profile["apis"][0],
            "request": "@wordpress/data",
            "exports": [
                "createReduxStore",
                "dispatch",
                "register",
                "select",
                "subscribe",
                "useDispatch",
                "useSelect",
            ],
        }
    ]
    assert [
        source["export"] for source in profile["apis"][0]["exportSources"]
    ] == profile["apis"][0]["exports"]

    policy = profile["policy"]
    assert policy == {
        "privateApisAllowed": False,
        "experimentalApisAllowed": False,
        "componentCatalogGeneratedOrCurated": (
            "curated-exact-source-and-published-types"
        ),
        "customStoreContract": "closed-action-and-immutable-snapshot",
        "legacyStringStoreAccessAllowed": False,
        "manualRegistrationJavaScriptAllowed": False,
    }
    package = profile["package"]
    assert manifest["devDependencies"]["@wordpress/data"] == package[
        "version"
    ]
    locked = lock["packages"]["node_modules/@wordpress/data"]
    assert locked["version"] == package["version"]
    assert locked["integrity"] == package["npm"]["integrity"]

    for record in profile_sources(profile):
        assert SHA1.fullmatch(record["blob"]), record["path"]
        assert SHA256.fullmatch(record["sha256"]), record["path"]


def download(commit: str, path: str) -> bytes:
    encoded_path = urllib.parse.quote(path, safe="/")
    request = urllib.request.Request(
        "https://raw.githubusercontent.com/WordPress/"
        f"gutenberg/{commit}/{encoded_path}",
        headers={"User-Agent": "wordpresshx-sdk-064-evidence/1"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def verify_sources(profile: dict[str, object]) -> None:
    commit = profile["provider"]["gutenbergCommit"]
    downloaded: dict[str, str] = {}
    for record in profile_sources(profile):
        data = download(commit, record["path"])
        assert digest(data) == record["sha256"], record["path"]
        assert blob_identity(data) == record["blob"], record["path"]
        downloaded[record["path"]] = data.decode("utf-8")

    index = downloaded["packages/data/src/index.ts"]
    for export in (
        "createReduxStore",
        "dispatch",
        "select",
        "useDispatch",
    ):
        assert export in index
    assert "export const subscribe =" in index
    assert "export const register =" in index
    assert "export default function createReduxStore" in downloaded[
        "packages/data/src/redux-store/index.js"
    ]
    assert "export function dispatch" in downloaded[
        "packages/data/src/dispatch.ts"
    ]
    assert "export function select" in downloaded[
        "packages/data/src/select.ts"
    ]
    assert "const useDispatch" in downloaded[
        "packages/data/src/components/use-dispatch/use-dispatch.js"
    ]
    assert "export default function useSelect" in downloaded[
        "packages/data/src/components/use-select/index.js"
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    profile = load(PROFILE_PATH)
    verify_metadata(profile)
    if not args.metadata_only:
        verify_sources(profile)
    print(
        "SDK-064 exact data-store profile passed: "
        "7 public APIs, 9 capabilities, 1 immutable npm package"
    )


if __name__ == "__main__":
    main()
