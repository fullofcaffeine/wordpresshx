#!/usr/bin/env python3
"""Exercise the production Haxe/Genes wphx foundation on exact Node."""

from __future__ import annotations

import copy
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
PROJECT_FIXTURE = ROOT / "fixtures" / "project-cli" / "project"
EXPECTED_INPUTS = ROOT / "fixtures" / "project-cli" / "valid" / "effective-inputs.json"
EVENT_SCHEMA = json.loads((ROOT / "schemas" / "cli-event.schema.json").read_text())
NODE_IMAGE = (
    "docker.io/library/node@sha256:"
    "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
MANIFEST = Path("build/nextjs/_GeneratedFiles.json")
EFFECTIVE = Path("build/nextjs/.wphx/effective-inputs.json")
REPRODUCIBILITY = Path("dist/wordpress-hx-build.json")
ARCHIVE = Path("dist/wordpress-hx.zip")
TRANSACTION = Path("build/nextjs/.wphx-transactions")
UNOWNED = Path("build/nextjs/README.txt")


def canonical(value: object, *, newline: bool = False) -> bytes:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode()
    return encoded + (b"\n" if newline else b"")


def digest(value: object, field: str) -> str:
    material = copy.deepcopy(value)
    material.pop(field, None)
    return hashlib.sha256(canonical(material)).hexdigest()


def snapshot(root: Path) -> dict[str, tuple[str, bytes | str]]:
    result: dict[str, tuple[str, bytes | str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        metadata = path.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            result[relative] = ("symlink", os.readlink(path))
        elif stat.S_ISREG(metadata.st_mode):
            result[relative] = ("file", path.read_bytes())
        elif stat.S_ISDIR(metadata.st_mode):
            result[relative] = ("directory", "")
        else:
            result[relative] = ("special", "")
    return result


def write_json(path: Path, value: object, *, pretty: bool = False) -> None:
    if pretty:
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    else:
        path.write_bytes(canonical(value, newline=True))


def refresh_lock(project: Path) -> dict[str, object]:
    config = json.loads((project / "wordpress-hx.json").read_text())
    lock_path = project / ".wphx/project.lock.json"
    lock = json.loads(lock_path.read_text())
    lock["project"]["configSemanticSha256"] = hashlib.sha256(canonical(config)).hexdigest()
    for field in ("manifest", "lockfile"):
        record = lock["packageGraph"][field]
        record["sha256"] = hashlib.sha256((project / record["path"]).read_bytes()).hexdigest()
    for component in lock["components"]:
        component["lockEntrySha256"] = digest(component, "lockEntrySha256")
    lock["lockDigest"] = digest(lock, "lockDigest")
    write_json(lock_path, lock)
    return lock


def assert_canonical_jsonl(data: str) -> list[dict[str, object]]:
    assert data.endswith("\n"), "machine output lacks its final LF"
    documents: list[dict[str, object]] = []
    for raw in data.splitlines(keepends=True):
        value = json.loads(raw)
        assert raw.encode() == canonical(value, newline=True), f"non-canonical JSONL: {raw!r}"
        assert isinstance(value, dict)
        documents.append(value)
    return documents


def validate_events(documents: list[dict[str, object]], command: str) -> None:
    events = [value for value in documents if value.get("schema") == "wordpress-hx.cli-event.v1"]
    assert events, f"{command} emitted no CLI events"
    assert [event["sequence"] for event in events] == list(range(1, len(events) + 1))
    run_ids = {event["runId"] for event in events}
    assert len(run_ids) == 1
    for event in events:
        assert set(event) == {
            "schema",
            "runId",
            "sequence",
            "elapsedMs",
            "command",
            "event",
            "stage",
            "status",
            "payload",
        }
        assert event["command"] == command
        assert isinstance(event["elapsedMs"], int) and event["elapsedMs"] >= 0
        assert event["command"] in EVENT_SCHEMA["properties"]["command"]["enum"]
        assert event["event"] in EVENT_SCHEMA["properties"]["event"]["enum"]
        assert event["stage"] in EVENT_SCHEMA["properties"]["stage"]["enum"]
        assert event["status"] in EVENT_SCHEMA["properties"]["status"]["enum"]
        payload = event["payload"]
        assert isinstance(payload, dict)
        allowed_payload = set(EVENT_SCHEMA["$defs"]["payload"]["properties"])
        assert set(payload) <= allowed_payload
        diagnostic = payload.get("diagnostic")
        if diagnostic is not None:
            assert set(diagnostic) <= set(EVENT_SCHEMA["$defs"]["diagnostic"]["properties"])
            assert diagnostic["code"].startswith("WPHX") and len(diagnostic["code"]) == 8
            source = diagnostic["source"]
            assert not source["path"].startswith("/")
            assert ".." not in source["path"].split("/")
            assert diagnostic["remediations"]
    assert events[0]["event"] == "command-started"
    assert events[-1]["event"] == "command-completed"


class Runtime:
    def __init__(self, runtime_root: Path, evidence_root: Path) -> None:
        self.runtime_root = runtime_root.resolve()
        self.evidence_root = evidence_root.resolve()
        self.positive = 0
        self.negative = 0
        self.no_write = 0

    def container(self, path: Path) -> str:
        return "/evidence/" + path.resolve().relative_to(self.evidence_root).as_posix()

    def invoke(
        self,
        arguments: list[str],
        *,
        expected: int = 0,
        environment: dict[str, str] | None = None,
        workdir: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "--mount",
            f"type=bind,src={self.runtime_root},dst=/runtime,readonly",
            "--mount",
            f"type=bind,src={self.evidence_root},dst=/evidence",
            "--env",
            "PATH=/evidence/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "-w",
            self.container(workdir or self.evidence_root),
        ]
        for name, value in sorted((environment or {}).items()):
            command.extend(["--env", f"{name}={value}"])
        command.extend([NODE_IMAGE, "node", "/runtime/index.js", *arguments])
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        if result.returncode != expected:
            raise AssertionError(
                f"{' '.join(arguments)} exited {result.returncode}, expected {expected}\n"
                f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            )
        combined = result.stdout + result.stderr
        for forbidden in (
            str(self.evidence_root),
            "/evidence/",
            "correct horse battery staple",
        ):
            assert forbidden not in combined, f"command output exposed {forbidden!r}"
        if expected == 0:
            self.positive += 1
        else:
            self.negative += 1
        return result

    def invoke_project(
        self,
        project: Path,
        command: str,
        *arguments: str,
        expected: int = 0,
        environment: dict[str, str] | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], list[dict[str, object]]]:
        result = self.invoke(
            [command, *arguments, "--project", self.container(project), "--json"],
            expected=expected,
            environment=environment,
        )
        documents = assert_canonical_jsonl(result.stdout)
        validate_events(documents, command)
        return result, documents


def make_tools(root: Path) -> None:
    tools = root / "tools"
    tools.mkdir()
    haxe = tools / "haxe"
    haxe.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "if [ \"${1:-}\" = \"--version\" ]; then printf '%s\\n' 4.3.7; exit 0; fi\n"
        "if [ \"$#\" -ne 1 ] || [ \"$1\" != .wphx/bootstrap/project.hxml ]; then exit 64; fi\n"
        "if grep -q BROKEN_HAXE src/acme/site/Site.hx; then\n"
        "  printf '%s\\n' 'src/acme/site/Site.hx:1: characters 1-6 : synthetic typing failure' >&2\n"
        "  exit 1\n"
        "fi\n"
        "grep -Fx -- --no-output \"$1\" >/dev/null\n"
    )
    lix = tools / "lix"
    lix.write_text("#!/bin/sh\nset -eu\n[ \"${1:-}\" = --version ]\nprintf '%s\\n' 15.12.2\n")
    haxe.chmod(0o755)
    lix.chmod(0o755)


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk043-production-", dir=temporary_parent) as raw:
        evidence = Path(raw)
        make_tools(evidence)
        runtime = Runtime(runtime_root, evidence)

        help_result = runtime.invoke(["--help"])
        assert "wphx build" not in help_result.stdout or "build" in help_result.stdout
        assert runtime.invoke(["--version"]).stdout == "0.0.0\n"

        project = evidence / "project"
        shutil.copytree(PROJECT_FIXTURE, project)
        expected_inputs = json.loads(EXPECTED_INPUTS.read_text())

        _, inputs_documents = runtime.invoke_project(project, "inspect", "inputs")
        inputs = next(value for value in inputs_documents if value.get("schema") == "wordpress-hx.effective-inputs.v1")
        assert inputs == expected_inputs
        nested = project / "src/acme/site"
        discovered = runtime.invoke(["inspect", "--json"], workdir=nested)
        discovered_documents = assert_canonical_jsonl(discovered.stdout)
        validate_events(discovered_documents, "inspect")

        secret_result, secret_documents = runtime.invoke_project(
            project,
            "inspect",
            "inputs",
            environment={"WP_DB_PASSWORD": "correct horse battery staple"},
        )
        secret_inputs = next(value for value in secret_documents if value.get("schema") == "wordpress-hx.effective-inputs.v1")
        assert secret_inputs == inputs
        assert "WP_DB_PASSWORD" in secret_result.stdout
        assert "correct horse battery staple" not in secret_result.stdout
        _, locale_documents = runtime.invoke_project(project, "inspect", "inputs", environment={"SITE_LOCALE": "fr_FR"})
        locale_inputs = next(value for value in locale_documents if value.get("schema") == "wordpress-hx.effective-inputs.v1")
        assert locale_inputs["fingerprint"] != inputs["fingerprint"]
        assert locale_inputs["compileServer"]["compatibilityDigest"] != inputs["compileServer"]["compatibilityDigest"]

        before = snapshot(project)
        _, doctor_documents = runtime.invoke_project(project, "doctor")
        doctor = next(value for value in doctor_documents if value.get("schema") == "wordpress-hx.doctor.v1")
        assert doctor["status"] == "passed"
        assert snapshot(project) == before
        runtime.no_write += 1

        _, check_documents = runtime.invoke_project(project, "check")
        assert any(value.get("stage") == "ownership-publish" and value.get("status") == "skipped" for value in check_documents)
        assert snapshot(project) == before
        runtime.no_write += 1

        _, dry_documents = runtime.invoke_project(project, "build", "--dry-run")
        assert any(value.get("event") == "dry-run-planned" for value in dry_documents)
        assert snapshot(project) == before
        runtime.no_write += 1

        unowned = project / UNOWNED
        unowned.parent.mkdir(parents=True)
        unowned.write_bytes(b"hand-owned fixture\n")
        _, build_documents = runtime.invoke_project(project, "build")
        assert any(value.get("event") == "build-published" for value in build_documents)
        assert (project / EFFECTIVE).read_bytes() == EXPECTED_INPUTS.read_bytes()
        manifest = json.loads((project / MANIFEST).read_text())
        assert manifest["schema"] == "wordpress-hx.generated-files.v1"
        assert manifest["manifestDigest"] == digest(manifest, "manifestDigest")
        assert [item["path"] for item in manifest["files"]] == sorted(
            [EFFECTIVE.as_posix(), REPRODUCIBILITY.as_posix(), ARCHIVE.as_posix()]
        )
        report_bytes = (project / REPRODUCIBILITY).read_bytes()
        report = json.loads(report_bytes)
        assert report_bytes == canonical(report, newline=True)
        assert report["schema"] == "wordpress-hx.reproducible-build.v1"
        assert report["fingerprint"] == inputs["fingerprint"]
        assert report["normalization"] == {
            "archiveComment": False,
            "archiveFormat": "zip32-stored-v1",
            "compression": "stored",
            "directoryMode": 0o755,
            "entryOrder": "portable-ascii-path-ascending",
            "extraFields": False,
            "fileMode": 0o644,
            "modifiedAt": "1980-01-01T00:00:00Z",
        }
        assert report["entries"] == [
            {
                "path": EFFECTIVE.as_posix(),
                "sha256": hashlib.sha256(EXPECTED_INPUTS.read_bytes()).hexdigest(),
                "sizeBytes": len(EXPECTED_INPUTS.read_bytes()),
                "mode": 0o644,
            }
        ]
        with zipfile.ZipFile(project / ARCHIVE) as archive:
            assert archive.namelist() == [
                "_wphx/reproducible-build.json",
                EFFECTIVE.as_posix(),
            ]
            assert archive.comment == b""
            for info in archive.infolist():
                assert info.compress_type == zipfile.ZIP_STORED
                assert info.date_time == (1980, 1, 1, 0, 0, 0)
                assert info.extra == b""
                assert info.comment == b""
                assert info.create_system == 3
                assert (info.external_attr >> 16) & 0xFFFF == stat.S_IFREG | 0o644
            assert archive.read("_wphx/reproducible-build.json") == report_bytes
            assert archive.read(EFFECTIVE.as_posix()) == EXPECTED_INPUTS.read_bytes()
        for generated in (project / MANIFEST, project / EFFECTIVE, project / REPRODUCIBILITY, project / ARCHIVE):
            assert stat.S_IMODE(generated.stat().st_mode) == 0o644
        assert unowned.read_bytes() == b"hand-owned fixture\n"

        published = snapshot(project)
        _, replay_documents = runtime.invoke_project(project, "build")
        assert snapshot(project) == published
        assert any(
            value.get("payload", {}).get("reason") == "no-op"
            for value in replay_documents
            if value.get("stage") == "ownership-publish"
        )
        _, build_inspection = runtime.invoke_project(project, "inspect", "build")
        assert any(value.get("schema") == "wordpress-hx.inspect-build.v1" for value in build_inspection)
        _, provenance = runtime.invoke_project(project, "inspect", "provenance", EFFECTIVE.as_posix())
        proof = next(value for value in provenance if value.get("schema") == "wordpress-hx.inspect-provenance.v1")
        assert proof["artifact"]["contentSha256"] == hashlib.sha256(EXPECTED_INPUTS.read_bytes()).hexdigest()

        tampered = project / EFFECTIVE
        original_effective = tampered.read_bytes()
        tampered.write_bytes(original_effective + b" ")
        tampered_snapshot = snapshot(project)
        _, tamper_documents = runtime.invoke_project(project, "check", expected=7)
        assert any(value.get("event") == "diagnostic" for value in tamper_documents)
        assert snapshot(project) == tampered_snapshot
        runtime.no_write += 1
        tampered.write_bytes(original_effective)

        runtime.invoke_project(project, "clean")
        assert not (project / EFFECTIVE).exists()
        assert not (project / REPRODUCIBILITY).exists()
        assert not (project / ARCHIVE).exists()
        assert unowned.read_bytes() == b"hand-owned fixture\n"
        clean_manifest = json.loads((project / MANIFEST).read_text())
        assert clean_manifest["files"] == []
        assert clean_manifest["manifestDigest"] == digest(clean_manifest, "manifestDigest")
        clean_snapshot = snapshot(project)
        runtime.invoke_project(project, "clean")
        assert snapshot(project) == clean_snapshot

        broken_haxe = evidence / "broken-haxe"
        shutil.copytree(PROJECT_FIXTURE, broken_haxe)
        source = broken_haxe / "src/acme/site/Site.hx"
        source.write_text("// BROKEN_HAXE\n" + source.read_text())
        broken_snapshot = snapshot(broken_haxe)
        _, broken_documents = runtime.invoke_project(broken_haxe, "check", expected=6)
        assert any(value.get("event") == "diagnostic" for value in broken_documents)
        assert snapshot(broken_haxe) == broken_snapshot
        runtime.no_write += 1

        dev_snapshot = snapshot(broken_haxe)
        _, dev_documents = runtime.invoke_project(broken_haxe, "dev", "--services=none", expected=7)
        assert any(
            value.get("event") == "diagnostic" and value.get("payload", {}).get("diagnostic", {}).get("code") == "WPHX4000"
            for value in dev_documents
        )
        assert snapshot(broken_haxe) == dev_snapshot
        runtime.no_write += 1

        def negative(name: str, mutate, expected: int = 3) -> None:
            candidate = evidence / ("negative-" + name)
            shutil.copytree(PROJECT_FIXTURE, candidate)
            mutate(candidate)
            before_negative = snapshot(candidate)
            _, documents = runtime.invoke_project(candidate, "check", expected=expected)
            assert any(value.get("event") == "diagnostic" for value in documents)
            assert snapshot(candidate) == before_negative
            runtime.no_write += 1

        def duplicate_key(candidate: Path) -> None:
            path = candidate / "wordpress-hx.json"
            source = path.read_text()
            path.write_text(source.replace('{\n  "schema":', '{\n  "schema": "wordpress-hx.project.v1",\n  "schema":', 1))

        negative("duplicate-key", duplicate_key)

        def unknown_field(candidate: Path) -> None:
            config = json.loads((candidate / "wordpress-hx.json").read_text())
            config["commands"] = {}
            write_json(candidate / "wordpress-hx.json", config, pretty=True)

        negative("unknown-field", unknown_field)

        def traversal(candidate: Path) -> None:
            config = json.loads((candidate / "wordpress-hx.json").read_text())
            config["paths"]["outputRoots"][0]["path"] = "../outside"
            write_json(candidate / "wordpress-hx.json", config, pretty=True)

        negative("traversal", traversal)

        def overlap(candidate: Path) -> None:
            config = json.loads((candidate / "wordpress-hx.json").read_text())
            config["paths"]["outputRoots"][0]["path"] = "src/generated"
            write_json(candidate / "wordpress-hx.json", config, pretty=True)

        negative("root-overlap", overlap)

        profile_candidate = evidence / "negative-profile-override"
        shutil.copytree(PROJECT_FIXTURE, profile_candidate)
        profile_before = snapshot(profile_candidate)
        runtime.invoke_project(profile_candidate, "check", "--profile", "wp69-release", expected=4)
        assert snapshot(profile_candidate) == profile_before
        runtime.no_write += 1

        def noncanonical_lock(candidate: Path) -> None:
            path = candidate / ".wphx/project.lock.json"
            path.write_bytes(path.read_bytes() + b" ")

        negative("noncanonical-lock", noncanonical_lock)

        def lock_tamper(candidate: Path) -> None:
            lock_path = candidate / ".wphx/project.lock.json"
            lock = json.loads(lock_path.read_text())
            lock["lockDigest"] = "f" * 64
            write_json(lock_path, lock)

        negative("lock-digest", lock_tamper)

        def package_tamper(candidate: Path) -> None:
            path = candidate / "npm-lock.json"
            path.write_bytes(path.read_bytes() + b" ")

        negative("package-digest", package_tamper)

        def local_identity(candidate: Path) -> None:
            lock_path = candidate / ".wphx/project.lock.json"
            lock = json.loads(lock_path.read_text())
            lock["components"][0]["identity"] = "file:../genes"
            write_json(lock_path, lock)
            refresh_lock(candidate)

        negative("local-identity", local_identity)

        def source_link(candidate: Path) -> None:
            os.symlink("Site.hx", candidate / "src/acme/site/Alias.hx")

        negative("source-symlink", source_link)

        def special_asset(candidate: Path) -> None:
            os.mkfifo(candidate / "assets/special.pipe")

        negative("special-asset", special_asset)

        orphan = evidence / "negative-orphan-lock"
        shutil.copytree(PROJECT_FIXTURE, orphan)
        lock_path = orphan / TRANSACTION / "lock"
        lock_path.parent.mkdir(parents=True)
        lock_path.write_bytes(b"orphan\n")
        orphan_before = snapshot(orphan)
        runtime.invoke_project(orphan, "doctor", expected=7)
        assert snapshot(orphan) == orphan_before
        runtime.no_write += 1

        usage = runtime.invoke(["unknown", "--json"], expected=2)
        diagnostic = assert_canonical_jsonl(usage.stderr)
        assert diagnostic[0]["schema"] == "wordpress-hx.cli-diagnostic.v1"

        return {
            "schema": "wordpress-hx.sdk043-production-summary.v1",
            "positiveCases": runtime.positive,
            "negativeCases": runtime.negative,
            "noWriteAssertions": runtime.no_write,
            "effectiveFingerprint": expected_inputs["fingerprint"],
            "nodeImage": NODE_IMAGE,
            "outcome": "passed",
        }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-production.py <compiled-runtime-root>")
    summary = run(Path(sys.argv[1]))
    print(json.dumps(summary, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
