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
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
PHP_IMAGES = (
    "docker.io/library/php@sha256:620a6b9f4d4feef2210026172570465e9d0c1de79766418d3affd09190a7fda5",
    "docker.io/library/php@sha256:6d4c0213d8e0ef5bfdbd1fb355ae33a36c203b0ea91c9996c15db11def0f1367",
)
FORBIDDEN_HAXE = ("Dynamic", "Any", "cast", "Reflect", "untyped")
PHP_QUALITY_POLICY_FILES = (
    "composer.json",
    "composer.lock",
    "phpcs-compat-private.xml",
    "phpcs-compat.xml",
    "phpcs-public.xml",
    "phpstan-private.neon",
    "phpstan-public.neon",
    "run.php",
    "toolchain.json",
)
PHP_QUALITY_TOOLS = (
    {"id": "composer", "version": "2.10.2"},
    {"id": "php-stubs/wordpress-stubs", "version": "7.0.0"},
    {"id": "phpcompatibility/phpcompatibility-wp", "version": "2.1.8"},
    {"id": "phpstan/phpstan", "version": "2.2.5"},
    {"id": "squizlabs/php_codesniffer", "version": "3.13.5"},
    {"id": "wp-coding-standards/wpcs", "version": "3.4.0"},
)
PHP_QUALITY_COMPOSER_LOCK_SHA256 = (
    "8185991c7986ea06c1b54710b21b6e63d342abc14b1212fa3a5483c1afbd2649"
)
WORDPRESS_STUBS_SHA256 = (
    "1fa69deee70f8a1be7e3a0498327ca16e36ee2b5c243a5b2ab1926bec456fd44"
)


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


def assert_public_plugin_permissions(plugin: Path) -> None:
    for path in (plugin, *sorted(plugin.rglob("*"))):
        metadata = path.lstat()
        assert not stat.S_ISLNK(metadata.st_mode), path
        expected = 0o755 if stat.S_ISDIR(metadata.st_mode) else 0o644
        assert stat.S_ISDIR(metadata.st_mode) or stat.S_ISREG(metadata.st_mode), path
        assert stat.S_IMODE(metadata.st_mode) == expected, path


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
    def __init__(self, runtime: Runtime, project: Path, *, services: bool = False) -> None:
        self.events: list[dict[str, object]] = []
        self.stdout_lines: list[str] = []
        self.stderr_lines: list[str] = []
        self.updates: queue.Queue[None] = queue.Queue()
        arguments = ["node", str(runtime.entry), "dev"]
        if not services:
            arguments.append("--services=none")
        arguments.extend(["--project", str(project), "--json"])
        self.process = subprocess.Popen(
            arguments,
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

    def stop(self, *, timeout: float = 30.0) -> None:
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGINT)
        status = self.process.wait(timeout=timeout)
        self.stdout_thread.join(timeout=2)
        self.stderr_thread.join(timeout=2)
        assert status == 130, (
            f"development process exited {status}\n"
            f"stdout:{''.join(self.stdout_lines)}\n"
            f"stderr:{''.join(self.stderr_lines)}"
        )


class ReloadProbe:
    def __init__(self, events_url: str, origin: str) -> None:
        self.events: queue.Queue[str] = queue.Queue()
        self.failure: queue.Queue[BaseException] = queue.Queue()
        self.connected = threading.Event()
        self.stopping = threading.Event()
        self.response = None
        self.thread = threading.Thread(
            target=self._run, args=(events_url, origin), daemon=True
        )
        self.thread.start()

    def _run(self, events_url: str, origin: str) -> None:
        try:
            request = urllib.request.Request(events_url, headers={"Origin": origin})
            with urllib.request.urlopen(request, timeout=300) as response:
                self.response = response
                assert response.status == 200
                assert response.headers["Content-Type"].startswith(
                    "text/event-stream"
                )
                self.connected.set()
                event_name = ""
                for raw_line in response:
                    line = raw_line.decode("utf-8").rstrip("\r\n")
                    if line.startswith("event: "):
                        event_name = line.removeprefix("event: ")
                    elif line == "" and event_name:
                        self.events.put(event_name)
                        event_name = ""
        except BaseException as error:
            if not self.stopping.is_set():
                self.failure.put(error)
                self.connected.set()

    def wait_connected(self, timeout: float = 10.0) -> None:
        assert self.connected.wait(timeout), "reload event stream did not connect"
        self.raise_failure()

    def assert_quiet(self, timeout: float) -> None:
        self.raise_failure()
        try:
            event = self.events.get(timeout=timeout)
        except queue.Empty:
            return
        raise AssertionError(f"unexpected reload event after failed build: {event}")

    def wait_reload(self, timeout: float = 20.0) -> None:
        self.raise_failure()
        try:
            event = self.events.get(timeout=timeout)
        except queue.Empty as error:
            self.raise_failure()
            raise AssertionError("timed out waiting for post-commit reload") from error
        assert event == "wordpresshx-reload"

    def raise_failure(self) -> None:
        try:
            error = self.failure.get_nowait()
        except queue.Empty:
            return
        raise AssertionError("reload event stream failed") from error

    def begin_stop(self) -> None:
        self.stopping.set()

    def stop(self) -> None:
        self.stopping.set()
        self.thread.join(timeout=5)
        assert not self.thread.is_alive(), "reload event stream survived server shutdown"


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


