#!/usr/bin/env python3
"""Exercise deterministic Haxe-first scaffold planning and publication."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NODE_IMAGE = (
    "docker.io/library/node@sha256:"
    "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
BEGIN = "# BEGIN wordpress-hx managed ignores"
END = "# END wordpress-hx managed ignores"
MANAGED_BLOCK = "\n".join(
    (
        BEGIN,
        "/.wphx/runtime/",
        "/.wphx/transactions/",
        "/build/",
        "/dist/",
        "/node_modules/",
        END,
    )
)
PLAN_KEYS = {
    "schema",
    "operation",
    "kind",
    "projectId",
    "profile",
    "entryPoint",
    "target",
    "dryRun",
    "status",
    "files",
    "limitations",
}
FILE_KEYS = {"path", "action", "ownership", "mode", "sha256", "sizeBytes"}


def canonical(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode()


def snapshot(root: Path) -> dict[str, tuple[str, int, bytes | str]]:
    result: dict[str, tuple[str, int, bytes | str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        metadata = path.lstat()
        mode = stat.S_IMODE(metadata.st_mode)
        if stat.S_ISLNK(metadata.st_mode):
            result[relative] = ("link", mode, os.readlink(path))
        elif stat.S_ISREG(metadata.st_mode):
            result[relative] = ("file", mode, path.read_bytes())
        elif stat.S_ISDIR(metadata.st_mode):
            result[relative] = ("directory", mode, "")
        else:
            result[relative] = ("special", mode, "")
    return result


def make_tools(evidence: Path) -> None:
    tools = evidence / "tools"
    tools.mkdir()
    haxe = tools / "haxe"
    haxe.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "if [ \"${1:-}\" = --version ]; then printf '%s\\n' 4.3.7; exit 0; fi\n"
        "if [ \"$#\" -ne 1 ] || [ \"$1\" != .wphx/bootstrap/project.hxml ]; then exit 64; fi\n"
        "grep -Fx -- '-cp src' \"$1\" >/dev/null\n"
        "grep -Fx -- '-cp test' \"$1\" >/dev/null\n"
        "grep -Fx -- '--no-output' \"$1\" >/dev/null\n"
    )
    lix = tools / "lix"
    lix.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "[ \"${1:-}\" = --version ]\n"
        "printf '%s\\n' 15.12.2\n"
    )
    haxe.chmod(0o755)
    lix.chmod(0o755)


class Runtime:
    def __init__(self, runtime_root: Path, evidence_root: Path) -> None:
        self.runtime_root = runtime_root.resolve()
        self.evidence_root = evidence_root.resolve()
        self.positive = 0
        self.negative = 0
        self.no_write = 0

    def container(self, path: Path) -> str:
        logical = Path(os.path.abspath(path))
        return "/evidence/" + logical.relative_to(self.evidence_root).as_posix()

    def invoke(
        self,
        arguments: list[str],
        *,
        expected: int = 0,
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
            NODE_IMAGE,
            "node",
            "/runtime/index.js",
            *arguments,
        ]
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        if result.returncode != expected:
            raise AssertionError(
                f"{' '.join(arguments)} exited {result.returncode}, expected {expected}\n"
                f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            )
        combined = result.stdout + result.stderr
        for forbidden in (str(self.evidence_root), "/evidence/", ".wordpresshx-new-", ".wordpresshx-init-"):
            assert forbidden not in combined, f"command exposed private value {forbidden!r}"
        if expected == 0:
            self.positive += 1
        else:
            self.negative += 1
        return result

    def scaffold(
        self,
        arguments: list[str],
        *,
        expected: int = 0,
        workdir: Path | None = None,
    ) -> dict[str, object]:
        result = self.invoke([*arguments, "--json"], expected=expected, workdir=workdir)
        stream = result.stdout if expected == 0 else result.stderr
        assert stream.endswith("\n") and len(stream.splitlines()) == 1
        value = json.loads(stream)
        assert stream.encode() == canonical(value)
        assert isinstance(value, dict)
        if expected == 0:
            validate_plan(value)
        else:
            assert value["schema"] == "wordpress-hx.cli-diagnostic.v1"
            assert value["exitCode"] == expected
            assert value["code"].startswith("WPHX")
        return value

    def project_command(self, project: Path, command: str, *, expected: int = 0) -> list[dict[str, object]]:
        result = self.invoke(
            [command, "--project", self.container(project), "--json"],
            expected=expected,
        )
        assert result.stdout.endswith("\n")
        documents: list[dict[str, object]] = []
        for line in result.stdout.splitlines(keepends=True):
            value = json.loads(line)
            assert line.encode() == canonical(value)
            assert isinstance(value, dict)
            documents.append(value)
        return documents


def validate_plan(plan: dict[str, object]) -> None:
    assert set(plan) == PLAN_KEYS
    assert plan["schema"] == "wordpress-hx.scaffold-plan.v1"
    assert plan["operation"] in {"new-site", "init-site"}
    assert plan["kind"] == "site"
    assert plan["profile"] == "wp70-release"
    assert plan["target"] == plan["projectId"]
    assert plan["status"] == ("planned" if plan["dryRun"] else "published")
    assert plan["limitations"] == [
        "native-target-producers-not-registered",
        "public-package-installation-blocked",
    ]
    files = plan["files"]
    assert isinstance(files, list) and files
    paths = [item["path"] for item in files]
    assert paths == sorted(paths) and len(paths) == len(set(paths))
    for item in files:
        keys = set(item)
        assert keys in (FILE_KEYS, FILE_KEYS | {"beforeSha256"})
        assert item["action"] in {"create", "update-marker"}
        assert item["ownership"] in {"authored", "cli-owned"}
        assert item["mode"] == 0o644
        assert isinstance(item["sizeBytes"], int) and item["sizeBytes"] >= 0
        assert len(item["sha256"]) == 64
        assert not item["path"].startswith("/")
        assert ".." not in item["path"].split("/")
        if item["action"] == "update-marker":
            assert len(item["beforeSha256"]) == 64
        else:
            assert "beforeSha256" not in item


def validate_published(project: Path, plan: dict[str, object]) -> None:
    assert stat.S_IMODE(project.stat().st_mode) == 0o755
    for item in plan["files"]:
        path = project / item["path"]
        assert path.is_file() and not path.is_symlink()
        data = path.read_bytes()
        assert len(data) == item["sizeBytes"]
        assert hashlib.sha256(data).hexdigest() == item["sha256"]
        assert stat.S_IMODE(path.stat().st_mode) == item["mode"]


def assert_no_private_stages(parent: Path) -> None:
    assert not list(parent.glob(".wordpresshx-new-*"))
    assert not list(parent.glob(".wordpresshx-init-*"))


def expect_no_write(
    runtime: Runtime,
    watched: Path,
    arguments: list[str],
    expected: int,
    code: str,
    *,
    workdir: Path | None = None,
) -> None:
    before = snapshot(watched)
    diagnostic = runtime.scaffold(arguments, expected=expected, workdir=workdir)
    assert diagnostic["code"] == code
    assert snapshot(watched) == before
    runtime.no_write += 1


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk045-production-", dir=temporary_parent) as raw:
        evidence = Path(raw)
        make_tools(evidence)
        runtime = Runtime(runtime_root, evidence)

        schema = json.loads((ROOT / "schemas/scaffold-plan.schema.json").read_text())
        assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
        assert schema["additionalProperties"] is False

        first_parent = evidence / "first"
        second_parent = evidence / "second"
        first_parent.mkdir()
        second_parent.mkdir()
        dry_before = snapshot(first_parent)
        dry = runtime.scaffold(
            ["new", "site", "acme-observatory", "--project", runtime.container(first_parent), "--dry-run"]
        )
        assert dry["dryRun"] is True and dry["status"] == "planned"
        assert snapshot(first_parent) == dry_before
        runtime.no_write += 1

        normalized_parent = evidence / "normalized"
        normalized_parent.mkdir()
        normalized_before = snapshot(normalized_parent)
        normalized = runtime.scaffold(
            ["new", "site", "class-1", "--project", runtime.container(normalized_parent), "--dry-run"]
        )
        assert normalized["entryPoint"] == "class_site.p_1.Site"
        assert any(item["path"] == "src/class_site/p_1/Site.hx" for item in normalized["files"])
        assert snapshot(normalized_parent) == normalized_before
        runtime.no_write += 1

        first_plan = runtime.scaffold(
            ["new", "site", "acme-observatory", "--project", runtime.container(first_parent)]
        )
        second_plan = runtime.scaffold(
            ["new", "site", "acme-observatory", "--project", runtime.container(second_parent)]
        )
        first = first_parent / "acme-observatory"
        second = second_parent / "acme-observatory"
        validate_published(first, first_plan)
        validate_published(second, second_plan)
        assert first_plan["entryPoint"] == "acme.observatory.Site"
        assert first_plan["files"] == second_plan["files"]
        assert snapshot(first) == snapshot(second)
        assert_no_private_stages(first_parent)
        assert_no_private_stages(second_parent)
        assert not any(path.suffix in {".php", ".js", ".ts", ".tsx", ".css"} for path in first.rglob("*"))
        site_source = (first / "src/acme/observatory/Site.hx").read_text()
        assert 'public static inline final id = "acme-observatory";' in site_source
        assert 'public static inline final profile = "wp70-release";' in site_source
        scaffold_lock = json.loads((first / ".wphx/project.lock.json").read_text())
        canonical_lock = json.loads(
            (ROOT / "fixtures/project-cli/project/.wphx/project.lock.json").read_text()
        )
        assert scaffold_lock["components"] == canonical_lock["components"]

        before_doctor = snapshot(first)
        doctor_documents = runtime.project_command(first, "doctor")
        doctor = next(value for value in doctor_documents if value.get("schema") == "wordpress-hx.doctor.v1")
        assert doctor["status"] == "passed"
        assert snapshot(first) == before_doctor
        runtime.no_write += 1
        check_documents = runtime.project_command(first, "check")
        assert any(value.get("stage") == "haxe-typing-and-plan" and value.get("status") == "passed" for value in check_documents)
        assert snapshot(first) == before_doctor
        runtime.no_write += 1
        build_documents = runtime.project_command(first, "build")
        assert any(value.get("event") == "build-published" for value in build_documents)
        manifest = json.loads((first / "build/wordpress/_GeneratedFiles.json").read_text())
        assert manifest["schema"] == "wordpress-hx.generated-files.v1"
        assert (first / "dist/wordpress-hx.zip").is_file()

        init_parent = evidence / "init-parent"
        init_root = init_parent / "editorial-site"
        init_root.mkdir(parents=True)
        unrelated = init_root / "notes.txt"
        unrelated.write_bytes(b"hand-owned notes\n")
        marker_source = "vendor/\n" + BEGIN + "\nold-owned-line\n" + END + "\nkeep.log\n"
        (init_root / ".gitignore").write_text(marker_source)
        init_before = snapshot(init_root)
        init_dry = runtime.scaffold(
            ["init", "--project", runtime.container(init_root), "--dry-run"]
        )
        marker_action = next(item for item in init_dry["files"] if item["path"] == ".gitignore")
        assert marker_action["action"] == "update-marker"
        assert marker_action["beforeSha256"] == hashlib.sha256(marker_source.encode()).hexdigest()
        assert snapshot(init_root) == init_before
        runtime.no_write += 1
        init_plan = runtime.scaffold(["init", "--project", runtime.container(init_root)])
        validate_published(init_root, init_plan)
        assert unrelated.read_bytes() == b"hand-owned notes\n"
        assert (init_root / ".gitignore").read_text() == "vendor/\n" + MANAGED_BLOCK + "\nkeep.log\n"
        assert_no_private_stages(init_parent)

        collision_parent = evidence / "collision-parent"
        collision_target = collision_parent / "existing-site"
        collision_target.mkdir(parents=True)
        (collision_target / "sentinel.txt").write_bytes(b"preserve\n")
        expect_no_write(
            runtime,
            collision_parent,
            ["new", "site", "existing-site", "--project", runtime.container(collision_parent)],
            5,
            "WPHX3007",
        )

        init_collision = evidence / "init-collision"
        init_collision.mkdir()
        (init_collision / "README.md").write_bytes(b"hand-owned\n")
        expect_no_write(
            runtime,
            init_collision,
            ["init", "--project", runtime.container(init_collision)],
            5,
            "WPHX3007",
        )

        marker_missing = evidence / "marker-missing"
        marker_missing.mkdir()
        (marker_missing / ".gitignore").write_bytes(b"vendor/\n")
        expect_no_write(
            runtime,
            marker_missing,
            ["init", "--project", runtime.container(marker_missing)],
            5,
            "WPHX3005",
        )
        marker_duplicate = evidence / "marker-duplicate"
        marker_duplicate.mkdir()
        (marker_duplicate / ".gitignore").write_text(BEGIN + "\n" + END + "\n" + BEGIN + "\n" + END + "\n")
        expect_no_write(
            runtime,
            marker_duplicate,
            ["init", "--project", runtime.container(marker_duplicate)],
            5,
            "WPHX3005",
        )

        invalid_parent = evidence / "invalid-parent"
        invalid_parent.mkdir()
        invalid_before = snapshot(invalid_parent)
        for arguments, code in (
            (["new", "site", "Bad-Name", "--project", runtime.container(invalid_parent)], "WPHX3003"),
            (
                [
                    "new",
                    "site",
                    "safe-name",
                    "--profile",
                    "wp69-release",
                    "--project",
                    runtime.container(invalid_parent),
                ],
                "WPHX3004",
            ),
            (["new", "plugin", "safe-name", "--project", runtime.container(invalid_parent)], "WPHX3002"),
        ):
            diagnostic = runtime.scaffold(arguments, expected=2)
            assert diagnostic["code"] == code
            assert snapshot(invalid_parent) == invalid_before
            runtime.no_write += 1

        external = evidence / "external"
        external.mkdir()
        linked_root = evidence / "linked-site"
        linked_root.mkdir()
        os.symlink(external, linked_root / "src")
        linked_before = snapshot(linked_root)
        external_before = snapshot(external)
        diagnostic = runtime.scaffold(
            ["init", "--project", runtime.container(linked_root)], expected=5
        )
        assert diagnostic["code"] == "WPHX3006"
        assert snapshot(linked_root) == linked_before
        assert snapshot(external) == external_before
        runtime.no_write += 1

        real_selected = evidence / "real-selected"
        real_selected.mkdir()
        selected_link = evidence / "selected-link"
        os.symlink(real_selected, selected_link)
        diagnostic = runtime.scaffold(
            ["init", "selected-site", "--project", runtime.container(selected_link)], expected=5
        )
        assert diagnostic["code"] == "WPHX3006"
        assert snapshot(real_selected) == {}
        runtime.no_write += 1

        drift_parent = evidence / "drift-parent"
        drift_parent.mkdir()
        runtime.scaffold(
            ["new", "site", "drift-site", "--project", runtime.container(drift_parent)]
        )
        drift = drift_parent / "drift-site"
        hxml = drift / ".wphx/bootstrap/project.hxml"
        hxml.write_text(hxml.read_text() + "-D hand-edited\n")
        drift_before = snapshot(drift)
        drift_documents = runtime.project_command(drift, "check", expected=5)
        diagnostic_event = next(value for value in drift_documents if value.get("event") == "diagnostic")
        assert diagnostic_event["payload"]["diagnostic"]["code"] == "WPHX3008"
        assert snapshot(drift) == drift_before
        runtime.no_write += 1

        rollback_parent = evidence / "rollback-parent"
        rollback_root = rollback_parent / "rollback-site"
        rollback_root.mkdir(parents=True)
        (rollback_root / ".gitignore").write_text(BEGIN + "\nold\n" + END + "\n")
        locked_directory = rollback_root / ".wphx"
        locked_directory.mkdir()
        locked_directory.chmod(0o555)
        rollback_before = snapshot(rollback_root)
        try:
            diagnostic = runtime.scaffold(
                ["init", "--project", runtime.container(rollback_root)], expected=5
            )
            assert diagnostic["code"] == "WPHX3011"
            assert snapshot(rollback_root) == rollback_before
            assert_no_private_stages(rollback_parent)
            runtime.no_write += 1
        finally:
            locked_directory.chmod(0o755)

        return {
            "schema": "wordpress-hx.sdk045-scaffold-summary.v1",
            "positiveCases": runtime.positive,
            "negativeCases": runtime.negative,
            "noWriteAssertions": runtime.no_write,
            "generatedFileCount": len(first_plan["files"]),
            "newReplay": "byte-identical",
            "doctorCheckBuild": "passed",
            "rollback": "exact-prior-tree-restored",
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
