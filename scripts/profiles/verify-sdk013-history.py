#!/usr/bin/env python3
"""Authenticate the historical SDK-013 receipt against its exact Git commit."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RECEIPT_PATH = ROOT / "manifests/evidence/sdk-013-profile-generator.json"
SHA1 = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")


def git(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        check=check,
        capture_output=True,
    )


def receipt_records(receipt: dict[str, object]) -> list[tuple[str, str]]:
    subject = receipt["subject"]
    assert isinstance(subject, dict)
    records: list[tuple[str, str]] = []
    for path_field, digest_field in (
        ("generatorPath", "generatorSha256"),
        ("checkerPath", "checkerSha256"),
        ("testPath", "testSha256"),
        ("selectionPath", "selectionSha256"),
        ("profileSchemaPath", "profileSchemaSha256"),
    ):
        path_text = subject[path_field]
        digest = subject[digest_field]
        assert isinstance(path_text, str)
        assert isinstance(digest, str) and SHA256.fullmatch(digest)
        records.append((path_text, digest))

    profiles = receipt["profiles"]
    assert isinstance(profiles, list)
    for profile in profiles:
        assert isinstance(profile, dict)
        for section_name in ("catalog", "omissions", "generationReport"):
            section = profile[section_name]
            assert isinstance(section, dict)
            path_text = section["path"]
            digest = section["fileSha256"]
            assert isinstance(path_text, str)
            assert isinstance(digest, str) and SHA256.fullmatch(digest)
            records.append((path_text, digest))

    records.sort()
    assert len(records) == 11
    assert len(records) == len({path for path, _digest in records})
    for path_text, _digest in records:
        path = Path(path_text)
        assert not path.is_absolute()
        assert ".." not in path.parts
        assert path.as_posix() == path_text
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-history",
        action="store_true",
        help="fail unless the exact historical commit is locally available",
    )
    arguments = parser.parse_args()

    receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))
    assert receipt["schemaVersion"] == 1
    assert receipt["receiptId"] == "SDK-013-PROFILE-GENERATOR"
    historical = receipt["historicalVerification"]
    assert isinstance(historical, dict)
    assert historical == {
        "algorithm": "sha256-lines-of-sha256-two-spaces-path-lf-v1",
        "subjectCommit": "4d633f2195542a655180e77c94c9f4e4b2fbb7e3",
        "subjectContentSha256": (
            "6381aa45691307fede7c986c133c5fb75491ad95e3101afbc6be81dfceb51c1f"
        ),
        "depthOneFallback": "self-contained-subject-digest-inventory",
        "relation": (
            "The original SDK-013 receipt remains authority only for its exact "
            "historical generator, selection, and catalog bytes."
        ),
    }
    subject_commit = historical["subjectCommit"]
    assert isinstance(subject_commit, str) and SHA1.fullmatch(subject_commit)

    records = receipt_records(receipt)
    material = bytearray()
    for path_text, digest in records:
        material.extend(f"{digest}  {path_text}\n".encode())
    assert hashlib.sha256(material).hexdigest() == historical[
        "subjectContentSha256"
    ]

    history_available = (
        git("cat-file", "-e", f"{subject_commit}^{{commit}}", check=False).returncode
        == 0
    )
    if not history_available:
        if arguments.require_history:
            raise AssertionError(
                f"required historical SDK-013 commit is unavailable: {subject_commit}"
            )
        shallow = git("rev-parse", "--is-shallow-repository").stdout.decode().strip()
        assert shallow == "true"
        print("SDK-013 historical receipt inventory passed; Git history unavailable")
        return 0

    head_commit = git("rev-parse", "HEAD").stdout.decode().strip()
    assert SHA1.fullmatch(head_commit)
    assert (
        git(
            "merge-base",
            "--is-ancestor",
            subject_commit,
            head_commit,
            check=False,
        ).returncode
        == 0
    )
    for path_text, expected_digest in records:
        content = git("show", f"{subject_commit}:{path_text}").stdout
        assert hashlib.sha256(content).hexdigest() == expected_digest

    print(f"SDK-013 historical receipt passed: {len(records)} exact files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
