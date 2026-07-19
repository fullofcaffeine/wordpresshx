#!/usr/bin/env python3
"""Build and authenticate a deterministic source-only reflaxe.php archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path


SCHEMA_VERSION = 1
MARKER = "REFLAXE_PHP_PACKAGE_ARTIFACT:PASS"
DEFAULT_SOURCE_DATE_EPOCH = 315532800
PACKAGE_DOCUMENTS = (
    "CHANGELOG.md",
    "EXTRACTION.md",
    "LICENSE.md",
    "README.md",
    "haxelib.json",
    "provenance.json",
)
MACHINE_LOCAL_PATTERNS = (
    re.compile("/" + r"Users/[^/\s]+/"),
    re.compile("/" + r"home/[^/\s]+/"),
    re.compile(r"[A-Za-z]:\\\\Users\\\\[^\\\s]+\\\\"),
)
EXACT_HAXELIB_VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")


class PackageFailure(RuntimeError):
    """A fail-closed package construction error."""


def sha256_bytes(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def run_git(package_root: Path, arguments: list[str]) -> str:
    result = subprocess.run(
        ["git", "-C", str(package_root), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise PackageFailure(f"git {' '.join(arguments)} failed: {detail}")
    return result.stdout.strip()


def repository_state(package_root: Path) -> tuple[str, bool]:
    commit = run_git(package_root, ["rev-parse", "HEAD"])
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise PackageFailure("package source commit is not a full lowercase Git SHA")
    status = run_git(
        package_root,
        ["status", "--porcelain", "--untracked-files=all", "--", "."],
    )
    return commit, bool(status)


def package_files(package_root: Path) -> list[Path]:
    selected = [package_root / relative for relative in PACKAGE_DOCUMENTS]
    source_root = package_root / "src"
    if not source_root.is_dir():
        raise PackageFailure("package source directory is missing")
    selected.extend(sorted(source_root.rglob("*.hx")))
    if not selected:
        raise PackageFailure("package archive has no source files")

    normalized: list[Path] = []
    seen: set[str] = set()
    for path in selected:
        relative = path.relative_to(package_root).as_posix()
        if relative in seen:
            raise PackageFailure(f"duplicate package input: {relative}")
        seen.add(relative)
        if path.is_symlink() or not path.is_file():
            raise PackageFailure(f"package input must be a regular file: {relative}")
        normalized.append(path)
    return sorted(normalized, key=lambda path: path.relative_to(package_root).as_posix())


def validate_metadata(package_root: Path) -> dict[str, object]:
    metadata_path = package_root / "haxelib.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PackageFailure(f"invalid haxelib.json: {error}") from error
    if metadata.get("name") != "reflaxe.php" or metadata.get("version") != "0.0.0":
        raise PackageFailure("private package identity must remain reflaxe.php 0.0.0")
    dependencies = metadata.get("dependencies")
    if not isinstance(dependencies, dict):
        raise PackageFailure("haxelib dependencies must be an object")
    for name, version in dependencies.items():
        if not isinstance(name, str) or not isinstance(version, str):
            raise PackageFailure("haxelib dependency identities must be strings")
        if not EXACT_HAXELIB_VERSION.fullmatch(version):
            raise PackageFailure(
                f"release dependency {name} must use an exact version, received {version}"
            )
    return metadata


def validate_portable_inputs(package_root: Path, files: list[Path]) -> None:
    for path in files:
        contents = path.read_text(encoding="utf-8")
        relative = path.relative_to(package_root).as_posix()
        for pattern in MACHINE_LOCAL_PATTERNS:
            if pattern.search(contents):
                raise PackageFailure(f"machine-local path found in package input: {relative}")
        if path.suffix == ".hxml" or path.name == "haxelib.json":
            lowered = contents.lower()
            forbidden = ("haxelib dev", "../", "..\\", "path:", "file:")
            for token in forbidden:
                if token in lowered:
                    raise PackageFailure(
                        f"floating filesystem token {token!r} found in release input {relative}"
                    )


def source_manifest(package_root: Path, files: list[Path], metadata: dict[str, object]) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    digest_lines: list[str] = []
    for path in files:
        relative = path.relative_to(package_root).as_posix()
        contents = path.read_bytes()
        digest = sha256_bytes(contents)
        entries.append({"path": relative, "sha256": digest, "bytes": len(contents)})
        digest_lines.append(f"{digest}  {relative}\n")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "package": {"name": metadata["name"], "version": metadata["version"]},
        "sourceOnly": True,
        "publicationAuthorized": False,
        "contentSha256": sha256_bytes("".join(digest_lines).encode("utf-8")),
        "files": entries,
    }


def zip_entry(relative: str, contents: bytes) -> tuple[zipfile.ZipInfo, bytes]:
    info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_STORED
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    return info, contents


def write_archive(
    archive_path: Path,
    package_root: Path,
    files: list[Path],
    manifest: dict[str, object],
) -> None:
    temporary = archive_path.with_suffix(archive_path.suffix + ".tmp")
    temporary.unlink(missing_ok=True)
    with zipfile.ZipFile(temporary, "w", allowZip64=True) as archive:
        for path in files:
            relative = path.relative_to(package_root).as_posix()
            info, contents = zip_entry(relative, path.read_bytes())
            archive.writestr(info, contents)
        info, contents = zip_entry("package-source.json", canonical_json(manifest))
        archive.writestr(info, contents)
    os.replace(temporary, archive_path)


def validate_archive(
    archive_path: Path,
    files: list[Path],
    package_root: Path,
    source: dict[str, object],
) -> None:
    expected = [path.relative_to(package_root).as_posix() for path in files]
    expected.append("package-source.json")
    with zipfile.ZipFile(archive_path, "r") as archive:
        names = archive.namelist()
        if names != expected or len(names) != len(set(names)):
            raise PackageFailure("archive inventory is not canonical")
        if archive.testzip() is not None:
            raise PackageFailure("archive integrity validation failed")
        for name in names:
            parts = Path(name).parts
            if name.startswith("/") or ".." in parts or "\\" in name:
                raise PackageFailure(f"unsafe archive path: {name}")
        embedded = json.loads(archive.read("package-source.json"))
        if embedded != source:
            raise PackageFailure("embedded source identity does not match the package inputs")


def build(out_dir: Path, require_clean: bool) -> Path:
    package_root = Path(__file__).resolve().parent.parent
    metadata = validate_metadata(package_root)
    files = package_files(package_root)
    validate_portable_inputs(package_root, files)
    commit, dirty = repository_state(package_root)
    if require_clean and dirty:
        raise PackageFailure("release-shaped package construction requires a clean package worktree")

    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", DEFAULT_SOURCE_DATE_EPOCH))
    if epoch != DEFAULT_SOURCE_DATE_EPOCH:
        raise PackageFailure(
            f"SOURCE_DATE_EPOCH must use the canonical ZIP epoch {DEFAULT_SOURCE_DATE_EPOCH}"
        )
    out_dir.mkdir(parents=True, exist_ok=True)
    archive_name = f"{metadata['name']}-{metadata['version']}.zip"
    archive_path = out_dir / archive_name
    source = source_manifest(package_root, files, metadata)
    write_archive(archive_path, package_root, files, source)
    validate_archive(archive_path, files, package_root, source)

    archive_contents = archive_path.read_bytes()
    artifact = {
        "schemaVersion": SCHEMA_VERSION,
        "marker": MARKER,
        "implementationCommit": commit,
        "workingTreeDirty": dirty,
        "sourceDateEpoch": epoch,
        "package": {
            "name": metadata["name"],
            "version": metadata["version"],
            "archiveFile": archive_name,
            "archiveSha256": sha256_bytes(archive_contents),
            "archiveBytes": len(archive_contents),
            "archiveFileCount": len(files) + 1,
            "sourceContentSha256": source["contentSha256"],
            "sourceFileCount": len(files),
            "sourceOnly": True,
            "reproducible": True,
            "publicationAuthorized": False,
        },
    }
    (out_dir / "artifact-manifest.json").write_bytes(canonical_json(artifact))
    print(f"reflaxe.php package archive sha256={artifact['package']['archiveSha256']}")
    print(MARKER)
    return archive_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--require-clean", action="store_true")
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    try:
        build(arguments.out.resolve(), arguments.require_clean)
    except (OSError, ValueError, PackageFailure, zipfile.BadZipFile) as error:
        print(f"reflaxe.php package build failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
