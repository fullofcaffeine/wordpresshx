#!/usr/bin/env python3
"""Materialize and verify the exact Gutenberg 23.4 forward source and release."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = (
    ROOT / "profiles" / "gutenberg-forward-23.4" / "source.lock.json"
)
USER_AGENT = "wordpress-hx-sdk-source-verifier/0.1"


def run(*args: str, cwd: Path | None = None) -> bytes:
    completed = subprocess.run(
        args,
        cwd=cwd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def iso_instant(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(
        timezone.utc
    )


def git_text(repository: Path, *args: str) -> str:
    return run("git", "-C", str(repository), *args).decode().strip()


def fetch_commit(repository_url: str, commit: str, destination: Path) -> None:
    run("git", "init", "-q", str(destination))
    run(
        "git",
        "-C",
        str(destination),
        "fetch",
        "-q",
        "--depth=2",
        "--filter=blob:none",
        repository_url,
        commit,
    )
    assert git_text(destination, "rev-parse", "FETCH_HEAD^{commit}") == commit


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)


def archive_path(value: str) -> str:
    if not value or "\\" in value or "\x00" in value:
        raise AssertionError(f"unsafe archive path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise AssertionError(f"unsafe archive path: {value}")
    normalized = path.as_posix()
    if normalized in ("", "."):
        raise AssertionError(f"unsafe archive path: {value}")
    return normalized


def zip_contents(path: Path) -> dict[str, str]:
    contents: dict[str, str] = {}
    with zipfile.ZipFile(path) as archive:
        for member in archive.infolist():
            normalized = archive_path(member.filename)
            if member.is_dir():
                continue
            unix_mode = member.external_attr >> 16
            if unix_mode and (unix_mode & 0o170000) == 0o120000:
                raise AssertionError(f"unsupported ZIP symlink: {member.filename}")
            if normalized in contents:
                raise AssertionError(f"duplicate ZIP entry: {normalized}")
            contents[normalized] = sha256(archive.read(member))
    return contents


def content_tree_digest(contents: dict[str, str]) -> str:
    material = "".join(
        f"{contents[path]}  ./{path}\n" for path in sorted(contents)
    ).encode()
    return sha256(material)


def plugin_header(source: str, name: str) -> str:
    match = re.search(
        rf"^\s*\*\s*{re.escape(name)}:\s*(.*?)\s*$",
        source,
        re.MULTILINE,
    )
    if match is None:
        raise AssertionError(f"missing plugin header: {name}")
    return match.group(1)


def verify_artifact(path: Path, artifact: dict[str, object]) -> None:
    assert path.stat().st_size == artifact["sizeBytes"]
    assert sha256(path.read_bytes()) == artifact["sha256"]


def source_bytes(
    repository: Path, source_lock: dict[str, object], source_path: str
) -> bytes:
    evidence = source_lock["sourceEvidence"]
    assert isinstance(evidence, dict)
    expected = evidence[source_path]
    assert isinstance(expected, dict)
    assert (
        git_text(repository, "rev-parse", f"FETCH_HEAD:{source_path}")
        == expected["blob"]
    )
    content = run(
        "git", "-C", str(repository), "show", f"FETCH_HEAD:{source_path}"
    )
    assert sha256(content) == expected["sha256"]
    return content


def main() -> None:
    assert iso_instant("2000-01-01T00:00:00Z") == iso_instant(
        "2000-01-01T00:00:00+00:00"
    )
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        help="Reuse or populate an explicit artifact cache directory.",
    )
    args = parser.parse_args()

    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    source = lock["gutenbergSource"]
    distribution = lock["releaseDistribution"]
    assert lock["profileId"] == "gutenberg-forward-23.4"
    assert lock["wordpress70CompatibilityStatus"] == "forbidden"
    assert lock["supportStatus"] == "experimental"
    assert lock["releaseChannel"] == "preview-or-experimental"
    assert lock["prohibitions"]["distributionClaim"] is None
    assert source["tagKind"] == "lightweight"
    assert source["tagObjectType"] == "commit"

    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk011-") as temporary:
        temporary_root = Path(temporary)
        artifact_root = args.artifact_dir or temporary_root / "artifacts"
        artifact_root.mkdir(parents=True, exist_ok=True)

        repository = temporary_root / "gutenberg-source"
        fetch_commit(source["repository"], source["commit"], repository)
        assert (
            git_text(repository, "rev-parse", "FETCH_HEAD^{tree}")
            == source["tree"]
        )
        assert (
            git_text(repository, "rev-parse", "FETCH_HEAD^")
            == source["parent"]
        )
        assert iso_instant(
            git_text(repository, "show", "-s", "--format=%cI", "FETCH_HEAD")
        ) == iso_instant(source["committerDate"])
        assert (
            git_text(repository, "show", "-s", "--format=%s", "FETCH_HEAD")
            == source["subject"]
        )
        tag_line = run(
            "git",
            "ls-remote",
            source["repository"],
            f"refs/tags/{source['tag']}",
        ).decode().strip()
        assert tag_line == f"{source['commit']}\trefs/tags/{source['tag']}"

        package_bytes = source_bytes(repository, source, "package.json")
        plugin_bytes = source_bytes(repository, source, "gutenberg.php")
        content_types_bytes = source_bytes(
            repository, source, "packages/content-types/package.json"
        )
        evidence = source["sourceEvidence"]

        package = json.loads(package_bytes)
        package_lock = evidence["package.json"]
        assert package["name"] == package_lock["name"]
        assert package["version"] == package_lock["version"]
        assert package["private"] is package_lock["private"]
        assert package["engines"]["node"] == package_lock["node"]
        assert package["engines"]["npm"] == package_lock["npm"]
        matching_pages = [
            page
            for page in package["wpPlugin"]["pages"]
            if isinstance(page, dict) and page.get("id") == "content-types"
        ]
        assert len(matching_pages) == 1
        assert (
            matching_pages[0]["experimental"]
            is package_lock["experimentalPage"]
            is True
        )

        plugin = plugin_bytes.decode()
        plugin_lock = evidence["gutenberg.php"]
        assert plugin_header(plugin, "Version") == plugin_lock["pluginVersion"]
        assert (
            plugin_header(plugin, "Requires at least")
            == plugin_lock["minimumWordPress"]
        )
        assert plugin_header(plugin, "Requires PHP") == plugin_lock["minimumPhp"]

        content_types = json.loads(content_types_bytes)
        content_types_lock = evidence["packages/content-types/package.json"]
        assert content_types["name"] == content_types_lock["name"]
        assert content_types["version"] == content_types_lock["version"]
        assert content_types["private"] is content_types_lock["private"]

        artifact = distribution["artifact"]
        artifact_path = artifact_root / artifact["name"]
        if not artifact_path.exists():
            download(artifact["url"], artifact_path)
        verify_artifact(artifact_path, artifact)

        archive_tree = zip_contents(artifact_path)
        assert len(archive_tree) == distribution["contentFileCount"]
        assert (
            content_tree_digest(archive_tree)
            == distribution["contentTreeSha256"]
        )
        plugin_evidence = distribution["pluginEvidence"]
        assert archive_tree[plugin_evidence["path"]] == plugin_evidence["sha256"]
        assert plugin_evidence["sha256"] == plugin_lock["sha256"]
        with zipfile.ZipFile(artifact_path) as archive:
            archive_plugin = archive.read(plugin_evidence["path"]).decode()
        assert (
            plugin_header(archive_plugin, "Version")
            == plugin_evidence["pluginVersion"]
        )
        assert (
            plugin_header(archive_plugin, "Requires at least")
            == plugin_evidence["minimumWordPress"]
        )
        assert (
            plugin_header(archive_plugin, "Requires PHP")
            == plugin_evidence["minimumPhp"]
        )
        for marker in distribution["forwardInventoryMarkers"]:
            assert marker in archive_tree

    print(
        json.dumps(
            {
                "profileId": lock["profileId"],
                "sourceCommit": source["commit"],
                "sourceTree": source["tree"],
                "releaseFileCount": distribution["contentFileCount"],
                "releaseContentTreeSha256": distribution[
                    "contentTreeSha256"
                ],
                "wordpress70Compatibility": "forbidden",
                "outcome": "passed",
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