def php_quality_policy_sha256(runtime: Runtime) -> str:
    tool_root = (runtime.entry.parent / "php-quality").resolve(strict=True)
    framed = bytearray()
    for relative in PHP_QUALITY_POLICY_FILES:
        content_sha256 = hashlib.sha256((tool_root / relative).read_bytes()).hexdigest()
        framed.extend(relative.encode())
        framed.append(0)
        framed.extend(content_sha256.encode())
        framed.append(0)
    return hashlib.sha256(framed).hexdigest()


def assert_php_quality_event(documents: list[dict[str, object]]) -> None:
    completed = [
        value
        for value in documents
        if value.get("event") == "stage-completed"
        and value.get("stage") == "format-and-static-check"
    ]
    assert len(completed) == 1
    event = completed[0]
    assert event["status"] == "passed"
    payload = event["payload"]
    assert isinstance(payload, dict)
    assert payload["reason"] == (
        "pinned lint, formatter, WPCS, compatibility, PHPStan, symbol, and "
        "autoload gates passed"
    )
    for name in ("policySha256", "reportSha256"):
        assert re.fullmatch(r"[0-9a-f]{64}", payload[name])


def assert_php_quality_report(
    runtime: Runtime,
    project: Path,
    plugin: Path,
    *,
    public_php_files: int,
    private_php_files: int,
    classmap_entries: int,
) -> dict[str, object]:
    report_path = project / "build/wordpress/.wphx/php-quality.json"
    report_bytes = report_path.read_bytes()
    report = json.loads(report_bytes)
    assert canonical(report) == report_bytes
    assert report["schema"] == "wordpress-hx.php-quality-report.v1"
    assert report["status"] == "passed"
    assert report["tools"] == list(PHP_QUALITY_TOOLS)

    expected_policy_sha256 = php_quality_policy_sha256(runtime)
    assert report["policy"] == {
        "composerLockSha256": PHP_QUALITY_COMPOSER_LOCK_SHA256,
        "id": "wp70-release-generated-php-v1",
        "sha256": expected_policy_sha256,
        "wordpressStubsSha256": WORDPRESS_STUBS_SHA256,
    }
    expected_private_level = 0 if private_php_files else -1
    expected_autoload = (
        "authoritative-private-classmap"
        if private_php_files
        else "native-require-closure"
    )
    assert report["checks"] == {
        "autoload": expected_autoload,
        "classmapEntries": classmap_entries,
        "duplicateSymbols": "none",
        "formatChangedFiles": 0,
        "phpFileCount": public_php_files + private_php_files,
        "phpStanPrivateLevel": expected_private_level,
        "phpStanPublicLevel": 6,
        "privatePhpFileCount": private_php_files,
        "publicPhpFileCount": public_php_files,
        "syntaxFloor": "7.4.33",
        "wordpressCodingStandards": "passed",
    }

    plugin_files = sorted(path for path in plugin.rglob("*") if path.is_file())
    report_files = report["files"]
    assert isinstance(report_files, list)
    report_by_path = {value["path"]: value for value in report_files}
    assert len(report_by_path) == len(report_files)
    assert set(report_by_path) == {
        path.relative_to(plugin).as_posix() for path in plugin_files
    }
    for path in plugin_files:
        value = report_by_path[path.relative_to(plugin).as_posix()]
        assert set(value) == {"lane", "path", "role", "sha256", "sizeBytes"}
        assert value["sha256"] == hashlib.sha256(path.read_bytes()).hexdigest()
        assert value["sizeBytes"] == path.stat().st_size

    manifest_path = project / "build/wordpress/_GeneratedFiles.json"
    manifest = json.loads(manifest_path.read_text())
    validators = {
        value["validatorId"]: value for value in manifest["validators"]
    }
    quality_validator = validators["wphx.plugin-php-quality"]
    assert quality_validator == {
        "configSha256": PHP_QUALITY_COMPOSER_LOCK_SHA256,
        "outcome": "passed",
        "scope": "complete-staged-tree",
        "tool": "WordPressHx pinned generated-PHP quality gate",
        "toolSha256": expected_policy_sha256,
        "validatorId": "wphx.plugin-php-quality",
        "version": "sdk-026-v1",
    }
    manifest_files = {value["path"]: value for value in manifest["files"]}
    quality_relative = "build/wordpress/.wphx/php-quality.json"
    quality_artifact = manifest_files[quality_relative]
    assert quality_artifact["kind"] == "build.php-quality-report.json"
    assert quality_artifact["contentSha256"] == hashlib.sha256(report_bytes).hexdigest()
    assert quality_artifact["sizeBytes"] == len(report_bytes)
    assert quality_artifact["validatorIds"] == ["wphx.plugin-php-quality"]
    plugin_prefix = f"build/wordpress/{plugin.name}/"
    plugin_artifacts = [
        value for path, value in manifest_files.items() if path.startswith(plugin_prefix)
    ]
    assert len(plugin_artifacts) == len(plugin_files)
    assert all(
        "wphx.plugin-php-quality" in value["validatorIds"]
        for value in plugin_artifacts
    )
    return report


