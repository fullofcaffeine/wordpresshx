#!/usr/bin/env python3
"""Validate the scoped immutable PHP-floor runtime used by SDK-051."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
LOCK_PATH = ROOT / "compiler" / "wordpress" / "lifecycle-runtime.lock.json"
EXPECTED_TAG = "docker.io/library/wordpress:php7.4-fpm"
EXPECTED_DIGEST = "sha256:0b4b629f3f1389cb4e42570c452188d6f1ebe74d31aee6395bbb010450a0640e"
EXPECTED_SOURCE_SHA = "002699113d01c0e19f0153ac8461c26f1d39394e56849b18baa1f632c1b3aa64"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resolve", action="store_true")
    args = parser.parse_args()
    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    require(lock.get("schemaVersion") == 1, "lifecycle runtime lock schema changed")
    require(set(lock) == {"schemaVersion", "image", "wordpressSource"}, "lifecycle runtime lock is not closed")
    image = lock["image"]
    require(image["tag"] == EXPECTED_TAG, "lifecycle PHP-floor discovery tag changed")
    require(image["indexDigest"] == EXPECTED_DIGEST, "lifecycle PHP-floor digest changed")
    require(
        image["reference"] == f"docker.io/library/wordpress@{EXPECTED_DIGEST}",
        "lifecycle PHP-floor reference is not the reviewed immutable index",
    )
    require(image["requiredPlatforms"] == ["linux/amd64", "linux/arm64/v8"], "lifecycle PHP-floor platforms changed")
    require(image["observedPhpVersion"] == "7.4.33", "lifecycle PHP-floor version changed")
    source = lock["wordpressSource"]
    require(source["path"] == "profiles/wp70-release/source.lock.json", "lifecycle WordPress source owner changed")
    source_path = ROOT / source["path"]
    source_sha = hashlib.sha256(source_path.read_bytes()).hexdigest()
    require(source["sha256"] == source_sha == EXPECTED_SOURCE_SHA, "lifecycle WordPress source lock identity changed")
    source_lock = json.loads(source_path.read_text(encoding="utf-8"))["distribution"]
    require(source["version"] == source_lock["versionEvidence"]["wordpressVersion"] == "7.0", "lifecycle WordPress version changed")
    require(source["contentFileCount"] == source_lock["contentFileCount"], "lifecycle WordPress file count changed")
    require(source["contentTreeSha256"] == source_lock["contentTreeSha256"], "lifecycle WordPress tree changed")
    result: dict[str, object] = {
        "check": "wordpresshx-sdk051-runtime-lock-v1",
        "imageReference": image["reference"],
        "offlineValidation": "passed",
        "wordpressSourceSha256": source_sha,
    }
    if args.resolve:
        process = subprocess.run(
            ["docker", "buildx", "imagetools", "inspect", image["tag"]],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        require(process.returncode == 0, "cannot resolve lifecycle PHP-floor discovery tag")
        match = re.search(r"^Digest:\s+(sha256:[0-9a-f]{64})\s*$", process.stdout, re.MULTILINE)
        require(match is not None and match.group(1) == EXPECTED_DIGEST, "lifecycle PHP-floor registry digest changed")
        platforms = set(re.findall(r"^\s*Platform:\s+(\S+)\s*$", process.stdout, re.MULTILINE))
        require(set(image["requiredPlatforms"]).issubset(platforms), "lifecycle PHP-floor registry platforms changed")
        result["registryResolution"] = "passed"
    else:
        result["registryResolution"] = "not-requested"
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
