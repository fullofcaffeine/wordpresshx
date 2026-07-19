#!/usr/bin/env python3
"""Exercise the production Haxe/Genes development loop on exact Node."""

from __future__ import annotations

import hashlib
import json
import os
import queue
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[2]
PROJECT_FIXTURE = ROOT / "fixtures" / "project-cli" / "project"
EVENT_SCHEMA = json.loads((ROOT / "schemas" / "cli-event.schema.json").read_text())
NODE_IMAGE = (
    "docker.io/library/node@sha256:"
    "b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
)
OWNED_PATHS = (
    Path("build/nextjs/_GeneratedFiles.json"),
    Path("build/nextjs/.wphx/effective-inputs.json"),
    Path("dist/wordpress-hx-build.json"),
    Path("dist/wordpress-hx.zip"),
)


def canonical(value: object, *, newline: bool = False) -> bytes:
    result = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode()
    return result + (b"\n" if newline else b"")


def owned_bytes(project: Path) -> dict[str, bytes]:
    return {path.as_posix(): (project / path).read_bytes() for path in OWNED_PATHS}


def make_tools(evidence: Path) -> Path:
    tools = evidence / "tools"
    tools.mkdir()
    haxe = tools / "haxe"
    haxe.write_text(
        """#!/usr/bin/env node
'use strict';
const fs = require('fs');
const net = require('net');
const path = require('path');
const args = process.argv.slice(2);
const trace = process.env.WPHX_FAKE_TRACE;
function record(event, detail = {}) {
  if (trace) fs.appendFileSync(trace, JSON.stringify({event, pid: process.pid, ...detail}) + '\\n');
}
function compile(hxml) {
  if (hxml !== '.wphx/bootstrap/project.hxml') process.exit(64);
  const sourcePath = path.join(process.cwd(), 'src/acme/site/Site.hx');
  const initial = fs.readFileSync(sourcePath, 'utf8');
  const delay = initial.includes('SLOW_HAXE') ? 500 : 10;
  setTimeout(() => {
    const source = fs.readFileSync(sourcePath, 'utf8');
    if (source.includes('BROKEN_HAXE')) {
      process.stderr.write('src/acme/site/Site.hx:1: characters 1-6 : synthetic typing failure\\n');
      process.exit(1);
    }
    const hxmlSource = fs.readFileSync(hxml, 'utf8').split(/\\r?\\n/);
    if (!hxmlSource.includes('--no-output')) process.exit(65);
    record('compile', {hxml});
    process.exit(0);
  }, delay);
}
if (args.length === 1 && args[0] === '--version') {
  process.stdout.write('4.3.7\\n');
} else if (args.length === 2 && args[0] === '--wait') {
  const port = Number(args[1]);
  const server = net.createServer(socket => socket.end());
  let stopped = false;
  const stop = signal => {
    if (stopped) return;
    stopped = true;
    server.close(() => {
      record('stopped', {port, signal});
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 1000).unref();
  };
  process.on('SIGTERM', () => stop('SIGTERM'));
  process.on('SIGINT', () => stop('SIGINT'));
  server.listen(port, '127.0.0.1', () => record('started', {port}));
  server.on('error', () => process.exit(69));
} else if (args.length >= 3 && args[0] === '--connect') {
  const port = Number(args[1]);
  const socket = net.createConnection({host: '127.0.0.1', port});
  const timeout = setTimeout(() => process.exit(69), 1000);
  socket.once('error', () => process.exit(69));
  socket.once('connect', () => {
    clearTimeout(timeout);
    socket.destroy();
    if (args[2] === '-version') {
      process.stdout.write('4.3.7\\n');
      process.exit(0);
    }
    compile(args[2]);
  });
} else if (args.length === 1) {
  compile(args[0]);
} else {
  process.exit(64);
}
"""
    )
    haxe.chmod(0o755)
    lix = tools / "lix"
    lix.write_text(
        "#!/bin/sh\nset -eu\n[ \"${1:-}\" = --version ]\nprintf '%s\\n' 15.12.2\n"
    )
    lix.chmod(0o755)
    return tools