def reject_tampered_php_quality_policy(runtime: Runtime, project: Path) -> None:
    runtime_bundle = runtime.entry.parent / "php-quality"
    assert runtime_bundle.is_symlink()
    original_target = os.readlink(runtime_bundle)
    original_root = runtime_bundle.resolve(strict=True)
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-quality-policy-tamper-", dir=temporary_parent
    ) as raw:
        tampered_root = Path(raw) / "php-quality"
        tampered_root.mkdir()
        for relative in PHP_QUALITY_POLICY_FILES:
            shutil.copy2(original_root / relative, tampered_root / relative)
        os.symlink(
            original_root / "vendor",
            tampered_root / "vendor",
            target_is_directory=True,
        )
        policy_path = tampered_root / "phpstan-public.neon"
        policy_path.write_text(policy_path.read_text() + "# rejected test mutation\n")
        runtime_bundle.unlink()
        os.symlink(tampered_root, runtime_bundle, target_is_directory=True)
        try:
            expect_command_no_write(runtime, project, "build", 6, "WPHX3400")
        finally:
            runtime_bundle.unlink(missing_ok=True)
            os.symlink(original_target, runtime_bundle, target_is_directory=True)
    assert runtime_bundle.resolve(strict=True) == original_root


def reject_invalid_private_classmap(plugin: Path) -> None:
    before = snapshot(plugin)
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-quality-classmap-", dir=temporary_parent
    ) as raw:
        stage = Path(raw) / plugin.name
        shutil.copytree(plugin, stage)
        classmap_path = stage / "private/wordpresshx/classmap.php"
        source = classmap_path.read_text()
        changed, replacements = re.subn(
            r"(\n\t')([^']+)('\s+=>)",
            lambda match: match.group(1)
            + match.group(2)
            + "\\\\Rejected"
            + match.group(3),
            source,
            count=1,
        )
        assert replacements == 1 and changed != source
        classmap_path.write_text(changed)
        result = subprocess.run(
            ["php", str(ROOT / "tooling/php-quality/run.php"), str(stage)],
            text=True,
            capture_output=True,
            check=False,
        )
        assert result.returncode == 6
        assert result.stdout == ""
        assert "private PHP classmap key does not match its declaration" in result.stderr
        assert str(stage) not in result.stderr
        assert str(ROOT) not in result.stderr
    assert snapshot(plugin) == before


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


def private_site_source(source: str, marker: str) -> str:
    result = source.replace(
        "WordPress.plugin();",
        "WordPress.plugin({titleFilter: filterTitle});\n\n"
        "\tpublic static function filterTitle(title:String, postId:Int):String {\n"
        f'\t\treturn postId > 0 ? title + ":{marker}" : title;\n'
        "\t}",
    )
    assert result != source
    return result


def expected_private_prefix(slug: str) -> tuple[str, str]:
    identity = b"wordpress-hx.private-runtime.v1\0" + slug.encode() + b"\0plugin"
    digest = hashlib.sha256(identity).hexdigest()
    return "wphx_internal.p" + digest[:24], digest


def private_php_matrix(
    first_plugin: Path,
    second_plugin: Path,
    first_bridge: str,
    second_bridge: str,
    first_private: str,
    second_private: str,
    expected_title: str,
) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    for image in PHP_IMAGES:
        subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                f"type=bind,src={first_plugin},dst=/first,readonly",
                "--mount",
                f"type=bind,src={second_plugin},dst=/second,readonly",
                image,
                "sh",
                "-euc",
                "find /first /second -type f -name '*.php' -print0 | sort -z | xargs -0 -n 1 php -l >/dev/null",
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        probe = subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                f"type=bind,src={ROOT},dst=/repo,readonly",
                "--mount",
                f"type=bind,src={first_plugin},dst=/first,readonly",
                "--mount",
                f"type=bind,src={second_plugin},dst=/second,readonly",
                image,
                "php",
                "/repo/scripts/scaffold/plugin-private-caller.php",
                f"/first/{first_plugin.name}.php",
                f"/second/{second_plugin.name}.php",
                first_bridge,
                second_bridge,
                first_private,
                second_private,
                expected_title,
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        payload = json.loads(probe.stdout)
        signature = {"parameters": ["string", "int"], "return": "string"}
        assert payload == {
            "expectedMatched": True,
            "filterCount": 2,
            "filteredTitle": expected_title,
            "firstPrivateLoaded": True,
            "firstSignature": signature,
            "outputBytes": 0,
            "prefixesDistinct": True,
            "secondPrivateLoaded": True,
            "secondSignature": signature,
        }
        conflict = subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                f"type=bind,src={ROOT},dst=/repo,readonly",
                "--mount",
                f"type=bind,src={first_plugin},dst=/first,readonly",
                image,
                "php",
                "/repo/scripts/scaffold/plugin-private-conflict.php",
                f"/first/{first_plugin.name}.php",
                first_bridge,
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        assert json.loads(conflict.stdout) == {
            "bridgeLoaded": False,
            "filterCount": 0,
            "outputBytes": 0,
        }
        assert "WPHX5201" in conflict.stderr
        samples = subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                "--network",
                "none",
                "--mount",
                f"type=bind,src={ROOT},dst=/repo,readonly",
                "--mount",
                f"type=bind,src={first_plugin},dst=/first,readonly",
                image,
                "sh",
                "-euc",
                'for sample in $(seq 1 25); do php -d opcache.enable_cli=0 /repo/scripts/scaffold/plugin-private-cold-boot.php "$1" "$2" "$3"; done',
                "private-cold-boot",
                f"/first/{first_plugin.name}.php",
                first_bridge,
                "seed:news",
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        observations = [json.loads(line) for line in samples.stdout.splitlines()]
        assert len(observations) == 25
        assert all(
            value["expectedMatched"] is True
            and value["filterCount"] == 1
            and value["result"] == "seed:news"
            and isinstance(value["elapsedNanoseconds"], int)
            and value["elapsedNanoseconds"] > 0
            for value in observations
        )
        median = int(statistics.median(value["elapsedNanoseconds"] for value in observations))
        assert median < 20_000_000
        results.append(
            {
                "image": image,
                "coldBootP50Nanoseconds": median,
                "sampleCount": 25,
                "coexistence": "passed",
                "polyfillMismatch": "WPHX5201-rejected-before-private-boot",
            }
        )
    return results


