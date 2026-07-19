#!/usr/bin/env python3
"""Prove the generated Haxe plugin through check/build and native PHP consumers."""

from __future__ import annotations

import hashlib
import json
import os
import queue
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
PHP_IMAGES = (
    "docker.io/library/php@sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5",
    "docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367",
)
FORBIDDEN_HAXE = ("Dynamic", "Any", "cast", "Reflect", "untyped")


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


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


def output_snapshot(project: Path) -> dict[str, tuple[str, int, bytes | str]]:
    result: dict[str, tuple[str, int, bytes | str]] = {}
    for root_name in ("build", "dist"):
        root = project / root_name
        for path, value in snapshot(root).items():
            result[f"{root_name}/{path}"] = value
    return result


def exact_environment() -> dict[str, str]:
    candidates: list[Path] = []
    configured = os.environ.get("WORDPRESSHX_EXACT_NODE_DIR")
    if configured:
        candidates.append(Path(configured))
    candidates.append(Path.home() / ".nvm/versions/node/v22.17.0/bin")
    discovered = shutil.which("node")
    if discovered:
        candidates.append(Path(discovered).resolve().parent)
    exact: Path | None = None
    for candidate in candidates:
        node = candidate / "node"
        npm = candidate / "npm"
        if not node.is_file() or not npm.exists():
            continue
        node_version = subprocess.run(
            [str(node), "--version"], text=True, capture_output=True, check=True
        ).stdout.strip()
        npm_version = subprocess.run(
            [str(npm), "--version"], text=True, capture_output=True, check=True
        ).stdout.strip()
        if node_version == "v22.17.0" and npm_version == "10.9.2":
            exact = candidate
            break
    if exact is None:
        raise AssertionError("the real Node 22.17.0/npm 10.9.2 toolchain is required")
    environment = os.environ.copy()
    environment["PATH"] = str(exact) + os.pathsep + environment["PATH"]
    return environment


class Runtime:
    def __init__(self, runtime_root: Path, environment: dict[str, str]) -> None:
        self.entry = runtime_root.resolve() / "index.js"
        self.environment = environment
        self.positive = 0
        self.negative = 0
        self.no_write = 0

    def invoke(self, arguments: list[str], expected: int = 0) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["node", str(self.entry), *arguments],
            text=True,
            capture_output=True,
            check=False,
            env=self.environment,
        )
        if result.returncode != expected:
            raise AssertionError(
                f"{' '.join(arguments)} exited {result.returncode}, expected {expected}\n"
                f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
            )
        if expected == 0:
            self.positive += 1
        else:
            self.negative += 1
        return result

    def scaffold(self, arguments: list[str], expected: int = 0) -> dict[str, object]:
        result = self.invoke([*arguments, "--json"], expected)
        stream = result.stdout if expected == 0 else result.stderr
        assert stream.endswith("\n") and len(stream.splitlines()) == 1
        value = json.loads(stream)
        assert stream.encode() == canonical(value)
        return value

    def command(
        self,
        project: Path,
        command: str,
        *options: str,
        expected: int = 0,
    ) -> list[dict[str, object]]:
        result = self.invoke(
            [command, "--project", str(project), *options, "--json"], expected
        )
        documents = [json.loads(line) for line in result.stdout.splitlines()]
        for line, value in zip(result.stdout.splitlines(keepends=True), documents):
            assert line.encode() == canonical(value)
        return documents


