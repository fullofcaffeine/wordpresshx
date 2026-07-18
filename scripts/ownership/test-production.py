#!/usr/bin/env python3
"""Exercise the Haxe/Genes production ownership transaction on exact Node."""

from __future__ import annotations

import hashlib
import json
import os
import copy
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CURRENT_MANIFEST = ROOT / "fixtures/ownership/valid/current.generated-files.json"
NEXT_MANIFEST = ROOT / "fixtures/ownership/valid/next.generated-files.json"
INITIAL_PLUGIN = ROOT / "fixtures/ownership/artifacts/initial/acme-observatory.php.txt"
INITIAL_STALE = ROOT / "fixtures/ownership/artifacts/initial/stale.php.txt"
NEXT_PLUGIN = ROOT / "fixtures/ownership/artifacts/next/acme-observatory.php.txt"
NEXT_THEME = ROOT / "fixtures/ownership/artifacts/next/theme.json.txt"

NODE_IMAGE = (
    "docker.io/library/node@sha256:"
    "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
MANIFEST_RELATIVE = Path("build/_GeneratedFiles.json")
LOCK_RELATIVE = Path("build/.wphx-transactions/lock")
JOURNAL_RELATIVE = Path("build/.wphx-transactions/journal.json")
PLUGIN_RELATIVE = Path("build/site/acme-observatory/acme-observatory.php")
STALE_RELATIVE = Path("build/site/acme-observatory/stale.php")
THEME_RELATIVE = Path("build/site/acme-observatory/theme.json")
UNOWNED_RELATIVE = Path("build/site/acme-observatory/README.txt")


def canonical(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode()


def snapshot(root: Path) -> dict[str, tuple[str, bytes | str]]:
    result: dict[str, tuple[str, bytes | str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            result[relative] = ("symlink", os.readlink(path))
        elif path.is_file():
            result[relative] = ("file", path.read_bytes())
        elif path.is_dir():
            result[relative] = ("directory", "")
        else:
            result[relative] = ("special", "")
    return result


def write_file(root: Path, relative: Path, data: bytes) -> None:
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def materialize_current(project: Path) -> None:
    write_file(project, PLUGIN_RELATIVE, INITIAL_PLUGIN.read_bytes())
    write_file(project, STALE_RELATIVE, INITIAL_STALE.read_bytes())
    write_file(project, UNOWNED_RELATIVE, b"hand-owned fixture\n")
    write_file(project, MANIFEST_RELATIVE, CURRENT_MANIFEST.read_bytes())


def make_stage(root: Path, generation: str, *, omit: Path | None = None) -> Path:
    stage = root / ("stage-" + generation)
    entries = (
        {
            PLUGIN_RELATIVE: INITIAL_PLUGIN.read_bytes(),
            STALE_RELATIVE: INITIAL_STALE.read_bytes(),
        }
        if generation == "current"
        else {
            PLUGIN_RELATIVE: NEXT_PLUGIN.read_bytes(),
            THEME_RELATIVE: NEXT_THEME.read_bytes(),
        }
    )
    for relative, data in entries.items():
        if relative != omit:
            write_file(stage, relative, data)
    return stage


class Runtime:
    def __init__(self, runtime_root: Path, evidence_root: Path) -> None:
        self.runtime_root = runtime_root.resolve()
        self.evidence_root = evidence_root.resolve()
        self.positive = 0
        self.negative = 0
        self.crash = 0

    def container_path(self, path: Path) -> str:
        return "/evidence/" + path.resolve().relative_to(self.evidence_root).as_posix()

    def invoke(
        self,
        project: Path,
        command: str,
        arguments: list[str] | None = None,
        *,
        fault: str | None = None,
        expected: int = 0,
    ) -> subprocess.CompletedProcess[str]:
        mapped: list[str] = []
        for argument in arguments or []:
            if argument.startswith("repo:"):
                mapped.append("/repo/" + argument.removeprefix("repo:"))
            elif argument.startswith("evidence:"):
                mapped.append(
                    self.container_path(self.evidence_root / argument.removeprefix("evidence:"))
                )
            else:
                mapped.append(argument)
        invocation = [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--mount",
            f"type=bind,src={self.runtime_root},dst=/runtime,readonly",
            "--mount",
            f"type=bind,src={self.evidence_root},dst=/evidence",
            "--mount",
            f"type=bind,src={ROOT},dst=/repo,readonly",
        ]
        if fault is not None:
            invocation.extend(["--env", f"WPHX_OWNERSHIP_FAULT={fault}"])
        invocation.extend(
            [
                NODE_IMAGE,
                "node",
                "/runtime/index.js",
                command,
                self.container_path(project),
                *mapped,
            ]
        )
        result = subprocess.run(invocation, text=True, capture_output=True, check=False)
        if result.returncode != expected:
            raise AssertionError(
                f"{command} exited {result.returncode}, expected {expected}\n"
                f"stdout: {result.stdout}\nstderr: {result.stderr}"
            )
        for forbidden in (str(self.evidence_root), "/evidence/"):
            if expected != 0 and forbidden in result.stderr:
                raise AssertionError(f"failure exposed an absolute path: {result.stderr}")
        if expected == 0:
            document = json.loads(result.stdout)
            if set(document) != {"outcome"} and command != "inspect":
                raise AssertionError(f"unexpected successful report: {document}")
            self.positive += 1
        elif expected == 91:
            self.crash += 1
        else:
            report = json.loads(result.stderr)
            if set(report) != {"code", "message", "path"}:
                raise AssertionError(f"unexpected failure report: {report}")
            self.negative += 1
        return result


def publish_args(manifest: str, stage: Path, root: Path, validator: str = "pass") -> list[str]:
    return [
        "repo:" + manifest,
        "evidence:" + stage.relative_to(root).as_posix(),
        validator,
    ]


def assert_current(project: Path) -> None:
    assert (project / PLUGIN_RELATIVE).read_bytes() == INITIAL_PLUGIN.read_bytes()
    assert (project / STALE_RELATIVE).read_bytes() == INITIAL_STALE.read_bytes()
    assert (project / MANIFEST_RELATIVE).read_bytes() == CURRENT_MANIFEST.read_bytes()


def assert_next(project: Path) -> None:
    assert (project / PLUGIN_RELATIVE).read_bytes() == NEXT_PLUGIN.read_bytes()
    assert not (project / STALE_RELATIVE).exists()
    assert (project / THEME_RELATIVE).read_bytes() == NEXT_THEME.read_bytes()
    assert (project / MANIFEST_RELATIVE).read_bytes() == NEXT_MANIFEST.read_bytes()
    assert not (project / LOCK_RELATIVE).exists()
    assert not (project / JOURNAL_RELATIVE).exists()


def case_root(evidence: Path, name: str) -> tuple[Path, Path]:
    root = evidence / name
    project = root / "project"
    project.mkdir(parents=True)
    return root, project


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-sdk041-production-", dir=temporary_parent
    ) as raw:
        evidence = Path(raw)
        runtime = Runtime(runtime_root, evidence)

        root, project = case_root(evidence, "publish-update-noop-clean")
        write_file(project, UNOWNED_RELATIVE, b"hand-owned fixture\n")
        current_stage = make_stage(root, "current")
        result = runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json",
                current_stage,
                evidence,
            ),
        )
        assert json.loads(result.stdout)["outcome"] == "published"
        assert_current(project)
        next_stage = make_stage(root, "next")
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json",
                next_stage,
                evidence,
            ),
        )
        assert_next(project)
        assert (project / UNOWNED_RELATIVE).read_bytes() == b"hand-owned fixture\n"
        before_noop = snapshot(project)
        replay_stage = make_stage(root / "replay", "next")
        result = runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json",
                replay_stage,
                evidence,
            ),
        )
        assert json.loads(result.stdout)["outcome"] == "no-op"
        assert snapshot(project) == before_noop
        runtime.invoke(project, "clean")
        assert not (project / PLUGIN_RELATIVE).exists()
        assert not (project / THEME_RELATIVE).exists()
        assert (project / UNOWNED_RELATIVE).read_bytes() == b"hand-owned fixture\n"
        empty_manifest = json.loads((project / MANIFEST_RELATIVE).read_text())
        assert empty_manifest["files"] == []
        assert empty_manifest["manifestDigest"] == hashlib.sha256(
            canonical({key: value for key, value in empty_manifest.items() if key != "manifestDigest"})[:-1]
        ).hexdigest()

        root, project = case_root(evidence, "adopt")
        materialize_current(project)
        runtime.invoke(project, "adopt", [PLUGIN_RELATIVE.as_posix()])
        assert (project / PLUGIN_RELATIVE).read_bytes() == INITIAL_PLUGIN.read_bytes()
        adopted = json.loads((project / MANIFEST_RELATIVE).read_text())
        assert [item["path"] for item in adopted["files"]] == [STALE_RELATIVE.as_posix()]
        before_collision = snapshot(project)
        stage = make_stage(root, "current")
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json", stage, evidence
            ),
            expected=3,
        )
        assert snapshot(project) == before_collision

        root, project = case_root(evidence, "caught-partial")
        materialize_current(project)
        stage = make_stage(root, "next")
        before = snapshot(project)
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json", stage, evidence
            ),
            fault="caught:after-operation-1",
            expected=3,
        )
        assert snapshot(project) == before

        root, project = case_root(evidence, "caught-committed")
        materialize_current(project)
        stage = make_stage(root, "next")
        result = runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json", stage, evidence
            ),
            fault="caught:after-manifest-phase",
        )
        assert json.loads(result.stdout)["outcome"] == "published-recovered"
        assert_next(project)

        rollback_points = [
            "after-journal-prepared",
            "after-publishing-phase",
            "after-operation-1",
            "after-operation-2",
            "after-operation-3",
        ]
        finalize_points = ["after-manifest-rename", "after-manifest-phase"]
        for point in rollback_points + finalize_points:
            root, project = case_root(evidence, "crash-" + point)
            materialize_current(project)
            stage = make_stage(root, "next")
            before = snapshot(project)
            runtime.invoke(
                project,
                "publish",
                publish_args(
                    "fixtures/ownership/valid/next.generated-files.json",
                    stage,
                    evidence,
                ),
                fault="crash:" + point,
                expected=91,
            )
            assert (project / LOCK_RELATIVE).is_file()
            assert (project / JOURNAL_RELATIVE).is_file()
            result = runtime.invoke(project, "recover")
            if point in rollback_points:
                assert json.loads(result.stdout)["outcome"] == "rolled-back"
                assert snapshot(project) == before
            else:
                assert json.loads(result.stdout)["outcome"] == "finalized"
                assert_next(project)

        root, project = case_root(evidence, "crash-initial-publication")
        stage = make_stage(root, "current")
        before = snapshot(project)
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json", stage, evidence
            ),
            fault="crash:after-operation-1",
            expected=91,
        )
        result = runtime.invoke(project, "recover")
        assert json.loads(result.stdout)["outcome"] == "rolled-back"
        assert snapshot(project) == before

        root, project = case_root(evidence, "crash-clean-rollback")
        materialize_current(project)
        before = snapshot(project)
        runtime.invoke(
            project,
            "clean",
            fault="crash:after-operation-1",
            expected=91,
        )
        result = runtime.invoke(project, "recover")
        assert json.loads(result.stdout)["outcome"] == "rolled-back"
        assert snapshot(project) == before

        root, project = case_root(evidence, "crash-clean-finalize")
        materialize_current(project)
        runtime.invoke(
            project,
            "clean",
            fault="crash:after-manifest-phase",
            expected=91,
        )
        result = runtime.invoke(project, "recover")
        assert json.loads(result.stdout)["outcome"] == "finalized"
        assert not (project / PLUGIN_RELATIVE).exists()
        assert not (project / STALE_RELATIVE).exists()
        assert (project / UNOWNED_RELATIVE).read_bytes() == b"hand-owned fixture\n"
        assert json.loads((project / MANIFEST_RELATIVE).read_text())["files"] == []

        root, project = case_root(evidence, "crash-adopt-finalize")
        materialize_current(project)
        runtime.invoke(
            project,
            "adopt",
            [PLUGIN_RELATIVE.as_posix()],
            fault="crash:after-manifest-rename",
            expected=91,
        )
        result = runtime.invoke(project, "recover")
        assert json.loads(result.stdout)["outcome"] == "finalized"
        assert (project / PLUGIN_RELATIVE).read_bytes() == INITIAL_PLUGIN.read_bytes()
        assert [
            item["path"]
            for item in json.loads((project / MANIFEST_RELATIVE).read_text())["files"]
        ] == [STALE_RELATIVE.as_posix()]

        root, project = case_root(evidence, "recovery-conflict")
        materialize_current(project)
        stage = make_stage(root, "next")
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json", stage, evidence
            ),
            fault="crash:after-operation-1",
            expected=91,
        )
        (project / PLUGIN_RELATIVE).write_bytes(b"unexpected concurrent edit\n")
        before_recovery = snapshot(project)
        runtime.invoke(project, "recover", expected=3)
        assert snapshot(project) == before_recovery

        root, project = case_root(evidence, "malformed-journal-recovery")
        materialize_current(project)
        stage = make_stage(root, "next")
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/next.generated-files.json", stage, evidence
            ),
            fault="crash:after-journal-prepared",
            expected=91,
        )
        (project / JOURNAL_RELATIVE).write_bytes(b"{not-json}\n")
        before_recovery = snapshot(project)
        runtime.invoke(project, "recover", expected=3)
        assert snapshot(project) == before_recovery

        def negative(
            name: str,
            setup,
            manifest: str = "fixtures/ownership/valid/current.generated-files.json",
            generation: str = "current",
            validator: str = "pass",
        ) -> None:
            root, project = case_root(evidence, "negative-" + name)
            stage = make_stage(root, generation)
            setup(root, project, stage)
            before = snapshot(project)
            runtime.invoke(
                project,
                "publish",
                publish_args(manifest, stage, evidence, validator),
                expected=3,
            )
            assert snapshot(project) == before, name

        negative(
            "unowned-collision",
            lambda _root, project, _stage: write_file(
                project, PLUGIN_RELATIVE, INITIAL_PLUGIN.read_bytes()
            ),
        )

        def modified(_root: Path, project: Path, _stage: Path) -> None:
            materialize_current(project)
            (project / PLUGIN_RELATIVE).write_bytes(b"manual edit\n")

        negative(
            "modified-owned",
            modified,
            "fixtures/ownership/valid/next.generated-files.json",
            "next",
        )

        def modified_stale(_root: Path, project: Path, _stage: Path) -> None:
            materialize_current(project)
            (project / STALE_RELATIVE).write_bytes(b"manual stale edit\n")

        negative(
            "modified-stale",
            modified_stale,
            "fixtures/ownership/valid/next.generated-files.json",
            "next",
        )

        if hasattr(os, "mkfifo"):

            def special_owned(_root: Path, project: Path, _stage: Path) -> None:
                materialize_current(project)
                (project / PLUGIN_RELATIVE).unlink()
                os.mkfifo(project / PLUGIN_RELATIVE)

            negative(
                "special-owned-file",
                special_owned,
                "fixtures/ownership/valid/next.generated-files.json",
                "next",
            )

        def missing_manifest(_root: Path, project: Path, _stage: Path) -> None:
            materialize_current(project)
            (project / MANIFEST_RELATIVE).unlink()

        negative("missing-manifest-unowned", missing_manifest)

        def malformed_manifest(_root: Path, project: Path, _stage: Path) -> None:
            materialize_current(project)
            (project / MANIFEST_RELATIVE).write_bytes(b"{not-json}\n")

        negative("malformed-current-manifest", malformed_manifest)

        def parent_symlink(root: Path, project: Path, _stage: Path) -> None:
            (root / "outside").mkdir()
            (project / "build").mkdir()
            os.symlink(root / "outside", project / "build/site")

        negative("parent-symlink", parent_symlink)

        def broken_destination(root: Path, project: Path, _stage: Path) -> None:
            target = project / PLUGIN_RELATIVE
            target.parent.mkdir(parents=True)
            os.symlink(root / "missing", target)

        negative("broken-destination-symlink", broken_destination)
        negative("validator-failure", lambda *_: None, validator="fail")

        root, project = case_root(evidence, "negative-incomplete-stage")
        stage = make_stage(root, "current", omit=STALE_RELATIVE)
        before = snapshot(project)
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json", stage, evidence
            ),
            expected=3,
        )
        assert snapshot(project) == before

        root, project = case_root(evidence, "negative-extra-stage")
        stage = make_stage(root, "current")
        write_file(stage, Path("build/site/undeclared.php"), b"undeclared\n")
        before = snapshot(project)
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json", stage, evidence
            ),
            expected=3,
        )
        assert snapshot(project) == before

        root, project = case_root(evidence, "negative-stage-symlink")
        stage = make_stage(root, "current")
        (stage / STALE_RELATIVE).unlink()
        os.symlink(root / "missing", stage / STALE_RELATIVE)
        before = snapshot(project)
        runtime.invoke(
            project,
            "publish",
            publish_args(
                "fixtures/ownership/valid/current.generated-files.json", stage, evidence
            ),
            expected=3,
        )
        assert snapshot(project) == before

        root, project = case_root(evidence, "negative-orphan-lock")
        write_file(project, LOCK_RELATIVE, b"orphan\n")
        before = snapshot(project)
        runtime.invoke(project, "recover", expected=3)
        assert snapshot(project) == before

        def mutated_manifest(mutator) -> bytes:
            document = copy.deepcopy(json.loads(CURRENT_MANIFEST.read_text()))
            mutator(document)
            material = [
                {
                    "contentSha256": item["contentSha256"],
                    "path": item["path"],
                    "sizeBytes": item["sizeBytes"],
                }
                for item in document["files"]
            ]
            document["inputs"]["generationSha256"] = hashlib.sha256(
                canonical(material)[:-1]
            ).hexdigest()
            document.pop("manifestDigest", None)
            document["manifestDigest"] = hashlib.sha256(
                canonical(document)[:-1]
            ).hexdigest()
            return canonical(document)

        def add_duplicate(document: dict[str, object]) -> None:
            document["files"].append(copy.deepcopy(document["files"][0]))
            document["files"].sort(key=lambda item: item["path"])

        def add_case_collision(document: dict[str, object]) -> None:
            duplicate = copy.deepcopy(document["files"][0])
            duplicate["path"] = (
                "build/site/acme-observatory/ACME-OBSERVATORY.PHP"
            )
            document["files"].append(duplicate)
            document["files"].sort(key=lambda item: item["path"])

        strict_documents = {
            "duplicate-key": CURRENT_MANIFEST.read_bytes().replace(
                b"{", b'{"schema":"wordpress-hx.generated-files.v1",', 1
            ),
            "float": CURRENT_MANIFEST.read_bytes().replace(
                b'"sizeBytes":109', b'"sizeBytes":109.0', 1
            ),
            "pretty": json.dumps(json.loads(CURRENT_MANIFEST.read_text()), indent=2).encode()
            + b"\n",
            "invalid-utf8": CURRENT_MANIFEST.read_bytes()[:-2] + b"\xff}\n",
            "traversal-path": mutated_manifest(
                lambda document: document["files"][0].update(
                    {"path": "build/site/../escape.php"}
                )
            ),
            "duplicate-path": mutated_manifest(add_duplicate),
            "case-collision": mutated_manifest(add_case_collision),
            "unknown-field": mutated_manifest(
                lambda document: document.update({"force": True})
            ),
            "legacy-schema": mutated_manifest(
                lambda document: document.update(
                    {"schema": "wordpress-hx.generated-files.v0"}
                )
            ),
        }
        for name, document in strict_documents.items():
            root, project = case_root(evidence, "negative-json-" + name)
            stage = make_stage(root, "current")
            bad = root / "bad.json"
            bad.write_bytes(document)
            before = snapshot(project)
            runtime.invoke(
                project,
                "publish",
                [
                    "evidence:" + bad.relative_to(evidence).as_posix(),
                    "evidence:" + stage.relative_to(evidence).as_posix(),
                    "pass",
                ],
                expected=3,
            )
            assert snapshot(project) == before

        return {
            "crashCheckpointCount": runtime.crash,
            "exactNodeVersion": "22.17.0",
            "negativeInvocationCount": runtime.negative,
            "outcome": "passed",
            "positiveInvocationCount": runtime.positive,
            "recoveryModes": ["finalize-complete-next", "rollback-partial"],
        }


def main() -> int:
    if len(sys.argv) != 2:
        raise ValueError("usage: test-production.py <compiled-runtime-root>")
    runtime_root = Path(sys.argv[1])
    if not (runtime_root / "index.js").is_file():
        raise ValueError("compiled ownership runtime is missing index.js")
    summary = run(runtime_root)
    print("OWNERSHIP_PRODUCTION_SUMMARY=" + canonical(summary).decode().rstrip())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"ownership production gate failed: {error}", file=sys.stderr)
        raise SystemExit(1)