def exercise_private_runtime(
    runtime: Runtime,
    first: Path,
    second: Path,
    source: str,
    third_parent: Path,
) -> dict[str, object]:
    first_source = first / "src/typed/news/Site.hx"
    second_source = second / "src/typed/news/Site.hx"
    private_site = private_site_source(source, "news")
    first_source.write_text(private_site)
    second_source.write_text(private_site)
    runtime.command(first, "build")
    runtime.command(second, "build")
    assert output_snapshot(first) == output_snapshot(second)
    assert_php_quality_report(
        runtime,
        first,
        first / "build/wordpress/typed-news",
        public_php_files=5,
        private_php_files=16,
        classmap_entries=14,
    )
    first_replay = output_snapshot(first)
    replay = runtime.command(first, "build")
    ownership = next(
        value
        for value in replay
        if value.get("event") == "stage-completed"
        and value.get("stage") == "ownership-publish"
    )
    assert ownership["payload"]["reason"] == "no-op"
    assert output_snapshot(first) == first_replay

    third_plan = runtime.scaffold(
        ["new", "plugin", "typed-pages", "--project", str(third_parent)]
    )
    third = third_parent / "typed-pages"
    third_source = third / "src/typed/pages/Site.hx"
    third_source.write_text(private_site_source(third_source.read_text(), "pages"))
    runtime.command(third, "build")
    assert_php_quality_report(
        runtime,
        third,
        third / "build/wordpress/typed-pages",
        public_php_files=5,
        private_php_files=16,
        classmap_entries=14,
    )

    first_plugin = first / "build/wordpress/typed-news"
    third_plugin = third / "build/wordpress/typed-pages"
    first_emission = json.loads(
        (first / "build/wordpress/.wphx/plugin-emission.json").read_text()
    )
    third_emission = json.loads(
        (third / "build/wordpress/.wphx/plugin-emission.json").read_text()
    )
    first_runtime = first_emission["privateRuntime"]
    third_runtime = third_emission["privateRuntime"]
    assert first_emission["schema"] == "wordpress-hx.plugin-emission.v2"
    assert first_emission["stockHaxePhpFiles"] == 15
    assert first_runtime["classmapEntries"] == 14
    assert first_runtime["privatePhpFileCount"] == 16
    assert first_runtime["privatePhpBytes"] < 163_840
    assert first_runtime["stockFrontPackaged"] is False
    for slug, value in (("typed-news", first_runtime), ("typed-pages", third_runtime)):
        prefix, digest = expected_private_prefix(slug)
        assert value["prefix"] == prefix
        assert value["derivationSha256"] == digest
    assert first_runtime["prefix"] != third_runtime["prefix"]

    expected_private_files = 22
    for project, plugin, emission in (
        (first, first_plugin, first_emission),
        (third, third_plugin, third_emission),
    ):
        files = sorted(path for path in plugin.rglob("*") if path.is_file())
        assert len(files) == expected_private_files
        assert len(emission["files"]) == expected_private_files
        assert not any(
            path.name in {"stock-front.php", "composer.json", "composer.lock"}
            or "vendor" in path.parts
            or path.name == "Entry.php"
            for path in files
        )
        root_bytes = str(project).encode()
        assert all(root_bytes not in path.read_bytes() for path in files)
        manifest = json.loads(
            (plugin / "private/wordpresshx/runtime-manifest.v1.json").read_text()
        )
        assert manifest["schema"] == "wordpress-hx.private-runtime-manifest.v1"
        assert manifest["composer"]["status"] == "absent-no-runtime-dependencies"
        assert manifest["autoload"]["processIncludePathMutation"] is False
        assert manifest["sbom"]["publicationBlocked"] is True
        assert {component["id"] for component in manifest["sbom"]["components"]} == {
            "haxe-4.3.7-stdlib",
            "project-private-haxe",
            "repository-original-work",
        }
        assert sum(
            path.stat().st_size for path in files if path.suffix == ".php"
        ) < 409_600
        bridge = (plugin / "includes/PrivateBridge.php").read_text()
        signature_line = next(line for line in bridge.splitlines() if "function filterTitle" in line)
        assert "wphx_internal" not in signature_line
        assert "public static function filterTitle(string $title, int $postId): string" in signature_line
        loader = (plugin / "includes/autoload.php").read_text()
        assert "WPHX5202 WordPressHx private runtime rejected its class map." in loader
        assert "WPHX5202 WordPressHx private runtime could not register its class map." in loader

    reject_invalid_private_classmap(first_plugin)

    first_bridge = "Typed\\News\\PrivateBridge"
    third_bridge = "Typed\\Pages\\PrivateBridge"
    expected_title = "seed:news:pages"
    matrix = private_php_matrix(
        first_plugin,
        third_plugin,
        first_bridge,
        third_bridge,
        first_runtime["privateClass"],
        third_runtime["privateClass"],
        expected_title,
    )
    wordpress = subprocess.run(
        [
            "bash",
            str(ROOT / "scripts/scaffold/test-plugin-private-wordpress.sh"),
            str(first_plugin),
            "typed-news",
            "Typed\\News\\Bootstrap",
            first_bridge,
            first_runtime["privateClass"],
            str(third_plugin),
            "typed-pages",
            "Typed\\Pages\\Bootstrap",
            third_bridge,
            third_runtime["privateClass"],
            expected_title,
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    wordpress_summary = json.loads(wordpress.stdout.splitlines()[-1])
    assert wordpress_summary["outcome"] == "passed"
    assert third_plan["kind"] == "plugin"
    return {
        "schema": "wordpress-hx.sdk024-private-runtime-result.v1",
        "classmapEntries": first_runtime["classmapEntries"],
        "deterministicSameIdentity": "byte-identical",
        "privatePhpBytes": first_runtime["privatePhpBytes"],
        "privatePhpFiles": first_runtime["privatePhpFileCount"],
        "phpMatrix": matrix,
        "prefixesDistinct": True,
        "stockFrontPackaged": False,
        "wordpress": wordpress_summary,
        "outcome": "passed",
    }


def strict_haxe_scan() -> None:
    paths = [
        ROOT / "packages/cli/project-api",
        ROOT / "packages/cli/src/wordpresshx/cli/closedjson/JsonDocument.hx",
        ROOT / "packages/cli/src/wordpresshx/cli/generatedoutput",
        ROOT / "packages/cli/src/wordpresshx/cli/scaffold",
        ROOT / "packages/cli/src/wordpresshx/cli/project/CompilerRunner.hx",
        ROOT / "packages/cli/src/wordpresshx/cli/project/ProjectBuild.hx",
    ]
    paths.extend(sorted((ROOT / "packages/cli/src/wordpresshx/cli/project").glob("Plugin*.hx")))
    paths.extend(
        ROOT / "packages/cli/src/wordpresshx/cli/project/development" / name
        for name in (
            "DevelopmentPlan.hx",
            "DevelopmentPlanReader.hx",
            "DevelopmentPlugin.hx",
            "DevelopmentProject.hx",
            "ReadinessProbe.hx",
            "WordPressBootstrapAdapter.hx",
            "WordPressProvider.hx",
            "WordPressReloadAdapter.hx",
        )
    )
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
        assert not [
            value for value in session.events if value["event"] == "service-starting"
        ]
    finally:
        session.stop()
    runtime.positive += 1


def reject_unowned_plugin_entry(
    runtime: Runtime, project: Path, plugin: Path
) -> None:
    unowned = plugin / "unowned-development-input.txt"
    unowned.write_text("must not enter the inferred provider\n")
    session = DevSession(runtime, project, services=True)
    try:
        session.wait_for(
            "diagnostic",
            predicate=lambda value: value["payload"]
            .get("diagnostic", {})
            .get("code")
            == "WPHX2332",
            timeout=60,
        )
        session.wait_for("watch-ready", timeout=30)
        assert not [
            value for value in session.events if value["event"] == "service-starting"
        ]
    finally:
        session.stop(timeout=30)
        unowned.unlink()


def docker_resource_ids(project_name: str, kind: str) -> list[str]:
    if kind == "container":
        arguments = ["docker", "ps", "--all", "--quiet"]
    elif kind in ("network", "volume"):
        arguments = ["docker", kind, "ls", "--quiet"]
    else:
        raise AssertionError(f"unknown Docker resource kind: {kind}")
    result = subprocess.run(
        [
            *arguments,
            "--filter",
            f"label=com.docker.compose.project={project_name}",
        ],
        text=True,
        capture_output=True,
        check=True,
    )
    return sorted(line for line in result.stdout.splitlines() if line)


def container_volume_names(container_ids: list[str]) -> list[str]:
    result: set[str] = set()
    for container_id in container_ids:
        inspected = subprocess.run(
            ["docker", "inspect", container_id],
            text=True,
            capture_output=True,
            check=True,
        )
        records = json.loads(inspected.stdout)
        assert len(records) == 1
        for mount in records[0]["Mounts"]:
            if mount["Type"] == "volume":
                result.add(mount["Name"])
    return sorted(result)


def assert_docker_cleanup(project_name: str, volume_names: list[str]) -> None:
    for kind in ("container", "network", "volume"):
        assert docker_resource_ids(project_name, kind) == [], (
            f"owned Docker {kind} resources survived shutdown"
        )
    for volume_name in volume_names:
        inspected = subprocess.run(
            ["docker", "volume", "inspect", volume_name],
            text=True,
            capture_output=True,
            check=False,
        )
        assert inspected.returncode != 0, (
            f"owned Docker volume survived shutdown: {volume_name}"
        )


def real_wordpress_dev_cycle(
    runtime: Runtime,
    project: Path,
    source_path: Path,
    stable_source: str,
    root_php: Path,
    plugin: Path,
) -> None:
    secret = "wordpresshx-sdk044-private-database-secret"
    previous_secret = runtime.environment.get("WP_DB_PASSWORD")
    runtime.environment["WP_DB_PASSWORD"] = secret
    session = DevSession(runtime, project, services=True)
    reload_probe: ReloadProbe | None = None
    compose_project = ""
    volume_names: list[str] = []
    try:
        initial_index, _ = session.wait_for(
            "build-published",
            predicate=lambda value: value["payload"].get("generation") == 1,
            timeout=60,
        )
        starting_index, starting = session.wait_for(
            "service-starting",
            after=initial_index + 1,
            predicate=lambda value: value["payload"].get("serviceId")
            == "wordpress",
            timeout=60,
        )
        assert starting["payload"]["serviceKind"] == "wordpress"
        assert starting["payload"]["readiness"] == "http"
        assert starting["payload"]["timeoutMs"] == 240000
        ready_index, ready = session.wait_for(
            "service-ready",
            after=starting_index + 1,
            predicate=lambda value: value["payload"].get("serviceId")
            == "wordpress",
            timeout=300,
        )
        session.wait_for("watch-ready", after=ready_index + 1, timeout=30)
        ready_url = ready["payload"]["url"]
        assert isinstance(ready_url, str)
        assert ready["payload"]["reload"] == "full-page"
        assert ready["payload"]["readiness"] == "http"

        request = urllib.request.Request(ready_url, headers={"Cache-Control": "no-cache"})
        with urllib.request.urlopen(request, timeout=20) as response:
            assert response.status == 200
            assert response.headers["X-WordPressHx-Plugin"] == (
                "typed-news/typed-news.php"
            ), dict(response.headers.items())
            page = response.read().decode("utf-8")
        assert re.search(r"<title>typed-news(?:\s|&|<)", page) is not None
        reload_match = re.search(
            r'<script src="([^"]+)" data-wordpresshx-reload-events="([^"]+)" async></script>',
            page,
        )
        assert reload_match is not None
        reload_client_url, reload_events_url = reload_match.groups()
        assert reload_client_url.startswith("http://127.0.0.1:")
        assert reload_events_url.startswith("http://127.0.0.1:")
        assert "/wordpresshx/reload/" in reload_client_url
        assert "/wordpresshx/reload/" in reload_events_url

        runtime_directory = project / ".wphx/runtime"
        compose_files = list(runtime_directory.glob("wphx-*.compose.json"))
        plugin_directories = list(runtime_directory.glob("wphx-*.mu-plugins"))
        bootstrap_files = list(runtime_directory.glob("wphx-*.bootstrap.php"))
        assert len(compose_files) == 1
        assert len(plugin_directories) == 1
        assert len(bootstrap_files) == 1
        compose_path = compose_files[0]
        private_directory = plugin_directories[0]
        reload_path = private_directory / "wordpresshx-dev-reload.php"
        bootstrap_path = bootstrap_files[0]
        assert stat.S_IMODE(compose_path.stat().st_mode) == 0o600
        assert stat.S_IMODE(private_directory.stat().st_mode) == 0o755
        assert stat.S_IMODE(reload_path.stat().st_mode) == 0o644
        assert stat.S_IMODE(bootstrap_path.stat().st_mode) == 0o600
        assert reload_path.read_text().rstrip().endswith("})();")
        assert "add_action('send_headers'" in reload_path.read_text()
        compose_bytes = compose_path.read_bytes()
        compose = json.loads(compose_bytes)
        assert compose_bytes == canonical(compose)
        assert secret.encode() not in compose_bytes
        assert b"/wordpresshx/reload/" not in compose_bytes
        assert set(compose) == {"networks", "services", "volumes"}
        assert set(compose["services"]) == {"bootstrap", "database", "wordpress"}
        assert compose["networks"]["default"]["labels"][
            "dev.wordpresshx.owned"
        ] == "true"
        assert compose["volumes"]["wordpress-data"]["labels"][
            "dev.wordpresshx.owned"
        ] == "true"
        wordpress = compose["services"]["wordpress"]
        bootstrap = compose["services"]["bootstrap"]
        assert wordpress["ports"][0].startswith("127.0.0.1:")
        assert bootstrap["entrypoint"] == ["php"]
        assert bootstrap["command"] == ["/opt/wordpresshx/dev-bootstrap.php"]
        assert bootstrap["depends_on"]["wordpress"]["condition"] == (
            "service_healthy"
        )
        assert wordpress["healthcheck"]["test"][:3] == ["CMD", "php", "-r"]
        wordpress_health_source = wordpress["healthcheck"]["test"][3]
        for required_path in (
            "/var/www/html/wp-load.php",
            "/var/www/html/wp-config.php",
            "/var/www/html/wp-settings.php",
            "/var/www/html/wp-includes/version.php",
            "/var/www/html/wp-admin/includes/upgrade.php",
            "/var/www/html/wp-admin/includes/plugin.php",
            "/var/www/html/wp-content/mu-plugins/wordpresshx-dev-reload.php",
            "/var/www/html/wp-content/plugins/typed-news/typed-news.php",
        ):
            assert required_path in wordpress_health_source
        assert wordpress["environment"]["WORDPRESS_DB_PASSWORD"] == (
            "${WPHX_INTERNAL_WORDPRESS_DB_PASSWORD:?required}"
        )
        assert bootstrap["environment"][
            "WPHX_INTERNAL_WORDPRESS_ADMIN_PASSWORD"
        ] == "${WPHX_INTERNAL_WORDPRESS_ADMIN_PASSWORD:?required}"
        wordpress_mounts = {value["target"]: value for value in wordpress["volumes"]}
        bootstrap_mounts = {value["target"]: value for value in bootstrap["volumes"]}
        plugin_target = "/var/www/html/wp-content/plugins/typed-news"
        assert wordpress_mounts[plugin_target] == {
            "read_only": True,
            "source": str(plugin.resolve()),
            "target": plugin_target,
            "type": "bind",
        }
        assert bootstrap_mounts[plugin_target] == wordpress_mounts[plugin_target]
        reload_target = "/var/www/html/wp-content/mu-plugins"
        assert wordpress_mounts[reload_target] == {
            "read_only": True,
            "source": str(private_directory.resolve()),
            "target": reload_target,
            "type": "bind",
        }
        assert bootstrap_mounts[reload_target] == wordpress_mounts[reload_target]
        assert bootstrap_mounts["/opt/wordpresshx/dev-bootstrap.php"][
            "read_only"
        ] is True
        for private_php in (reload_path, bootstrap_path):
            lint = subprocess.run(
                ["php", "-l", str(private_php)],
                text=True,
                capture_output=True,
                check=False,
            )
            assert lint.returncode == 0, lint.stderr

        compose_project = compose_path.name.removesuffix(".compose.json")
        container_ids = docker_resource_ids(compose_project, "container")
        assert len(container_ids) == 3
        assert len(docker_resource_ids(compose_project, "network")) == 1
        assert len(docker_resource_ids(compose_project, "volume")) >= 1
        volume_names = container_volume_names(container_ids)
        assert volume_names

        origin = ready_url.rstrip("/")
        reload_probe = ReloadProbe(reload_events_url, origin)
        reload_probe.wait_connected()
        initial_plugin_bytes = root_php.read_bytes()
        failed_source = stable_source.replace(
            'version: "1.2.3"', 'version: "1.2.3", unknown: "no"'
        )
        assert failed_source != stable_source
        failed_start = len(session.events)
        source_path.write_text(failed_source)
        session.wait_for("change-detected", after=failed_start, timeout=30)
        session.wait_for(
            "diagnostic",
            after=failed_start,
            predicate=lambda value: value["payload"]
            .get("diagnostic", {})
            .get("code")
            == "WPHX2002",
            timeout=60,
        )
        retained_index, _ = session.wait_for(
            "build-retained", after=failed_start, timeout=30
        )
        assert root_php.read_bytes() == initial_plugin_bytes
        reload_probe.assert_quiet(1.0)

        changed_source = stable_source.replace(
            'version: "1.2.3"', 'version: "1.2.4"'
        )
        assert changed_source != stable_source
        source_path.write_text(changed_source)
        change_index, _ = session.wait_for(
            "change-detected", after=retained_index + 1, timeout=30
        )
        published_index, _ = session.wait_for(
            "build-published",
            after=change_index + 1,
            predicate=lambda value: value["payload"].get("generation") == 2,
            timeout=60,
        )
        _, reload_event = session.wait_for(
            "reload-requested",
            after=published_index + 1,
            predicate=lambda value: value["payload"].get("serviceId")
            == "wordpress",
            timeout=30,
        )
        assert reload_event["payload"]["reason"] == (
            "complete ownership transaction published"
        )
        reload_probe.wait_reload()
        assert "Version: 1.2.4" in root_php.read_text()
        assert docker_resource_ids(compose_project, "container") == container_ids
        assert [
            value
            for value in session.events
            if value["event"] == "service-starting"
            and value["payload"].get("serviceId") == "wordpress"
        ] == [starting]
        assert not [
            value
            for value in session.events
            if value["event"] == "service-stopped"
            and value["payload"].get("serviceId") == "wordpress"
        ]

        serialized_events = "".join(session.stdout_lines).encode()
        assert secret.encode() not in serialized_events
        assert str(compose_path).encode() not in serialized_events
        for root_name in ("build", "dist"):
            for value in snapshot(project / root_name).values():
                if value[0] == "file":
                    assert secret.encode() not in value[2]
                    assert b"/wordpresshx/reload/" not in value[2]
    finally:
        if reload_probe is not None:
            reload_probe.begin_stop()
        try:
            session.stop(timeout=60)
        finally:
            if reload_probe is not None:
                reload_probe.stop()
            source_path.write_text(stable_source)
            if previous_secret is None:
                runtime.environment.pop("WP_DB_PASSWORD", None)
            else:
                runtime.environment["WP_DB_PASSWORD"] = previous_secret

    assert compose_project
    assert_docker_cleanup(compose_project, volume_names)
    runtime_directory = project / ".wphx/runtime"
    assert not runtime_directory.exists() or list(runtime_directory.iterdir()) == []
    positive_before_restore = runtime.positive
    runtime.command(project, "build")
    runtime.positive = positive_before_restore
    assert "Version: 1.2.3" in root_php.read_text()


def run(runtime_root: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(prefix="wordpresshx-sdk045-plugin-", dir=temporary_parent) as raw:
        evidence = Path(raw)
        environment = exact_environment()
        runtime = Runtime(runtime_root, environment)
        first_parent = evidence / "first"
        second_parent = evidence / "second"
        third_parent = evidence / "third"
        dry_parent = evidence / "dry"
        first_parent.mkdir()
        second_parent.mkdir()
        third_parent.mkdir()
        dry_parent.mkdir()

        dry_before = snapshot(dry_parent)
        dry_plan = runtime.scaffold(
            ["new", "plugin", "typed-news", "--project", str(dry_parent), "--dry-run"]
        )
        assert dry_plan["kind"] == "plugin"
        assert dry_plan["operation"] == "new-plugin"
        assert dry_plan["limitations"] == [
            "general-plugin-apis-dependency-gated",
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
        assert_php_quality_event(check)
        assert snapshot(first) == before_check
        runtime.no_write += 1

        before_dry_build = snapshot(first)
        dry_build = runtime.command(first, "build", "--dry-run")
        assert any(value.get("event") == "dry-run-planned" for value in dry_build)
        assert_php_quality_event(dry_build)
        assert snapshot(first) == before_dry_build
        runtime.no_write += 1

        first_build = runtime.command(first, "build")
        second_build = runtime.command(second, "build")
        assert any(value.get("event") == "build-published" for value in first_build)
        assert any(value.get("event") == "build-published" for value in second_build)
        assert_php_quality_event(first_build)
        assert_php_quality_event(second_build)
        assert output_snapshot(first) == output_snapshot(second)

        plugin = first / "build/wordpress/typed-news"
        root_php = plugin / "typed-news.php"
        expected_files = {
            "includes/Bootstrap.php",
            "includes/autoload.php",
            "typed-news.php",
        }
        assert {path.relative_to(plugin).as_posix() for path in plugin.rglob("*.php")} == expected_files
        assert_public_plugin_permissions(plugin)
        assert_php_quality_report(
            runtime,
            first,
            plugin,
            public_php_files=3,
            private_php_files=0,
            classmap_entries=0,
        )
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

        plugin.chmod(0o700)
        (plugin / "includes").chmod(0o700)
        root_php.chmod(0o600)
        mode_repair = runtime.command(first, "build")
        mode_repair_ownership = next(
            value
            for value in mode_repair
            if value.get("event") == "stage-completed"
            and value.get("stage") == "ownership-publish"
        )
        assert mode_repair_ownership["payload"]["reason"] == "no-op"
        assert_public_plugin_permissions(plugin)

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
                "WordPress.plugin();",
                "WordPress.plugin({titleFilter: (title, postId) -> title});",
            ),
            source.replace(
                "\tpublic static final definition = WordPress.plugin();",
                "\tpublic static final definition = WordPress.plugin({titleFilter: invalidFilter});\n\n"
                "\tstatic function invalidFilter(title:String, postId:Int):String {\n"
                "\t\treturn title;\n"
                "\t}",
            ),
            source.replace(
                "\tpublic static final definition = WordPress.plugin();",
                "\tpublic static final definition = WordPress.plugin({titleFilter: invalidFilter});\n\n"
                "\tpublic static function invalidFilter<T>(title:String, postId:Int):String {\n"
                "\t\treturn title;\n"
                "\t}",
            ),
            source.replace(
                "\tpublic static final definition = WordPress.plugin();",
                "\tpublic static final definition = WordPress.plugin({titleFilter: invalidFilter});\n\n"
                "\tpublic static function invalidFilter(title:String):String {\n"
                "\t\treturn title;\n"
                "\t}",
            ),
            source.replace(
                "\tpublic static final definition = WordPress.plugin();",
                "\tpublic static final definition = WordPress.plugin({titleFilter: invalidFilter});\n\n"
                "\t@:native(\"renamed\")\n"
                "\tpublic static function invalidFilter(title:String, postId:Int):String {\n"
                "\t\treturn title;\n"
                "\t}",
            ),
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

        reject_tampered_php_quality_policy(runtime, first)

        dev_cycle(runtime, first, source_path, good_source, root_php)
        assert_public_plugin_permissions(plugin)
        reject_unowned_plugin_entry(runtime, first, plugin)
        real_wordpress_dev_cycle(
            runtime,
            first,
            source_path,
            good_source,
            root_php,
            plugin,
        )

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
        private_runtime = exercise_private_runtime(
            runtime,
            first,
            second,
            source,
            third_parent,
        )
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
            "devWordPress": "inferred-install-activate-reload-cleanup",
            "phpMatrix": ["7.4", "8.4"],
            "privateRuntime": private_runtime,
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