class DevSession:
    def __init__(self, runtime: Runtime, project: Path) -> None:
        self.events: list[dict[str, object]] = []
        self.stdout_lines: list[str] = []
        self.stderr_lines: list[str] = []
        self.updates: queue.Queue[None] = queue.Queue()
        self.process = subprocess.Popen(
            [
                "node",
                str(runtime.entry),
                "dev",
                "--services=none",
                "--project",
                str(project),
                "--json",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=1,
            env=runtime.environment,
        )
        assert self.process.stdout is not None
        assert self.process.stderr is not None
        self.stdout_thread = threading.Thread(
            target=self._read_stdout, args=(self.process.stdout,), daemon=True
        )
        self.stderr_thread = threading.Thread(
            target=self._read_stderr, args=(self.process.stderr,), daemon=True
        )
        self.stdout_thread.start()
        self.stderr_thread.start()

    def _read_stdout(self, stream) -> None:
        for line in stream:
            self.stdout_lines.append(line)
            value = json.loads(line)
            assert line.encode() == canonical(value)
            if value.get("schema") == "wordpress-hx.cli-event.v1":
                self.events.append(value)
            self.updates.put(None)

    def _read_stderr(self, stream) -> None:
        for line in stream:
            self.stderr_lines.append(line)
            self.updates.put(None)

    def wait_for(
        self,
        event: str,
        *,
        after: int = 0,
        predicate: Callable[[dict[str, object]], bool] | None = None,
        timeout: float = 20.0,
    ) -> tuple[int, dict[str, object]]:
        deadline = time.monotonic() + timeout
        while True:
            for index in range(after, len(self.events)):
                candidate = self.events[index]
                if candidate["event"] == event and (
                    predicate is None or predicate(candidate)
                ):
                    return index, candidate
            if self.process.poll() is not None:
                raise AssertionError(
                    f"development process exited {self.process.returncode} before {event}\n"
                    f"stdout:{''.join(self.stdout_lines)}\n"
                    f"stderr:{''.join(self.stderr_lines)}"
                )
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(
                    f"timed out waiting for {event}\n"
                    f"stdout:{''.join(self.stdout_lines)}\n"
                    f"stderr:{''.join(self.stderr_lines)}"
                )
            try:
                self.updates.get(timeout=min(remaining, 0.25))
            except queue.Empty:
                pass

    def stop(self) -> None:
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGINT)
        status = self.process.wait(timeout=15)
        self.stdout_thread.join(timeout=2)
        self.stderr_thread.join(timeout=2)
        assert status == 130, (
            f"development process exited {status}\n"
            f"stdout:{''.join(self.stdout_lines)}\n"
            f"stderr:{''.join(self.stderr_lines)}"
        )


def expect_command_no_write(
    runtime: Runtime,
    project: Path,
    command: str,
    expected: int,
    code: str,
) -> None:
    before = snapshot(project)
    documents = runtime.command(project, command, expected=expected)
    diagnostic = next(value for value in documents if value.get("event") == "diagnostic")
    assert diagnostic["payload"]["diagnostic"]["code"] == code
    assert snapshot(project) == before
    runtime.no_write += 1


def php_matrix(plugin: Path, bootstrap_class: str) -> None:
    for image in PHP_IMAGES:
        for path in sorted(plugin.rglob("*.php")):
            relative = path.relative_to(plugin.parent.parent.parent).as_posix()
            subprocess.run(
                [
                    "docker",
                    "run",
                    "--rm",
                    "--network",
                    "none",
                    "--mount",
                    f"type=bind,src={plugin.parent.parent.parent},dst=/project,readonly",
                    image,
                    "php",
                    "-l",
                    f"/project/{relative}",
                ],
                check=True,
                text=True,
                capture_output=True,
            )
    result = subprocess.run(
        ["php", str(ROOT / "scripts/scaffold/plugin-native-caller.php"), str(plugin / f"{plugin.name}.php"), bootstrap_class],
        check=True,
        text=True,
        capture_output=True,
    )
    assert json.loads(result.stdout) == {
        "booted": True,
        "class": bootstrap_class,
        "methods": ["boot", "isBooted"],
        "outputBytes": 0,
    }


def strict_haxe_scan() -> None:
    paths = [
        ROOT / "packages/cli/project-api",
        ROOT / "packages/cli/src/wordpresshx/cli/scaffold",
        ROOT / "packages/cli/src/wordpresshx/cli/project/CompilerRunner.hx",
        ROOT / "packages/cli/src/wordpresshx/cli/project/ProjectBuild.hx",
    ]
    paths.extend(sorted((ROOT / "packages/cli/src/wordpresshx/cli/project").glob("Plugin*.hx")))
    for root in paths:
        candidates = [root] if root.is_file() else sorted(root.rglob("*.hx"))
        for path in candidates:
            source = path.read_text()
            pattern = re.compile(r"\b(?:" + "|".join(FORBIDDEN_HAXE) + r")\b")
            match = pattern.search(source)
            assert match is None, f"{path} contains forbidden Haxe token {match.group(0)}"