class DevSession:
    def __init__(self, runtime: Path, evidence: Path, project: Path, tools: Path) -> None:
        self.name = "wordpresshx-sdk044-" + uuid.uuid4().hex[:12]
        self.events: list[dict[str, object]] = []
        self.stdout_lines: list[str] = []
        self.stderr_lines: list[str] = []
        self.updates: queue.Queue[None] = queue.Queue()
        command = [
            "docker",
            "run",
            "--rm",
            "--name",
            self.name,
            "--network",
            "none",
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "--mount",
            f"type=bind,src={runtime.resolve()},dst=/runtime,readonly",
            "--mount",
            f"type=bind,src={evidence.resolve()},dst=/evidence",
            "--env",
            "PATH=/evidence/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "--env",
            "WPHX_FAKE_TRACE=/evidence/compiler-events.jsonl",
            "-w",
            "/evidence/project",
            NODE_IMAGE,
            "node",
            "/runtime/index.js",
            "dev",
            "--services=none",
            "--project",
            "/evidence/project",
            "--json",
        ]
        self.process = subprocess.Popen(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=1,
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
            assert line.encode() == canonical(value, newline=True)
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
                    f"stdout:{''.join(self.stdout_lines)}\nstderr:{''.join(self.stderr_lines)}"
                )
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(
                    f"timed out waiting for {event}\n"
                    f"stdout:{''.join(self.stdout_lines)}\nstderr:{''.join(self.stderr_lines)}"
                )
            try:
                self.updates.get(timeout=min(remaining, 0.25))
            except queue.Empty:
                pass

    def stop(self) -> None:
        result = subprocess.run(
            ["docker", "kill", "--signal=SIGINT", self.name],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0 and self.process.poll() is None:
            raise AssertionError(f"could not signal development container: {result.stderr}")
        status = self.process.wait(timeout=15)
        self.stdout_thread.join(timeout=2)
        self.stderr_thread.join(timeout=2)
        assert status == 130, f"development container exited {status}"

    def run_node(self, source: str) -> None:
        result = subprocess.run(
            [
                "docker",
                "exec",
                "--workdir",
                "/evidence/project",
                self.name,
                "node",
                "-e",
                source,
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(
                f"in-container edit failed {result.returncode}\n"
                f"stdout:{result.stdout}\nstderr:{result.stderr}"
            )

    def force_cleanup(self) -> None:
        if self.process.poll() is None:
            subprocess.run(
                ["docker", "kill", self.name],
                text=True,
                capture_output=True,
                check=False,
            )
            self.process.wait(timeout=10)


def validate_event_stream(events: list[dict[str, object]]) -> None:
    assert events
    assert [event["sequence"] for event in events] == list(range(1, len(events) + 1))
    assert len({event["runId"] for event in events}) == 1
    allowed_payload = set(EVENT_SCHEMA["$defs"]["payload"]["properties"])
    for event in events:
        assert event["command"] == "dev"
        assert event["event"] in EVENT_SCHEMA["properties"]["event"]["enum"]
        assert event["stage"] in EVENT_SCHEMA["properties"]["stage"]["enum"]
        assert event["status"] in EVENT_SCHEMA["properties"]["status"]["enum"]
        assert set(event["payload"]) <= allowed_payload
        assert isinstance(event["elapsedMs"], int) and event["elapsedMs"] >= 0
    assert events[0]["event"] == "command-started"
    assert events[-1]["event"] == "command-completed"
    assert events[-1]["payload"]["exitCode"] == 130


def run_bounded(runtime: Path, evidence: Path, project_name: str) -> None:
    command = [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "--user",
        f"{os.getuid()}:{os.getgid()}",
        "--mount",
        f"type=bind,src={runtime.resolve()},dst=/runtime,readonly",
        "--mount",
        f"type=bind,src={evidence.resolve()},dst=/evidence",
        "--env",
        "PATH=/evidence/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "-w",
        f"/evidence/{project_name}",
        NODE_IMAGE,
        "node",
        "/runtime/index.js",
        "build",
        "--project",
        f"/evidence/{project_name}",
        "--json",
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise AssertionError(
            f"clean oracle build exited {result.returncode}\n{result.stdout}\n{result.stderr}"
        )


def run(runtime: Path) -> dict[str, object]:
    temporary_parent = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    with tempfile.TemporaryDirectory(
        prefix="wordpresshx-sdk044-production-", dir=temporary_parent
    ) as raw:
        evidence = Path(raw)
        project = evidence / "project"
        shutil.copytree(PROJECT_FIXTURE, project)
        tools = make_tools(evidence)
        session = DevSession(runtime, evidence, project, tools)
        try:
            server_index, server_event = session.wait_for("compiler-server-ready")
            initial_index, initial_event = session.wait_for(
                "build-published",
                predicate=lambda value: value["payload"].get("generation") == 1,
            )
            watch_index, _ = session.wait_for("watch-ready")
            assert server_index < initial_index < watch_index
            initial_owned = owned_bytes(project)
            initial_manifest = initial_event["payload"]["manifestDigest"]
            assert (project / ".wphx/runtime/compiler-server.json").is_file()

            burst_start = len(session.events)
            source = project / "src/acme/site/Site.hx"
            session.run_node(
                "const fs=require('fs');"
                "fs.appendFileSync('src/acme/site/Site.hx','\\n// burst source\\n');"
                "setTimeout(()=>fs.appendFileSync('assets/brand.txt','burst asset\\n'),20);"
            )
            _, generation_two = session.wait_for(
                "build-published",
                after=burst_start,
                predicate=lambda value: value["payload"].get("generation") == 2,
            )
            burst_events = session.events[burst_start:]
            detected = next(
                value for value in burst_events if value["event"] == "change-detected"
            )
            changed_paths = detected["payload"]["changedPaths"]
            assert changed_paths == sorted(set(changed_paths))
            assert {
                "assets/brand.txt",
                "src/acme/site/Site.hx",
            }.issubset(set(changed_paths)), json.dumps(burst_events, sort_keys=True)
            assert detected["payload"]["coalescedChanges"] == len(changed_paths)
            assert (
                sum(value["event"] == "rebuild-scheduled" for value in burst_events) == 1
            )
            assert generation_two["payload"]["manifestDigest"] != initial_manifest
            generation_two_owned = owned_bytes(project)

            failed_start = len(session.events)
            source.write_text("// BROKEN_HAXE\n" + source.read_text())
            _, diagnostic = session.wait_for(
                "diagnostic",
                after=failed_start,
                predicate=lambda value: value["payload"]
                .get("diagnostic", {})
                .get("code")
                == "WPHX2002",
            )
            _, retained = session.wait_for("build-retained", after=failed_start)
            assert retained["payload"]["retainedManifestDigest"] == generation_two["payload"][
                "manifestDigest"
            ]
            assert owned_bytes(project) == generation_two_owned
            failed_owned = owned_bytes(project)
            assert failed_owned != initial_owned
            assert diagnostic["status"] == "failed"

            repair_start = len(session.events)
            source.write_text(source.read_text().replace("// BROKEN_HAXE\n", "", 1))
            nested = project / "src/acme/site/components"
            nested.mkdir()
            added = nested / "Added.hxx"
            added.write_text("package acme.site.components;\nclass Added {}\n")
            _, generation_three = session.wait_for(
                "build-published",
                after=repair_start,
                predicate=lambda value: value["payload"].get("generation") == 3,
            )
            assert generation_three["payload"]["manifestDigest"] != retained["payload"][
                "retainedManifestDigest"
            ]

            rename_start = len(session.events)
            renamed = nested / "Renamed.hxx"
            added.rename(renamed)
            session.wait_for(
                "build-published",
                after=rename_start,
                predicate=lambda value: value["payload"].get("generation") == 4,
            )
            delete_start = len(session.events)
            renamed.unlink()
            session.wait_for(
                "build-published",
                after=delete_start,
                predicate=lambda value: value["payload"].get("generation") == 5,
            )
            session.wait_for(
                "stage-skipped",
                after=delete_start,
                predicate=lambda value: value["stage"] == "watching"
                and value["payload"].get("reason")
                == "published generation has no admitted reload adapter",
            )
            time.sleep(0.3)

            lock_bytes = (project / ".wphx/project.lock.json").read_bytes()
            lock_failure_start = len(session.events)
            (project / ".wphx/project.lock.json").write_bytes(lock_bytes + b" ")
            session.wait_for(
                "change-detected",
                after=lock_failure_start,
                predicate=lambda value: ".wphx/project.lock.json"
                in value["payload"]["changedPaths"],
            )
            session.wait_for("diagnostic", after=lock_failure_start)
            lock_retained = owned_bytes(project)
            time.sleep(0.2)
            lock_repair_start = len(session.events)
            (project / ".wphx/project.lock.json").write_bytes(lock_bytes)
            session.wait_for(
                "change-detected",
                after=lock_repair_start,
                predicate=lambda value: ".wphx/project.lock.json"
                in value["payload"]["changedPaths"],
            )
            session.wait_for(
                "stage-skipped",
                after=lock_repair_start,
                predicate=lambda value: value["stage"] == "watching",
            )
            assert owned_bytes(project) == lock_retained

            restart_start = len(session.events)
            hxml = project / ".wphx/bootstrap/project.hxml"
            hxml.write_text(hxml.read_text() + "# compiler identity change\n")
            _, replacement_server = session.wait_for(
                "compiler-server-ready", after=restart_start
            )
            assert replacement_server["payload"]["serverCompatibilityDigest"] != server_event[
                "payload"
            ]["serverCompatibilityDigest"]
            session.wait_for(
                "build-published",
                after=restart_start,
                predicate=lambda value: value["payload"].get("generation") == 6,
            )

            stability_start = len(session.events)
            source.write_text(source.read_text() + "\n// SLOW_HAXE first snapshot\n")
            session.wait_for("rebuild-scheduled", after=stability_start)
            time.sleep(0.12)
            source.write_text(
                source.read_text().replace("first snapshot", "second snapshot")
            )
            session.wait_for(
                "diagnostic",
                after=stability_start,
                predicate=lambda value: value["payload"]
                .get("diagnostic", {})
                .get("code")
                == "WPHX2200",
            )
            stability_retained_index, _ = session.wait_for(
                "build-retained", after=stability_start
            )
            assert not any(
                value["event"] == "build-published"
                for value in session.events[stability_start : stability_retained_index + 1]
            )
            _, final_generation = session.wait_for(
                "build-published",
                after=stability_retained_index + 1,
                predicate=lambda value: value["payload"].get("generation") == 7,
                timeout=30,
            )
            final_owned = owned_bytes(project)
            assert final_generation["payload"]["manifestDigest"] == json.loads(
                final_owned["build/nextjs/_GeneratedFiles.json"]
            )["manifestDigest"]

            session.stop()
            session.wait_for("command-completed", timeout=2)
            validate_event_stream(session.events)
            assert not (project / ".wphx/runtime/compiler-server.json").exists()
            assert all("/evidence/" not in line for line in session.stdout_lines)
            assert all(str(evidence) not in line for line in session.stdout_lines)
            assert not session.stderr_lines

            compiler_trace = [
                json.loads(line)
                for line in (evidence / "compiler-events.jsonl").read_text().splitlines()
            ]
            starts = [value for value in compiler_trace if value["event"] == "started"]
            stops = [value for value in compiler_trace if value["event"] == "stopped"]
            assert len(starts) >= 2
            assert len(stops) == len(starts)
            assert {value["port"] for value in starts} == {
                value["port"] for value in stops
            }

            clean = evidence / "clean"
            shutil.copytree(project, clean)
            for generated_root in (clean / "build", clean / "dist"):
                if generated_root.exists():
                    shutil.rmtree(generated_root)
            runtime_root = clean / ".wphx/runtime"
            if runtime_root.exists():
                shutil.rmtree(runtime_root)
            run_bounded(runtime, evidence, "clean")
            assert owned_bytes(clean) == final_owned

            return {
                "schema": "wordpress-hx.sdk044-production-summary.v1",
                "compilerStarts": len(starts),
                "publishedGenerations": 7,
                "finalManifestDigest": final_generation["payload"]["manifestDigest"],
                "finalFingerprint": json.loads(
                    final_owned["build/nextjs/.wphx/effective-inputs.json"]
                )["fingerprint"],
                "nodeImage": NODE_IMAGE,
                "outcome": "passed",
            }
        finally:
            session.force_cleanup()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-production.py <compiled-runtime-root>")
    summary = run(Path(sys.argv[1]))
    print(json.dumps(summary, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
