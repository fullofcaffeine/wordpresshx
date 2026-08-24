#!/usr/bin/env python3
"""Materialize and verify the locked WordPress 7.0 source for PHP-floor tests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[3]
SOURCE_LOCK = ROOT / "profiles" / "wp70-release" / "source.lock.json"
BUILD = ROOT / "compiler" / "wordpress" / "build" / "lifecycle"
CACHE = BUILD / "cache"
DESTINATION = BUILD / "wordpress70-floor"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> None:
    lock = json.loads(SOURCE_LOCK.read_text(encoding="utf-8"))["distribution"]
    artifact = next(item for item in lock["artifacts"] if item["name"] == "wordpress-7.0.zip")
    CACHE.mkdir(parents=True, exist_ok=True)
    archive_path = CACHE / artifact["name"]
    if not archive_path.exists() or archive_path.stat().st_size != artifact["sizeBytes"] or digest(archive_path) != artifact["sha256"]:
        temporary = CACHE / (artifact["name"] + ".partial")
        if temporary.exists():
            temporary.unlink()
        with urllib.request.urlopen(artifact["url"], timeout=120) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        if temporary.stat().st_size != artifact["sizeBytes"] or digest(temporary) != artifact["sha256"]:
            temporary.unlink(missing_ok=True)
            raise SystemExit("downloaded WordPress 7.0 ZIP differs from the source lock")
        temporary.replace(archive_path)

    temporary_root = Path(tempfile.mkdtemp(prefix="wordpress70-floor-", dir=BUILD))
    try:
        extracted = temporary_root / "wordpress"
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                logical = PurePosixPath(info.filename)
                if logical.is_absolute() or ".." in logical.parts or not logical.parts or logical.parts[0] != "wordpress":
                    raise SystemExit(f"unsafe WordPress ZIP entry: {info.filename}")
                if (info.external_attr >> 16) & 0o170000 == 0o120000:
                    raise SystemExit(f"WordPress ZIP contains a symlink: {info.filename}")
            archive.extractall(temporary_root)
        files = sorted(
            (path for path in extracted.rglob("*") if path.is_file()),
            key=lambda path: path.relative_to(extracted).as_posix(),
        )
        if len(files) != lock["contentFileCount"]:
            raise SystemExit("WordPress floor source file count differs")
        digest_input = b"".join(
            f"{digest(path)}  ./{path.relative_to(extracted).as_posix()}\n".encode()
            for path in files
        )
        tree_digest = hashlib.sha256(digest_input).hexdigest()
        if tree_digest != lock["contentTreeSha256"]:
            raise SystemExit("WordPress floor source tree differs")
        version_path = extracted / "wp-includes" / "version.php"
        if digest(version_path) != lock["versionEvidence"]["sha256"]:
            raise SystemExit("WordPress floor version evidence differs")
        if DESTINATION.exists():
            shutil.rmtree(DESTINATION)
        extracted.replace(DESTINATION)
    finally:
        if temporary_root.exists():
            shutil.rmtree(temporary_root)
    print(json.dumps({
        "contentFileCount": lock["contentFileCount"],
        "contentTreeSha256": lock["contentTreeSha256"],
        "path": str(DESTINATION),
        "wordpressVersion": lock["versionEvidence"]["wordpressVersion"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
