#!/usr/bin/env python3
"""Verify the exact SDK-032 React/Gutenberg HXX source profile."""

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
    / "src/wordpress/hx/gutenberg/profile/wp70-release.browser-hxx.json"
)
SOURCE_LOCK_PATH = REPOSITORY_ROOT / "profiles/wp70-release/source.lock.json"
TOOLING_MANIFEST_PATH = PACKAGE_ROOT / "hxx-tooling/package.json"
TOOLING_LOCK_PATH = PACKAGE_ROOT / "hxx-tooling/package-lock.json"

SHA1 = re.compile(r"[0-9a-f]{40}\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
NPM_INTEGRITY = re.compile(r"sha512-[A-Za-z0-9+/]+={0,2}\Z")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob_sha1(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def source_records(profile: dict) -> list[dict]:
    records = [profile["provider"]["dependencyLock"], profile["hookSource"]]
    for component in profile["components"]:
        source = component["source"]
        records.append(
            {
                "path": source["path"],
                "blob": source["blob"],
                "sha256": source["sha256"],
            }
        )
        records.append(
            {
                "path": source["propsPath"],
                "blob": source["propsBlob"],
                "sha256": source["propsSha256"],
            }
        )
    unique = {record["path"]: record for record in records}
    assert len(unique) == 5, "SDK-032 source inventory changed"
    return [unique[path] for path in sorted(unique)]


def verify_metadata(profile: dict) -> None:
    source_lock = load_json(SOURCE_LOCK_PATH)
    manifest = load_json(TOOLING_MANIFEST_PATH)
    lock = load_json(TOOLING_LOCK_PATH)

    assert profile["schemaVersion"] == 1
    assert profile["profileId"] == "wp70-release"
    assert profile["catalogRevision"] == "wp70-release/catalog-v1"
    assert profile["provider"] == {
        "wordpressVersion": "7.0.0",
        "wordpressCommit": "26b68024931348d267b70e2a29910e1320d0094f",
        "gutenbergCommit": "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd",
        "gutenbergTree": "8bd91d6b490d79ef991d388409705b5cd06fdc94",
        "dependencyLock": {
            "path": "package-lock.json",
            "blob": "b45618b56375df75595ba7184f688cebf41795f8",
            "sha256": (
                "48a76d63400289c1e80ca9685651157f"
                "d49d7eded233a68cb19ced59f78cc9ee"
            ),
        },
    }
    assert source_lock["profileId"] == profile["profileId"]
    assert source_lock["catalogRevision"] == profile["catalogRevision"]
    assert (
        source_lock["wordpressSource"]["commit"]
        == profile["provider"]["wordpressCommit"]
    )
    assert (
        source_lock["embeddedGutenberg"]["commit"]
        == profile["provider"]["gutenbergCommit"]
    )
    assert (
        source_lock["embeddedGutenberg"]["tree"]
        == profile["provider"]["gutenbergTree"]
    )

    assert profile["react"] == {
        "runtimeVersion": "18.3.1",
        "typesVersion": "18.3.27",
        "jsxRuntimeRequest": "react/jsx-runtime",
        "wordpressHandle": "react-jsx-runtime",
    }
    assert [(item["tag"], item["children"]) for item in profile["components"]] == [
        ("Button", "optional"),
        ("Notice", "required"),
    ]
    assert profile["hooks"] == [
        "createContext",
        "useContext",
        "useEffect",
        "useRef",
        "useState",
    ]
    assert profile["policy"] == {
        "rawJsxAllowed": False,
        "browserHxxRuntimeAllowed": False,
        "openAttributeSpreadsAllowed": False,
        "profileGeneratedOrCurated": "curated-exact-source-and-published-types",
    }
    for record in source_records(profile):
        assert SHA1.fullmatch(record["blob"]), record["path"]
        assert SHA256.fullmatch(record["sha256"]), record["path"]

    assert manifest["private"] is True
    assert manifest["packageManager"] == "npm@10.9.2"
    assert manifest["engines"] == {"node": "22.17.0", "npm": "10.9.2"}
    assert lock["lockfileVersion"] == 3
    assert lock["packages"][""]["devDependencies"] == manifest["devDependencies"]
    for package in profile["packages"]:
        package_name = package["request"]
        assert manifest["devDependencies"][package_name] == package["version"]
        entry = lock["packages"][f"node_modules/{package_name}"]
        assert entry["version"] == package["version"]
        assert entry["integrity"] == package["npm"]["integrity"]
        assert NPM_INTEGRITY.fullmatch(entry["integrity"])


def download_source(commit: str, path: str) -> bytes:
    encoded_path = urllib.parse.quote(path, safe="/")
    url = f"https://raw.githubusercontent.com/WordPress/gutenberg/{commit}/{encoded_path}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "wordpresshx-sdk-032-evidence/1"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def verify_sources(profile: dict) -> None:
    commit = profile["provider"]["gutenbergCommit"]
    downloaded: dict[str, bytes] = {}
    for record in source_records(profile):
        data = download_source(commit, record["path"])
        assert sha256(data) == record["sha256"], (
            f"source digest mismatch: {record['path']}"
        )
        assert git_blob_sha1(data) == record["blob"], (
            f"source blob mismatch: {record['path']}"
        )
        downloaded[record["path"]] = data

    provider_lock = json.loads(downloaded["package-lock.json"])
    tooling_lock = load_json(TOOLING_LOCK_PATH)
    tooling_packages = tooling_lock["packages"]
    provider_packages = provider_lock["packages"]
    wordpress_versions: dict[str, str] = {}
    for package_path, entry in tooling_packages.items():
        match = re.search(r"(?:^|/)node_modules/(@wordpress/[^/]+)\Z", package_path)
        if match is None:
            continue
        package_name = match.group(1)
        previous = wordpress_versions.setdefault(package_name, entry["version"])
        assert previous == entry["version"], f"split tooling version: {package_name}"
    assert len(wordpress_versions) == 24
    for package_name, version in sorted(wordpress_versions.items()):
        package_path = f"node_modules/{package_name}"
        provider_entry = provider_packages[package_path]
        if provider_entry.get("link") is True:
            provider_entry = provider_packages[provider_entry["resolved"]]
        assert version == provider_entry["version"], (
            f"provider version drift: {package_name}"
        )
    tooling_ariakit_versions = {
        entry["version"]
        for package_path, entry in tooling_packages.items()
        if package_path.endswith("node_modules/@ariakit/react")
    }
    provider_ariakit_versions = {
        entry["version"]
        for package_path, entry in provider_packages.items()
        if package_path.endswith("node_modules/@ariakit/react")
        and "version" in entry
    }
    assert tooling_ariakit_versions == provider_ariakit_versions == {"0.4.21"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="validate committed cross-locks without fetching immutable sources",
    )
    args = parser.parse_args()
    profile = load_json(PROFILE_PATH)
    verify_metadata(profile)
    if not args.metadata_only:
        verify_sources(profile)
    print("SDK-032 exact React/Gutenberg HXX profile passed")


if __name__ == "__main__":
    main()
