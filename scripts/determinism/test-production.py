#!/usr/bin/env python3
"""Prove SDK-042 reproducibility in two unrelated fresh project roots."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "fixtures" / "project-cli" / "project"
COMPARATOR = ROOT / "scripts" / "determinism" / "compare-builds.py"
NODE_IMAGE = (
    "docker.io/library/node@sha256:"
    "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
MANIFEST = Path("build/nextjs/_GeneratedFiles.json")
EFFECTIVE = Path("build/nextjs/.wphx/effective-inputs.json")
REPORT = Path("dist/wordpress-hx-build.json")
ARCHIVE = Path("dist/wordpress-hx.zip")


def canonical(value: object, *, newline: bool = False) -> bytes:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return encoded + (b"\n" if newline else b"")


def digest_without(value: dict[str, object], field: str) -> str:
    material = dict(value)
    material.pop(field, None)
    return hashlib.sha256(canonical(material)).hexdigest()


def make_tools(root: Path) -> None:
    tools = root / "tools"
    tools.mkdir()
    haxe = tools / "haxe"
    haxe.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "if [ \"${1:-}\" = \"--version\" ]; then printf '%s\\n' 4.3.7; exit 0; fi\n"
        "hxml=\n"
        "for argument in \"$@\"; do [ \"$argument\" = .wphx/bootstrap/project.hxml ] && hxml=$argument; done\n"
        "[ -n \"$hxml\" ]\n"
        "grep -Fx -- --no-output \"$hxml\" >/dev/null\n"
    )
    lix = tools / "lix"
    lix.write_text("#!/bin/sh\nset -eu\n[ \"${1:-}\" = --version ]\nprintf '%s\\n' 15.12.2\n")
    npm = tools / "npm"
    npm.write_text("#!/bin/sh\nset -eu\n[ \"${1:-}\" = --version ]\nprintf '%s\\n' 10.9.2\n")
    for command in (haxe, lix, npm):
        command.chmod(0o755)


def invoke(runtime_root: Path, evidence: Path, project: Path) -> None:
    command = [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "--user",
        f"{os.getuid()}:{os.getgid()}",
        "--mount",
        f"type=bind,src={runtime_root.resolve()},dst=/runtime,readonly",
        "--mount",
        f"type=bind,src={evidence.resolve()},dst=/evidence",
        "--env",
        "PATH=/evidence/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "-w",
        "/evidence",
        NODE_IMAGE,
        "node",
        "/runtime/index.js",
        "build",
        "--project",
        "/evidence/" + project.relative_to(evidence).as_posix(),
        "--json",
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise AssertionError(f"fresh build failed ({result.returncode})\n{result.stdout}\n{result.stderr}")
    events = [json.loads(line) for line in result.stdout.splitlines()]
    assert events[-1]["event"] == "command-completed" and events[-1]["status"] == "passed"


def compare(left: Path, right: Path, expected: int) -> dict[str, object]:
    result = subprocess.run(
        [sys.executable, str(COMPARATOR), str(left), str(right)],
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == expected, result.stdout + result.stderr
    document = json.loads(result.stdout)
    assert result.stdout.encode() == canonical(document, newline=True)
    return document


def perturb_input_metadata(project: Path, *, mode: int, timestamp: int) -> None:
    for relative in ("src/acme/site/Site.hx", "assets/brand.txt", ".wphx/bootstrap/project.hxml"):
        path = project / relative
        path.chmod(mode)
        os.utime(path, (timestamp, timestamp))


def validate_archive(project: Path) -> tuple[str, int]:
    report_bytes = (project / REPORT).read_bytes()
    report = json.loads(report_bytes)
    assert report_bytes == canonical(report, newline=True)
    assert report["normalization"]["fileMode"] == 0o644
    assert report["normalization"]["modifiedAt"] == "1980-01-01T00:00:00Z"
    with zipfile.ZipFile(project / ARCHIVE) as archive:
        assert archive.namelist() == ["_wphx/reproducible-build.json", EFFECTIVE.as_posix()]
        for info in archive.infolist():
            assert info.date_time == (1980, 1, 1, 0, 0, 0)
            assert info.compress_type == zipfile.ZIP_STORED
            assert info.extra == b"" and info.comment == b""
            assert (info.external_attr >> 16) & 0xFFFF == stat.S_IFREG | 0o644
        assert archive.read("_wphx/reproducible-build.json") == report_bytes
        assert archive.read(EFFECTIVE.as_posix()) == (project / EFFECTIVE).read_bytes()
        entry_count = len(archive.infolist())
    forbidden = (
        b"/Us" b"ers/",
        b"/ho" b"me/",
        b"/evidence/",
        b"workspace/code",
        b"wordpresshx-sdk042-determinism-",
    )
    manifest = json.loads((project / MANIFEST).read_text())
    for record in manifest["files"]:
        data = project.joinpath(*Path(record["path"]).parts).read_bytes()
        assert not any(marker in data for marker in forbidden)
        assert stat.S_IMODE(project.joinpath(*Path(record["path"]).parts).stat().st_mode) == 0o644
    assert stat.S_IMODE((project / MANIFEST).stat().st_mode) == 0o644
    return hashlib.sha256((project / ARCHIVE).read_bytes()).hexdigest(), entry_count


def make_legacy_single_root_generation(project: Path) -> None:
    manifest_path = project / MANIFEST
    manifest = json.loads(manifest_path.read_text())
    manifest["files"] = [record for record in manifest["files"] if record["path"] == EFFECTIVE.as_posix()]
    manifest["files"][0]["validatorIds"] = ["wphx.effective-inputs"]
    manifest["validators"] = [
        validator for validator in manifest["validators"] if validator["validatorId"] == "wphx.effective-inputs"
    ]
    manifest["outputRoots"] = [root for root in manifest["outputRoots"] if root["path"] != "dist"]
    effective_digest = hashlib.sha256((project / EFFECTIVE).read_bytes()).hexdigest()
    manifest["inputs"]["emissionResultSha256s"] = [effective_digest]
    generation_material = [
        {"contentSha256": record["contentSha256"], "path": record["path"], "sizeBytes": record["sizeBytes"]}
        for record in manifest["files"]
    ]
    manifest["inputs"]["generationSha256"] = hashlib.sha256(canonical(generation_material)).hexdigest()
    manifest["manifestDigest"] = digest_without(manifest, "manifestDigest")
    manifest_path.write_bytes(canonical(manifest, newline=True))
    manifest_path.chmod(0o644)
    (project / REPORT).unlink()
    (project / ARCHIVE).unlink()


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk042-determinism-", dir=temporary_parent) as raw:
        evidence = Path(raw)
        make_tools(evidence)
        left = evidence / "fresh-a" / "project"
        right = evidence / "fresh-b" / "nested" / "project"
        left.parent.mkdir(parents=True)
        right.parent.mkdir(parents=True)
        shutil.copytree(FIXTURE, left)
        shutil.copytree(FIXTURE, right)
        perturb_input_metadata(left, mode=0o600, timestamp=978307200)
        perturb_input_metadata(right, mode=0o644, timestamp=1893456000)
        invoke(runtime_root, evidence, left)
        invoke(runtime_root, evidence, right)

        equality = compare(left, right, 0)
        assert equality["status"] == "equal" and equality["firstDifference"] is None
        assert (left / MANIFEST).read_bytes() == (right / MANIFEST).read_bytes()
        left_archive, entry_count = validate_archive(left)
        right_archive, right_entry_count = validate_archive(right)
        assert left_archive == right_archive and entry_count == right_entry_count

        migration = evidence / "migration-from-sdk043"
        shutil.copytree(right, migration)
        make_legacy_single_root_generation(migration)
        invoke(runtime_root, evidence, migration)
        migration_comparison = compare(right, migration, 0)
        assert migration_comparison["status"] == "equal"

        byte_mutation = evidence / "mutation-bytes"
        shutil.copytree(right, byte_mutation)
        archive = byte_mutation / ARCHIVE
        data = bytearray(archive.read_bytes())
        data[0] ^= 1
        archive.write_bytes(data)
        byte_difference = compare(left, byte_mutation, 2)
        assert byte_difference["status"] == "invalid"
        assert "dist/wordpress-hx.zip" in byte_difference["reason"]

        mode_mutation = evidence / "mutation-mode"
        shutil.copytree(right, mode_mutation)
        (mode_mutation / REPORT).chmod(0o600)
        mode_difference = compare(left, mode_mutation, 1)
        assert mode_difference["firstDifference"] == {
            "scope": "artifact-mode",
            "path": REPORT.as_posix(),
            "left": 0o644,
            "right": 0o600,
        }

        missing_mutation = evidence / "mutation-missing"
        shutil.copytree(right, missing_mutation)
        (missing_mutation / EFFECTIVE).unlink()
        missing_difference = compare(left, missing_mutation, 2)
        assert missing_difference["status"] == "invalid"
        assert EFFECTIVE.as_posix() in missing_difference["reason"]

        return {
            "schema": "wordpress-hx.sdk042-determinism-summary.v1",
            "freshRootCount": 2,
            "ownedArtifactCount": equality["left"]["artifactCount"],
            "archiveEntryCount": entry_count,
            "negativeComparisonCount": 3,
            "additiveRootMigrationCount": 1,
            "fingerprint": equality["left"]["fingerprint"],
            "archiveSha256": left_archive,
            "nodeImage": NODE_IMAGE,
            "outcome": "passed",
        }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-production.py <compiled-runtime-root>")
    print(canonical(run(Path(sys.argv[1])), newline=True).decode(), end="")


if __name__ == "__main__":
    main()
