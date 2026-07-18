#!/usr/bin/env python3
"""Validate immutable SDK container inputs without trusting mutable tags."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = REPOSITORY_ROOT / "docker/images.lock.json"
COMPOSE_PATH = REPOSITORY_ROOT / "docker/wordpress/compose.yml"
WP_SOURCE_LOCK_PATH = REPOSITORY_ROOT / "profiles/wp70-release/source.lock.json"
PHP_MATRIX_PATH = (
    REPOSITORY_ROOT / "compiler/reflaxe.php/scripts/test-php-matrix.sh"
)

EXPECTED_IMAGES = {
    "mariadb": {
        "tag": "docker.io/library/mariadb:11.4.5",
        "digest": "sha256:49117dcc565cf51aa57ac5fca59ab31213402ff0eae6ffc13c46a37b938f7e4b",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
    "mysql": {
        "tag": "docker.io/library/mysql:8.4.10",
        "digest": "sha256:c592c15aaf4a1961e15d82eb31ea5987dda862d1c4b1e93424438c0e91dc1f8d",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
    "node": {
        "tag": "docker.io/library/node:22.17.0-bookworm-slim",
        "digest": "sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
    "php74Floor": {
        "tag": "docker.io/library/php:7.4.33-cli-bullseye",
        "digest": "sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
    "php84Cli": {
        "tag": "docker.io/library/php:8.4.7-cli-bookworm",
        "digest": "sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
    "playwright": {
        "tag": "mcr.microsoft.com/playwright:v1.58.2-noble",
        "digest": "sha256:6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d",
        "platforms": ["linux/amd64", "linux/arm64"],
    },
    "wordpress70Php84": {
        "tag": "docker.io/library/wordpress:7.0.0-php8.4-apache",
        "digest": "sha256:9a37e25aa7cb8b01a7a6c9ff0af7b9c0aca1ff78b489dd3756f90142a58d3161",
        "platforms": ["linux/amd64", "linux/arm64/v8"],
    },
}


class LockError(RuntimeError):
    pass


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise LockError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=reject_duplicate_keys,
        )
    except (OSError, json.JSONDecodeError) as error:
        raise LockError(f"cannot read {path.relative_to(REPOSITORY_ROOT)}: {error}")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise LockError(message)


def validate_closed_lock() -> dict[str, Any]:
    lock = load_json(LOCK_PATH)
    require(lock.get("schemaVersion") == 1, "image lock schemaVersion must be 1")
    images = lock.get("images")
    require(isinstance(images, dict), "image lock must contain an images object")
    require(set(images) == set(EXPECTED_IMAGES), "image lock key set is not closed")

    digest_pattern = re.compile(r"sha256:[0-9a-f]{64}\Z")
    hex_digest_pattern = re.compile(r"[0-9a-f]{64}\Z")
    runtime_tested = {
        "mariadb",
        "mysql",
        "php74Floor",
        "php84Cli",
        "playwright",
        "wordpress70Php84",
    }
    for key, expected in EXPECTED_IMAGES.items():
        entry = images[key]
        require(isinstance(entry, dict), f"{key} must be an object")
        digest = entry.get("indexDigest")
        reference = entry.get("reference")
        require(entry.get("tag") == expected["tag"], f"{key} tag changed")
        require(digest == expected["digest"], f"{key} digest changed")
        require(
            bool(digest_pattern.fullmatch(str(digest))),
            f"{key} digest is invalid",
        )
        expected_reference = f"{expected['tag'].rsplit(':', 1)[0]}@{digest}"
        require(
            reference == expected_reference,
            f"{key} immutable reference does not match its digest",
        )
        require("@sha256:" in str(reference), f"{key} runtime reference is mutable")
        require(
            entry.get("requiredPlatforms") == expected["platforms"],
            f"{key} required platform set changed",
        )
        status = entry.get("evidenceStatus")
        expected_status = (
            "runtime-tested" if key in runtime_tested else "inventoried"
        )
        require(
            status == expected_status,
            f"{key} evidence status must be {expected_status}, found {status}",
        )

    wp_source_lock = load_json(WP_SOURCE_LOCK_PATH)
    source_distribution = wp_source_lock["distribution"]
    wordpress_entry = images["wordpress70Php84"]
    image_distribution = wordpress_entry["distribution"]
    require(
        wordpress_entry.get("expectedWordPressVersion")
        == source_distribution["versionEvidence"]["wordpressVersion"]
        == "7.0",
        "WordPress image version is not the exact wp70 release",
    )
    require(
        image_distribution.get("contentFileCount")
        == source_distribution["contentFileCount"],
        "WordPress image file count differs from the official distribution lock",
    )
    require(
        image_distribution.get("contentTreeSha256")
        == source_distribution["contentTreeSha256"],
        "WordPress image tree differs from the official distribution lock",
    )
    extras = image_distribution.get("allowedImageExtras")
    require(
        isinstance(extras, list)
        and [extra.get("path") for extra in extras]
        == [".htaccess", "wp-config-docker.php"],
        "WordPress image extras must be a closed two-file set",
    )
    for extra in extras:
        require(
            set(extra) == {"path", "sha256"},
            "WordPress image extra records must contain only path and sha256",
        )
        require(
            bool(hex_digest_pattern.fullmatch(str(extra["sha256"]))),
            f"WordPress image extra {extra['path']} has an invalid digest",
        )

    php_matrix = PHP_MATRIX_PATH.read_text(encoding="utf-8")
    for key, variable in (
        ("php74Floor", "php74_image"),
        ("php84Cli", "php84_image"),
    ):
        expected_line = f'{variable}="{images[key]["reference"]}"'
        require(
            expected_line in php_matrix,
            f"{variable} is out of sync with image lock",
        )

    compose_text = COMPOSE_PATH.read_text(encoding="utf-8")
    compose_images = re.findall(r"^\s*image:\s*(\S+)\s*$", compose_text, re.MULTILINE)
    expected_compose_images = {
        images["mysql"]["reference"],
        images["mariadb"]["reference"],
        images["wordpress70Php84"]["reference"],
    }
    require(
        set(compose_images) == expected_compose_images,
        "Compose image set changed",
    )
    require(
        len(compose_images) == 4,
        "Compose must declare two WordPress and two DB services",
    )
    require(
        compose_images.count(images["wordpress70Php84"]["reference"]) == 2,
        "Compose must use the exact WordPress image in both database lanes",
    )
    require(
        all("@sha256:" in reference for reference in compose_images),
        "Compose contains a mutable image reference",
    )
    return lock


def resolve_remote_indexes(lock: dict[str, Any]) -> list[dict[str, Any]]:
    results = []
    for key in sorted(lock["images"]):
        entry = lock["images"][key]
        process = subprocess.run(
            ["docker", "buildx", "imagetools", "inspect", entry["tag"]],
            cwd=REPOSITORY_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        if process.returncode != 0:
            detail = process.stderr.strip() or process.stdout.strip()
            raise LockError(f"cannot resolve {key}: {detail}")
        digest_match = re.search(
            r"^Digest:\s+(sha256:[0-9a-f]{64})\s*$",
            process.stdout,
            re.MULTILINE,
        )
        require(
            digest_match is not None,
            f"registry output for {key} has no index digest",
        )
        resolved_digest = digest_match.group(1)
        require(
            resolved_digest == entry["indexDigest"],
            f"registry digest changed for {key}: {resolved_digest}",
        )
        platforms = set(
            re.findall(
                r"^\s*Platform:\s+(\S+)\s*$",
                process.stdout,
                re.MULTILINE,
            )
        )
        missing = sorted(set(entry["requiredPlatforms"]) - platforms)
        require(
            not missing,
            f"registry index for {key} lacks platforms: {', '.join(missing)}",
        )
        results.append(
            {
                "image": key,
                "indexDigest": resolved_digest,
                "requiredPlatforms": entry["requiredPlatforms"],
                "outcome": "passed",
            }
        )
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--resolve",
        action="store_true",
        help="also resolve mutable discovery tags and compare their current indexes",
    )
    args = parser.parse_args()
    try:
        lock = validate_closed_lock()
        result: dict[str, Any] = {
            "check": "wordpresshx-image-lock-v1",
            "imageCount": len(lock["images"]),
            "offlineValidation": "passed",
        }
        if args.resolve:
            result["registryResolution"] = resolve_remote_indexes(lock)
        else:
            result["registryResolution"] = "not-requested"
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (LockError, OSError) as error:
        print(f"image lock validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
