#!/usr/bin/env python3
"""Materialize and verify the exact wp70-release source and distribution."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = ROOT / "profiles" / "wp70-release" / "source.lock.json"
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
        "--depth=1",
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


def archive_path(value: str, root: str) -> str | None:
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise AssertionError(f"unsafe archive path: {value}")
    root_name = root.removesuffix("/")
    if path.parts[0] != root_name:
        raise AssertionError(f"archive entry outside {root}: {value}")
    if len(path.parts) == 1:
        return None
    return PurePosixPath(*path.parts[1:]).as_posix()


def tar_contents(path: Path, root: str) -> dict[str, str]:
    contents: dict[str, str] = {}
    with tarfile.open(path, "r:gz") as archive:
        for member in archive.getmembers():
            relative = archive_path(member.name, root)
            if member.isdir() or relative is None:
                continue
            if not member.isfile():
                raise AssertionError(f"unsupported tar entry: {member.name}")
            extracted = archive.extractfile(member)
            assert extracted is not None
            if relative in contents:
                raise AssertionError(f"duplicate tar entry: {relative}")
            contents[relative] = sha256(extracted.read())
    return contents


def zip_contents(path: Path, root: str) -> dict[str, str]:
    contents: dict[str, str] = {}
    with zipfile.ZipFile(path) as archive:
        for member in archive.infolist():
            relative = archive_path(member.filename, root)
            if member.is_dir() or relative is None:
                continue
            if relative in contents:
                raise AssertionError(f"duplicate zip entry: {relative}")
            contents[relative] = sha256(archive.read(member))
    return contents


def content_tree_digest(contents: dict[str, str]) -> str:
    material = "".join(
        f"{contents[path]}  ./{path}\n" for path in sorted(contents)
    ).encode()
    return sha256(material)


def php_scalar(source: str, name: str) -> str:
    match = re.search(rf"\${re.escape(name)}\s*=\s*'([^']+)'\s*;", source)
    if match is None:
        raise AssertionError(f"missing PHP scalar: {name}")
    return match.group(1)


def php_integer(source: str, name: str) -> int:
    match = re.search(rf"\${re.escape(name)}\s*=\s*([0-9]+)\s*;", source)
    if match is None:
        raise AssertionError(f"missing PHP integer: {name}")
    return int(match.group(1))


def php_string_array(source: str, name: str) -> list[str]:
    match = re.search(
        rf"\${re.escape(name)}\s*=\s*array\((.*?)\);",
        source,
        re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"missing PHP string array: {name}")
    return re.findall(r"'([^']+)'", match.group(1))


def verify_artifact(path: Path, artifact: dict[str, object]) -> None:
    assert path.stat().st_size == artifact["sizeBytes"]
    assert sha256(path.read_bytes()) == artifact["sha256"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        help="Reuse or populate an explicit artifact cache directory.",
    )
    args = parser.parse_args()

    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    source = lock["wordpressSource"]
    embedded = lock["embeddedGutenberg"]
    distribution = lock["distribution"]

    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk010-") as temporary:
        temporary_root = Path(temporary)
        artifact_root = args.artifact_dir or temporary_root / "artifacts"
        artifact_root.mkdir(parents=True, exist_ok=True)

        wordpress_repository = temporary_root / "wordpress-source"
        fetch_commit(source["repository"], source["commit"], wordpress_repository)
        assert (
            git_text(wordpress_repository, "rev-parse", "FETCH_HEAD^{tree}")
            == source["tree"]
        )
        assert (
            git_text(
                wordpress_repository,
                "show",
                "-s",
                "--format=%cI",
                "FETCH_HEAD",
            )
            == source["committerDate"]
        )
        assert (
            git_text(
                wordpress_repository,
                "show",
                "-s",
                "--format=%s",
                "FETCH_HEAD",
            )
            == source["subject"]
        )
        tag_line = run(
            "git",
            "ls-remote",
            source["repository"],
            f"refs/tags/{source['tag']}",
        ).decode().strip()
        assert tag_line == f"{source['commit']}\trefs/tags/{source['tag']}"

        package_bytes = run(
            "git",
            "-C",
            str(wordpress_repository),
            "show",
            "FETCH_HEAD:package.json",
        )
        version_bytes = run(
            "git",
            "-C",
            str(wordpress_repository),
            "show",
            "FETCH_HEAD:src/wp-includes/version.php",
        )
        package_lock = source["sourceEvidence"]["package.json"]
        version_lock = source["sourceEvidence"]["src/wp-includes/version.php"]
        assert (
            git_text(wordpress_repository, "rev-parse", "FETCH_HEAD:package.json")
            == package_lock["blob"]
        )
        assert (
            git_text(
                wordpress_repository,
                "rev-parse",
                "FETCH_HEAD:src/wp-includes/version.php",
            )
            == version_lock["blob"]
        )
        assert sha256(package_bytes) == package_lock["sha256"]
        assert sha256(version_bytes) == version_lock["sha256"]
        package = json.loads(package_bytes)
        assert package["version"] == package_lock["version"]
        assert package["gutenberg"]["sha"] == embedded["commit"]
        assert package["engines"]["node"] == package_lock["node"]
        assert package["engines"]["npm"] == package_lock["npm"]
        source_version = version_bytes.decode()
        assert (
            php_scalar(source_version, "wp_version")
            == version_lock["wordpressVersion"]
        )
        assert (
            php_integer(source_version, "wp_db_version")
            == version_lock["databaseRevision"]
        )
        assert (
            php_scalar(source_version, "required_php_version")
            == version_lock["minimumPhp"]
        )
        assert (
            php_scalar(source_version, "required_mysql_version")
            == version_lock["minimumMysql"]
        )
        assert (
            php_string_array(source_version, "required_php_extensions")
            == version_lock["requiredPhpExtensions"]
        )

        gutenberg_repository = temporary_root / "gutenberg-source"
        fetch_commit(embedded["repository"], embedded["commit"], gutenberg_repository)
        assert (
            git_text(gutenberg_repository, "rev-parse", "FETCH_HEAD^{tree}")
            == embedded["tree"]
        )
        assert (
            git_text(
                gutenberg_repository,
                "show",
                "-s",
                "--format=%cI",
                "FETCH_HEAD",
            )
            == embedded["committerDate"]
        )

        artifact_paths: dict[str, Path] = {}
        for artifact in distribution["artifacts"]:
            path = artifact_root / artifact["name"]
            if not path.exists():
                download(artifact["url"], path)
            verify_artifact(path, artifact)
            artifact_paths[artifact["name"]] = path

        tar_tree = tar_contents(
            artifact_paths["wordpress-7.0.tar.gz"], distribution["archiveRoot"]
        )
        zip_tree = zip_contents(
            artifact_paths["wordpress-7.0.zip"], distribution["archiveRoot"]
        )
        assert tar_tree == zip_tree
        assert len(tar_tree) == distribution["contentFileCount"]
        assert content_tree_digest(tar_tree) == distribution["contentTreeSha256"]

        version_path = distribution["versionEvidence"]["path"].removeprefix(
            distribution["archiveRoot"]
        )
        archive_version_digest = tar_tree[version_path]
        version_evidence = distribution["versionEvidence"]
        assert archive_version_digest == version_evidence["sha256"]
        with zipfile.ZipFile(artifact_paths["wordpress-7.0.zip"]) as archive:
            archive_version = archive.read(distribution["versionEvidence"]["path"]).decode()
        assert (
            php_scalar(archive_version, "wp_version")
            == version_evidence["wordpressVersion"]
        )
        assert (
            php_integer(archive_version, "wp_db_version")
            == version_evidence["databaseRevision"]
        )
        assert (
            php_scalar(archive_version, "required_php_version")
            == version_evidence["minimumPhp"]
        )
        assert (
            php_scalar(archive_version, "required_mysql_version")
            == version_evidence["minimumMysql"]
        )
        assert (
            php_string_array(archive_version, "required_php_extensions")
            == version_evidence["requiredPhpExtensions"]
        )

    print(
        json.dumps(
            {
                "profileId": lock["profileId"],
                "sourceCommit": source["commit"],
                "sourceTree": source["tree"],
                "embeddedGutenbergCommit": embedded["commit"],
                "embeddedGutenbergTree": embedded["tree"],
                "distributionFileCount": distribution["contentFileCount"],
                "distributionContentTreeSha256": distribution["contentTreeSha256"],
                "outcome": "passed",
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
