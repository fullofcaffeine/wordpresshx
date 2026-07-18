#!/usr/bin/env python3
"""Verify the exact SDK-080 parser release and transitive source closure."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PACKAGE_ROOT.parents[1]
LOCK_PATH = PACKAGE_ROOT / "dependency-lock.json"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def assert_hex(value: str, length: int, label: str) -> None:
    assert len(value) == length, f"{label} has wrong length"
    assert all(character in "0123456789abcdef" for character in value), (
        f"{label} is not lowercase hexadecimal"
    )


def verify_metadata(lock: dict) -> None:
    assert lock["schemaVersion"] == 1
    assert lock["status"] == "resolved-sdk-080"
    assert lock["toolchain"]["haxe"] == "4.3.7"
    assert lock["toolchain"]["lix"]["version"] == "15.12.4"
    assert lock["toolchain"]["lix"]["reportedCliVersion"] == "15.12.2"
    assert_hex(
        lock["toolchain"]["lix"]["artifact"]["sha256"],
        64,
        "Lix artifact",
    )
    assert lock["parser"]["name"] == "tink_hxx"
    assert lock["parser"]["version"] == "0.25.1"
    assert lock["parser"]["tag"] == "0.25.1"
    assert len(lock["dependencies"]) == 5
    assert [item["name"] for item in lock["dependencies"]] == sorted(
        item["name"] for item in lock["dependencies"]
    )

    for field in ("commit", "tree"):
        assert_hex(lock["parser"][field], 40, f"parser {field}")
    assert_hex(lock["parser"]["artifact"]["sha256"], 64, "parser artifact")

    for dependency in lock["dependencies"]:
        if dependency["sourceKind"] == "haxelib":
            assert_hex(dependency["sha256"], 64, dependency["name"])
        elif dependency["sourceKind"] == "git":
            assert_hex(dependency["commit"], 40, dependency["name"])
            assert_hex(dependency["tree"], 40, dependency["name"])
        else:
            raise AssertionError(
                f"unknown source kind for {dependency['name']}: "
                f"{dependency['sourceKind']}"
            )

    policy = lock["policy"]
    assert policy["compileTimeOnly"] is True
    assert policy["floatingVersionsAllowed"] is False
    assert policy["haxelibDevAllowed"] is False
    assert policy["repositoryRelativeDependencyAllowed"] is False

    haxerc = json.loads((PACKAGE_ROOT / ".haxerc").read_text(encoding="utf-8"))
    assert haxerc == {"version": "4.3.7", "resolveLibs": "scoped"}

    hxml_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((PACKAGE_ROOT / "haxe_libraries").glob("*.hxml"))
    )
    for dependency in [lock["parser"], *lock["dependencies"]]:
        assert dependency["name"] in hxml_text
        assert dependency["version"] in hxml_text
        if dependency.get("sourceKind") == "git":
            assert dependency["commit"] in hxml_text
    assert "=dev" not in hxml_text
    assert "../" not in hxml_text

    architecture = json.loads(
        (REPOSITORY_ROOT / "manifests/hxx-architecture.json").read_text(
            encoding="utf-8"
        )
    )
    parser = architecture["parser"]
    assert parser["releaseArtifactAndTransitivesResolved"] is True
    assert parser["dependencyLock"] == "packages/hxx/dependency-lock.json"
    assert parser["releaseArtifact"]["sha256"] == lock["parser"]["artifact"][
        "sha256"
    ]


def download(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "wordpresshx-sdk-080-evidence/1"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def verify_artifact(name: str, artifact: dict) -> bytes:
    data = download(artifact["url"])
    assert len(data) == artifact["sizeBytes"], f"{name} artifact size mismatch"
    assert sha256(data) == artifact["sha256"], f"{name} artifact digest mismatch"
    return data


def verify_haxelib(entry: dict) -> None:
    artifact = entry.get("artifact", entry)
    data = verify_artifact(entry["name"], artifact)
    with tempfile.NamedTemporaryFile(suffix=".zip") as archive_file:
        archive_file.write(data)
        archive_file.flush()
        with zipfile.ZipFile(archive_file.name) as archive:
            metadata = json.loads(archive.read("haxelib.json"))
    assert metadata["name"] == entry["name"]
    assert metadata["version"] == entry["version"]
    if entry["name"] == "tink_hxx":
        assert set(metadata["dependencies"]) == {
            "html-entities",
            "tink_anon",
            "tink_parse",
        }


def verify_git(entry: dict, selected_dependencies: list[dict] | None = None) -> None:
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk080-git-") as root:
        subprocess.run(["git", "init", "--quiet", root], check=True)
        fetch_command = [
            "git",
            "-C",
            root,
            "fetch",
            "--quiet",
            "--depth=1",
            "--no-auto-maintenance",
            entry["repository"],
            entry["commit"],
        ]
        assert fetch_command.count("--no-auto-maintenance") == 1
        subprocess.run(fetch_command, check=True)
        commit = subprocess.check_output(
            ["git", "-C", root, "rev-parse", "FETCH_HEAD"], text=True
        ).strip()
        tree = subprocess.check_output(
            ["git", "-C", root, "rev-parse", "FETCH_HEAD^{tree}"], text=True
        ).strip()
        if "tag" in entry:
            tag_ref = f"refs/tags/{entry['tag']}"
            tag_lines = subprocess.check_output(
                ["git", "ls-remote", "--tags", entry["repository"], tag_ref],
                text=True,
            ).splitlines()
            assert tag_lines == [f"{entry['commit']}\t{tag_ref}"], (
                f"{entry['name']} tag does not resolve directly to the pinned commit"
            )
        if selected_dependencies is not None:
            selected_paths = []
            for dependency in selected_dependencies:
                source_path = f"haxe_libraries/{dependency['name']}.hxml"
                selected_paths.append(source_path)
                content = subprocess.check_output(
                    ["git", "-C", root, "show", f"FETCH_HEAD:{source_path}"],
                    text=True,
                )
                assert dependency["version"] in content
                if dependency["sourceKind"] == "git":
                    assert dependency["commit"] in content
                else:
                    assert f"haxelib:/{dependency['name']}" in content
            assert selected_paths == sorted(
                json.loads(LOCK_PATH.read_text(encoding="utf-8"))[
                    "selectionOrigin"
                ]["paths"]
            )
    assert commit == entry["commit"], f"{entry['name']} commit mismatch"
    assert tree == entry["tree"], f"{entry['name']} tree mismatch"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="validate lock/linkage without network materialization",
    )
    arguments = parser.parse_args()

    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    verify_metadata(lock)
    if not arguments.metadata_only:
        verify_artifact("lix", lock["toolchain"]["lix"]["artifact"])
        verify_haxelib(lock["parser"])
        verify_git(lock["parser"], lock["dependencies"])
        for dependency in lock["dependencies"]:
            if dependency["sourceKind"] == "haxelib":
                verify_haxelib(dependency)
            else:
                verify_git(dependency)
    print("SDK-080 exact HXX parser dependency lock passed")


if __name__ == "__main__":
    main()