def dev_cycle(
    runtime: Runtime,
    project: Path,
    source_path: Path,
    stable_source: str,
    root_php: Path,
) -> None:
    session = DevSession(runtime, project)
    try:
        initial_index, _ = session.wait_for(
            "build-published",
            predicate=lambda value: value["payload"].get("generation") == 1,
        )
        assert "Version: 1.2.3" in root_php.read_text()
        changed_source = stable_source.replace(
            'version: "1.2.3"', 'version: "1.2.4"'
        )
        assert changed_source != stable_source
        source_path.write_text(changed_source)
        change_index, _ = session.wait_for("change-detected", after=initial_index + 1)
        second_index, _ = session.wait_for(
            "build-published",
            after=change_index + 1,
            predicate=lambda value: value["payload"].get("generation") == 2,
        )
        assert "Version: 1.2.4" in root_php.read_text()
        source_path.write_text(stable_source)
        third_change_index, _ = session.wait_for(
            "change-detected", after=second_index + 1
        )
        session.wait_for(
            "build-published",
            after=third_change_index + 1,
            predicate=lambda value: value["payload"].get("generation") == 3,
        )
        assert "Version: 1.2.3" in root_php.read_text()
    finally:
        session.stop()
    runtime.positive += 1


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk045-plugin-", dir=temporary_parent) as raw:
        evidence = Path(raw)
        environment = exact_environment()
        runtime = Runtime(runtime_root, environment)
        first_parent = evidence / "first"
        second_parent = evidence / "second"
        dry_parent = evidence / "dry"
        first_parent.mkdir()
        second_parent.mkdir()
        dry_parent.mkdir()

        dry_before = snapshot(dry_parent)
        dry_plan = runtime.scaffold(
            ["new", "plugin", "typed-news", "--project", str(dry_parent), "--dry-run"]
        )
        assert dry_plan["kind"] == "plugin"
        assert dry_plan["operation"] == "new-plugin"
        assert dry_plan["limitations"] == [
            "plugin-bootstrap-only",
            "public-package-installation-blocked",
        ]
        assert snapshot(dry_parent) == dry_before
        runtime.no_write += 1

        first_plan = runtime.scaffold(
            ["new", "plugin", "typed-news", "--project", str(first_parent)]
        )
        second_plan = runtime.scaffold(
            ["new", "plugin", "typed-news", "--project", str(second_parent)]
        )
        first = first_parent / "typed-news"
        second = second_parent / "typed-news"
        assert first_plan["files"] == second_plan["files"]
        assert snapshot(first) == snapshot(second)
        maintained_suffixes = {".php", ".js", ".ts", ".tsx", ".css"}
        assert not any(path.suffix in maintained_suffixes for path in first.rglob("*"))
        source_path = first / "src/typed/news/Site.hx"
        source = source_path.read_text()
        assert "WordPress.plugin();" in source
        assert "Plugin Name" not in source and "typed-news" not in source

        before_check = snapshot(first)
        check = runtime.command(first, "check")
        assert any(value.get("stage") == "php-emission" and value.get("status") == "passed" for value in check)
        assert snapshot(first) == before_check
        runtime.no_write += 1

        before_dry_build = snapshot(first)
        dry_build = runtime.command(first, "build", "--dry-run")
        assert any(value.get("event") == "dry-run-planned" for value in dry_build)
        assert snapshot(first) == before_dry_build
        runtime.no_write += 1

        first_build = runtime.command(first, "build")
        second_build = runtime.command(second, "build")
        assert any(value.get("event") == "build-published" for value in first_build)
        assert any(value.get("event") == "build-published" for value in second_build)
        assert output_snapshot(first) == output_snapshot(second)

        plugin = first / "build/wordpress/typed-news"
        root_php = plugin / "typed-news.php"
        expected_files = {
            "includes/Bootstrap.php",
            "includes/autoload.php",
            "typed-news.php",
        }
        assert {path.relative_to(plugin).as_posix() for path in plugin.rglob("*.php")} == expected_files
        root_source = root_php.read_text()
        for expected in (
            "Plugin Name: Typed News",
            "Description: Typed News generated by WordPressHx.",
            "Requires at least: 7.0",
            "Requires PHP: 7.4",
            "Text Domain: typed-news",
            "\\Typed\\News\\Bootstrap::boot();",
        ):
            assert expected in root_source
        manifest = json.loads((first / "build/wordpress/_GeneratedFiles.json").read_text())
        assert manifest["inputs"]["semanticPlanSha256"] == hashlib.sha256(
            (first / "build/wordpress/.wphx/plugin-plan.json").read_bytes()
        ).hexdigest()
        assert manifest["inputs"]["emissionResultSha256s"] == [
            hashlib.sha256((first / "build/wordpress/.wphx/plugin-emission.json").read_bytes()).hexdigest()
        ]

        before_replay = output_snapshot(first)
        replay = runtime.command(first, "build")
        ownership = next(
            value
            for value in replay
            if value.get("event") == "stage-completed"
            and value.get("stage") == "ownership-publish"
        )
        assert ownership["payload"]["reason"] == "no-op"
        assert output_snapshot(first) == before_replay

        custom_source = source.replace(
            "WordPress.plugin();",
            'WordPress.plugin({name: "Typed Dispatch", description: "A concise Haxe plugin.", version: "1.2.3", author: "Acme", license: "GPL-2.0-or-later"});',
        )
        source_path.write_text(custom_source)
        runtime.command(first, "build")
        custom_php = root_php.read_text()
        for expected in (
            "Plugin Name: Typed Dispatch",
            "Description: A concise Haxe plugin.",
            "Version: 1.2.3",
            "Author: Acme",
        ):
            assert expected in custom_php

        good_source = source_path.read_text()
        good_outputs = output_snapshot(first)
        invalid_sources = (
            source.replace("WordPress.plugin();", 'WordPress.plugin({unknown: "no"});'),
            source.replace("WordPress.plugin();", 'WordPress.plugin({version: "latest"});'),
            source.replace(
                "\tpublic static final definition = WordPress.plugin();",
                "\tpublic static final definition = WordPress.plugin();\n"
                "\tpublic static final duplicate = WordPress.plugin();",
            ),
        )
        for invalid_source in invalid_sources:
            source_path.write_text(invalid_source)
            documents = runtime.command(first, "build", expected=6)
            diagnostic = next(value for value in documents if value.get("event") == "diagnostic")
            assert diagnostic["payload"]["diagnostic"]["code"] == "WPHX2002"
            assert output_snapshot(first) == good_outputs
            runtime.no_write += 1
        source_path.write_text(good_source)

        dev_cycle(runtime, first, source_path, good_source, root_php)

        shadow = first / "src/wordpresshx/WordPress.hx"
        shadow.parent.mkdir()
        shadow.write_text("package wordpresshx; final class WordPress {}\n")
        expect_command_no_write(runtime, first, "build", 6, "WPHX3302")
        shadow.unlink()
        shadow.parent.rmdir()

        owned_before = root_php.read_bytes()
        root_php.write_bytes(owned_before + b"// modified\n")
        modified_snapshot = snapshot(first)
        documents = runtime.command(first, "build", expected=7)
        diagnostic = next(value for value in documents if value.get("event") == "diagnostic")
        assert diagnostic["payload"]["diagnostic"]["code"] == "WPHX1200"
        assert snapshot(first) == modified_snapshot
        runtime.no_write += 1
        root_php.write_bytes(owned_before)

        php_matrix(plugin, "Typed\\News\\Bootstrap")
        wordpress_result = subprocess.run(
            [
                "bash",
                str(ROOT / "scripts/scaffold/test-plugin-wordpress.sh"),
                str(plugin),
                "typed-news",
                "Typed\\News\\Bootstrap",
                "Typed Dispatch",
                "1.2.3",
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        wordpress_summary = json.loads(wordpress_result.stdout.splitlines()[-1])
        assert wordpress_summary["outcome"] == "passed"
        strict_haxe_scan()
        return {
            "schema": "wordpress-hx.sdk045-plugin-scaffold-summary.v1",
            "positiveCases": runtime.positive,
            "negativeCases": runtime.negative,
            "noWriteAssertions": runtime.no_write,
            "generatedFileCount": len(first_plan["files"]),
            "nativePhpFiles": len(expected_files),
            "freshTreeReplay": "byte-identical",
            "buildReplay": "no-op-byte-identical",
            "devReplay": "three-atomic-generations",
            "phpMatrix": ["7.4", "8.4"],
            "wordpress": "7.0-mariadb-clean-activation",
            "strictHaxe": "passed",
            "outcome": "passed",
        }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-plugin-production.py <compiled-runtime-root>")
    print(json.dumps(run(Path(sys.argv[1])), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
