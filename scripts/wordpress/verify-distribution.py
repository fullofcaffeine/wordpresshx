#!/usr/bin/env python3
"""Verify that the locked WordPress image contains the exact 7.0 distribution."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
IMAGE_LOCK_PATH = REPOSITORY_ROOT / "docker/images.lock.json"
SOURCE_LOCK_PATH = REPOSITORY_ROOT / "profiles/wp70-release/source.lock.json"


class VerificationError(RuntimeError):
    pass


def run_container(image: str, command: list[str]) -> str:
    process = subprocess.run(
        ["docker", "run", "--rm", "--network", "none", image, *command],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0:
        detail = process.stderr.strip() or process.stdout.strip()
        raise VerificationError(f"container command failed: {detail}")
    return process.stdout


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    try:
        image_lock = load_json(IMAGE_LOCK_PATH)
        source_lock = load_json(SOURCE_LOCK_PATH)
        image_entry = image_lock["images"]["wordpress70Php84"]
        image = image_entry["reference"]

        version_code = (
            "require '/usr/src/wordpress/wp-includes/version.php';"
            "echo json_encode(array('phpVersion' => PHP_VERSION,"
            "'wordpressVersion' => $wp_version), JSON_UNESCAPED_SLASHES);"
        )
        versions = json.loads(run_container(image, ["php", "-r", version_code]))
        require(
            versions["wordpressVersion"] == image_entry["expectedWordPressVersion"],
            "WordPress version in image differs from lock",
        )
        require(
            versions["phpVersion"] == image_entry["observedPhpVersion"],
            "PHP version in WordPress image differs from lock",
        )

        checksum_output = run_container(
            image,
            [
                "sh",
                "-eu",
                "-c",
                "cd /usr/src/wordpress && "
                "find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum",
            ],
        )
        checksum_line = re.compile(r"([0-9a-f]{64})  (\./.+)\Z")
        entries: dict[str, str] = {}
        for line in checksum_output.splitlines():
            match = checksum_line.fullmatch(line)
            require(match is not None, f"unexpected checksum line: {line}")
            digest, relative_path = match.groups()
            require(relative_path not in entries, f"duplicate image path: {relative_path}")
            entries[relative_path] = digest

        expected_extra_records = image_entry["distribution"]["allowedImageExtras"]
        expected_extras = {
            extra["path"]: extra["sha256"] for extra in expected_extra_records
        }
        for path, expected_digest in expected_extras.items():
            image_path = f"./{path}"
            actual_digest = entries.pop(image_path, None)
            require(actual_digest is not None, f"missing allowed image extra: {path}")
            require(actual_digest == expected_digest, f"image extra changed: {path}")

        distribution = source_lock["distribution"]
        require(
            len(entries) == distribution["contentFileCount"],
            "official distribution file count differs inside WordPress image",
        )
        digest_input = "".join(
            f"{entries[path]}  {path}\n" for path in sorted(entries)
        ).encode("utf-8")
        tree_digest = hashlib.sha256(digest_input).hexdigest()
        require(
            tree_digest == distribution["contentTreeSha256"],
            "official WordPress distribution tree differs inside image",
        )

        result = {
            "check": "wordpresshx-wordpress-image-distribution-v1",
            "containerNetwork": "none",
            "imageReference": image,
            "imageExtraCount": len(expected_extras),
            "imageExtras": expected_extra_records,
            "officialDistributionFileCount": len(entries),
            "officialDistributionTreeSha256": tree_digest,
            "outcome": "passed",
            "phpVersion": versions["phpVersion"],
            "wordpressVersion": versions["wordpressVersion"],
        }
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (KeyError, OSError, json.JSONDecodeError, VerificationError) as error:
        print(f"WordPress image verification failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
