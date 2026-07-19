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
PLAYWRIGHT_IMAGE = (
    "mcr.microsoft.com/playwright@sha256:"
    "6446946a1d9fd62d9ae501312a2d76a43ee688542b21622056a372959b65d63d"
)
BROWSER_READY_TIMEOUT_SECONDS = 120
BROWSER_STOP_TIMEOUT_SECONDS = 10
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
const crypto = require('crypto');
const fs = require('fs');
const net = require('net');
const path = require('path');
const args = process.argv.slice(2);
const trace = process.env.WPHX_FAKE_TRACE;
function record(event, detail = {}) {
  if (trace) fs.appendFileSync(trace, JSON.stringify({event, pid: process.pid, ...detail}) + '\\n');
}
function canonical(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
}
function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}
function serviceNode(sourceDigest, serviceId, dependsOn, readiness) {
  const tracePath = '.wphx/runtime/service-trace.jsonl';
  return {
    dependsOn: dependsOn.map(id => 'service/' + id),
    id: 'service/' + serviceId,
    kind: 'development.service',
    payload: {
      command: {
        arguments: ['src/dev-service.mjs', serviceId, '{port}', tracePath],
        component: 'runtime.node',
        executable: 'node'
      },
      dependsOn,
      environment: [],
      port: {preferred: 44100, strict: false},
      readiness,
      reload: 'none',
      restart: {backoffMs: 50, maxAttempts: 1},
      serviceId,
      serviceKind: 'external',
      url: {path: '/', scheme: 'http'},
      workingDirectory: '.'
    },
    profileCapabilities: [],
    projections: [{artifactKind: 'development.service', emitterId: 'wordpresshx.dev', projectionId: 'dev/service/' + serviceId}],
    relatedSources: [],
    schemaId: 'wordpress-hx.semantic-node.development.service.v1',
    source: {
      end: {column: 1, line: 1, offset: 1},
      path: 'src/acme/site/Site.hx',
      sourceSha256: sourceDigest,
      start: {column: 0, line: 1, offset: 0},
      symbol: 'acme.site.Site.' + serviceId
    }
  };
}
function wordpressNode(sourceDigest) {
  const node = serviceNode(
    sourceDigest,
    'wordpress',
    [],
    {intervalMs: 50, kind: 'http', path: '/wp-json/', text: '', timeoutMs: 3000}
  );
  node.payload.command = null;
  node.payload.environment = ['WP_DB_PASSWORD'];
  node.payload.port = {preferred: 44200, strict: false};
  node.payload.reload = 'full-page';
  node.payload.serviceKind = 'wordpress';
  node.source.symbol = 'acme.site.Site.wordpress';
  return node;
}
function writeServicePlan(mode, source) {
  if (!mode) return;
  const lockBytes = fs.readFileSync('.wphx/project.lock.json');
  const lock = JSON.parse(lockBytes);
  const sourceDigest = sha256(Buffer.from(source));
  const nodes = mode === 'timeout'
    ? [serviceNode(sourceDigest, 'timeout', [], {intervalMs: 50, kind: 'tcp', path: '/', text: '', timeoutMs: 300})]
    : mode === 'wordpress'
      ? [wordpressNode(sourceDigest)]
      : [
        serviceNode(sourceDigest, 'api', [], {intervalMs: 50, kind: 'http', path: '/health', text: '', timeoutMs: 3000}),
        serviceNode(sourceDigest, 'frontend', ['api'], {intervalMs: 50, kind: 'log', path: '/', text: 'FRONTEND_READY', timeoutMs: 3000})
      ];
  const plan = {
    canonicalization: 'wordpress-hx.canonical-json.v1',
    generator: {
      collectorId: 'wordpress-hx.build.semantic-plan',
      collectorSourceSha256: '1'.repeat(64),
      collectorVersion: '1.0.0',
      sdkVersion: '0.0.0',
      toolchainSha256: sha256(lockBytes)
    },
    nodeSchemas: [{
      authority: 'core',
      consumerEmitters: ['wordpresshx.dev'],
      kind: 'development.service',
      schemaId: 'wordpress-hx.semantic-node.development.service.v1',
      schemaSha256: '0e344463d1316909a97a08a2381f9ee6c7cd5a57fd158952b0ac8cab9b911d57',
      version: 1
    }],
    nodes,
    planDigestAlgorithm: 'sha256-canonical-json-without-planDigest-v1',
    profile: {
      catalogRevision: lock.profile.catalogRevision,
      catalogSha256: lock.profile.catalogSha256,
      profileId: lock.profile.id
    },
    project: {projectId: lock.project.id, projectVersion: '0.1.0', sourceTreeSha256: sourceDigest},
    schema: 'wordpress-hx.semantic-plan.v1'
  };
  plan.planDigest = sha256(Buffer.from(canonical(plan)));
  fs.writeFileSync('.wphx/runtime/semantic-plan.next.json', canonical(plan) + '\\n');
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
    writeServicePlan(process.env.WPHX_FAKE_SERVICE_PLAN, source);
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
    docker = tools / "docker"
    docker.write_text(
        """#!/usr/bin/env node
'use strict';
const fs = require('fs');
const http = require('http');
const path = require('path');
const args = process.argv.slice(2);
let trace;
function record(event, detail = {}) {
  if (trace) fs.appendFileSync(trace, JSON.stringify({event, pid: process.pid, ...detail}) + '\\n');
}
if (args[0] !== 'compose') process.exit(64);
if (args[1] === 'version') {
  process.stdout.write('Docker Compose version v2.38.2\\n');
  process.exit(0);
}
const fileIndex = args.indexOf('--file');
if (fileIndex < 0 || fileIndex + 1 >= args.length) process.exit(64);
const composePath = args[fileIndex + 1];
trace = path.join(path.dirname(composePath), 'docker-events.jsonl');
const command = args.includes('up') ? 'up' : args.includes('down') ? 'down' : '';
if (command === 'down') {
  record('down', {composePath});
  process.exit(0);
}
if (command !== 'up') process.exit(64);
const config = JSON.parse(fs.readFileSync(composePath, 'utf8'));
const database = config.services.database;
const wordpress = config.services.wordpress;
if (database.image !== 'docker.io/library/mariadb@sha256:49117dcc565cf51aa57ac5fca59ab31213402ff0eae6ffc13c46a37b938f7e4b') process.exit(65);
if (wordpress.image !== 'docker.io/library/wordpress@sha256:9a37e25aa7cb8b01a7a6c9ff0af7b9c0aca1ff78b489dd3756f90142a58d3161') process.exit(66);
if (wordpress.environment.WORDPRESS_DB_PASSWORD !== '${WPHX_INTERNAL_WORDPRESS_DB_PASSWORD:?required}') process.exit(67);
if (wordpress.environment.WPHX_DEV_RELOAD_CLIENT !== '${WPHX_INTERNAL_WORDPRESS_RELOAD_CLIENT:?required}') process.exit(67);
if (wordpress.environment.WPHX_DEV_RELOAD_EVENTS !== '${WPHX_INTERNAL_WORDPRESS_RELOAD_EVENTS:?required}') process.exit(67);
const mapping = wordpress.ports[0];
const match = /^127\\.0\\.0\\.1:([0-9]+):80$/.exec(mapping);
if (!match) process.exit(68);
const port = Number(match[1]);
const origin = `http://127.0.0.1:${port}`;
const reloadClient = process.env.WPHX_INTERNAL_WORDPRESS_RELOAD_CLIENT;
const reloadEvents = process.env.WPHX_INTERNAL_WORDPRESS_RELOAD_EVENTS;
if (typeof reloadClient !== 'string' || typeof reloadEvents !== 'string') process.exit(69);
const clientUrl = new URL(reloadClient);
const eventsUrl = new URL(reloadEvents);
const clientMatch = /^\\/wordpresshx\\/reload\\/([0-9a-f]{64})\\/client\\.js$/.exec(clientUrl.pathname);
const eventsMatch = /^\\/wordpresshx\\/reload\\/([0-9a-f]{64})\\/events$/.exec(eventsUrl.pathname);
if (clientUrl.protocol !== 'http:' || clientUrl.hostname !== '127.0.0.1') process.exit(69);
if (clientUrl.origin !== eventsUrl.origin || !clientMatch || !eventsMatch || clientMatch[1] !== eventsMatch[1]) process.exit(69);
if (!Array.isArray(wordpress.volumes) || wordpress.volumes.length !== 1) process.exit(69);
const reloadVolume = wordpress.volumes[0];
if (reloadVolume.type !== 'bind' || reloadVolume.read_only !== true) process.exit(69);
if (reloadVolume.target !== '/var/www/html/wp-content/mu-plugins/wordpresshx-dev-reload.php') process.exit(69);
const reloadPlugin = fs.readFileSync(reloadVolume.source, 'utf8');
if (!reloadPlugin.includes("add_action('wp_footer'") || !reloadPlugin.includes('WPHX_DEV_RELOAD_EVENTS')) process.exit(69);
if (reloadPlugin.includes(clientMatch[1])) process.exit(69);
const pageTrace = path.join(path.dirname(composePath), 'browser-page-loads.jsonl');
record('up', {
  composePath,
  declaredPresent: process.env.WP_DB_PASSWORD !== undefined,
  internalPresent: typeof process.env.WPHX_INTERNAL_WORDPRESS_DB_PASSWORD === 'string',
  port,
  reloadClientPresent: true,
  secretPresent: process.env.WPHX_UNDECLARED_SECRET !== undefined
});
function requestStatus(target, headers = {}) {
  return new Promise((resolve, reject) => {
    const request = http.get(target, {headers}, response => {
      resolve(response.statusCode);
      response.destroy();
    });
    request.once('error', reject);
  });
}
async function probeReloadSecurity() {
  const invalid = new URL(reloadClient);
  invalid.pathname = '/wordpresshx/reload/invalid/client.js';
  const results = {
    allowedClient: await requestStatus(reloadClient, {referer: `${origin}/`}),
    allowedEvents: await requestStatus(reloadEvents, {origin}),
    badReferer: await requestStatus(reloadClient, {referer: 'http://127.0.0.1:1/'}),
    invalidCapability: await requestStatus(invalid),
    wrongOrigin: await requestStatus(reloadEvents, {origin: 'http://127.0.0.1:1'})
  };
  record('reload-security', results);
  if (JSON.stringify(results) !== JSON.stringify({allowedClient: 200, allowedEvents: 200, badReferer: 403, invalidCapability: 404, wrongOrigin: 403})) process.exit(69);
}
const server = http.createServer((request, response) => {
  if (request.url === '/wp-json/') {
    response.statusCode = 200;
    response.end();
    return;
  }
  if (request.url === '/') {
    fs.appendFileSync(pageTrace, JSON.stringify({event: 'page-load'}) + '\\n');
    response.writeHead(200, {'cache-control': 'no-store', 'content-type': 'text/html; charset=utf-8'});
    response.end(`<!doctype html><html><head><meta charset="utf-8"><title>WordPressHx reload fixture</title><script>const key='wordpresshx-page-loads';const loads=Number(sessionStorage.getItem(key)||'0')+1;sessionStorage.setItem(key,String(loads));document.documentElement.dataset.wordpresshxPageLoads=String(loads);</script></head><body><main>WordPressHx reload fixture</main><script src="${reloadClient}" data-wordpresshx-reload-events="${reloadEvents}" async></script></body></html>`);
    return;
  }
  response.statusCode = 404;
  response.end();
});
let stopped = false;
function stop(signal) {
  if (stopped) return;
  stopped = true;
  server.close(() => {
    record('stopped', {signal});
    process.exit(0);
  });
  setTimeout(() => process.exit(0), 1000).unref();
}
process.on('SIGTERM', () => stop('SIGTERM'));
process.on('SIGINT', () => stop('SIGINT'));
server.listen(port, '127.0.0.1', () => {
  probeReloadSecurity().catch(() => process.exit(69));
});
"""
    )
    docker.chmod(0o755)
    return tools


def install_service_fixture(project: Path) -> None:
    (project / "src/dev-service.mjs").write_text(
        """import fs from 'node:fs';
import http from 'node:http';

const [serviceId, portText, tracePath] = process.argv.slice(2);
const port = Number(portText);
function record(event) {
  fs.appendFileSync(tracePath, JSON.stringify({
    event,
    pid: process.pid,
    port,
    secretPresent: process.env.WPHX_UNDECLARED_SECRET !== undefined,
    serviceId
  }) + '\\n');
}
let server;
let timer;
function stop(signal) {
  if (timer) clearInterval(timer);
  if (server) {
    server.close(() => {
      record('stopped');
      process.exit(0);
    });
    setTimeout(() => process.exit(0), 1000).unref();
  } else {
    record('stopped');
    process.exit(0);
  }
}
process.on('SIGTERM', () => stop('SIGTERM'));
process.on('SIGINT', () => stop('SIGINT'));
if (serviceId === 'timeout') {
  record('started');
  timer = setInterval(() => {}, 1000);
} else {
  server = http.createServer((request, response) => {
    response.statusCode = request.url === '/health' ? 204 : 200;
    response.end();
  });
  server.listen(port, '127.0.0.1', () => {
    record('started');
    if (serviceId === 'frontend') process.stdout.write('FRONTEND_READY\\n');
  });
}
"""
    )


class DevSession:
    def __init__(
        self,
        runtime: Path,
        evidence: Path,
        project: Path,
        tools: Path,
        *,
        service_mode: str | None = None,
    ) -> None:
        self.name = "wordpresshx-sdk044-" + uuid.uuid4().hex[:12]
        self.events: list[dict[str, object]] = []
        self.stdout_lines: list[str] = []
        self.stderr_lines: list[str] = []
        self.updates: queue.Queue[None] = queue.Queue()
        cli_arguments = ["node", "/runtime/index.js", "dev"]
        if service_mode is None:
            cli_arguments.append("--services=none")
        cli_arguments.extend(["--project", "/evidence/project", "--json"])
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
            "--env",
            "WPHX_UNDECLARED_SECRET=must-not-reach-services",
        ]
        if service_mode is not None:
            command.extend(["--env", f"WPHX_FAKE_SERVICE_PLAN={service_mode}"])
        if service_mode == "wordpress":
            command.extend(["--env", "WP_DB_PASSWORD=declared-test-only"])
        command.extend(
            [
                "-w",
                "/evidence/project",
                NODE_IMAGE,
                *cli_arguments,
            ]
        )
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

    def signal_pid(self, pid: int) -> None:
        result = subprocess.run(
            [
                "docker",
                "exec",
                self.name,
                "node",
                "-e",
                "process.kill(Number(process.argv[1]), 'SIGKILL')",
                str(pid),
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(
                f"could not kill owned service {pid}: {result.stderr}"
            )

    def wait_exit(self, expected: int, timeout: float = 20.0) -> None:
        status = self.process.wait(timeout=timeout)
        self.stdout_thread.join(timeout=2)
        self.stderr_thread.join(timeout=2)
        assert status == expected, f"development container exited {status}"

    def assert_container_removed(self, timeout: float = 5.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = subprocess.run(
                ["docker", "inspect", self.name],
                text=True,
                capture_output=True,
                check=False,
            )
            if result.returncode != 0:
                return
            time.sleep(0.05)
        raise AssertionError(f"development container {self.name} was not removed")

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


def validate_event_stream(
    events: list[dict[str, object]], *, expected_exit: int = 130
) -> None:
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
    assert events[-1]["payload"]["exitCode"] == expected_exit


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


def service_trace(project: Path) -> list[dict[str, object]]:
    path = project / ".wphx/runtime/service-trace.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines()]


def docker_trace(project: Path) -> list[dict[str, object]]:
    path = project / ".wphx/runtime/docker-events.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines()]


def browser_page_loads(project: Path) -> int:
    path = project / ".wphx/runtime/browser-page-loads.jsonl"
    if not path.exists():
        return 0
    return len(path.read_text().splitlines())


def wait_for_path(path: Path, process: subprocess.Popen[str], timeout: float) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        if process.poll() is not None:
            stdout, stderr = process.communicate()
            raise AssertionError(
                f"browser exited {process.returncode} before {path.name}\n"
                f"stdout:{stdout}\nstderr:{stderr}"
            )
        time.sleep(0.05)
    raise AssertionError(f"timed out waiting for browser marker {path}")


def stop_browser_process(process: subprocess.Popen[str], container_name: str) -> None:
    try:
        subprocess.run(
            ["docker", "kill", container_name],
            text=True,
            capture_output=True,
            check=False,
            timeout=BROWSER_STOP_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        pass
    if process.poll() is not None:
        return
    try:
        process.terminate()
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=BROWSER_STOP_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        try:
            process.kill()
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=BROWSER_STOP_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            pass


def wait_for_docker_event(project: Path, event: str, timeout: float = 5.0) -> dict[str, object]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for value in docker_trace(project):
            if value["event"] == event:
                return value
        time.sleep(0.05)
    raise AssertionError(f"timed out waiting for controlled Docker event {event}")


def service_ids(events: list[dict[str, object]], event_name: str) -> list[object]:
    return [
        event["payload"]["serviceId"]
        for event in events
        if event["event"] == event_name
    ]


def prepare_service_case(
    parent: Path, name: str
) -> tuple[Path, Path, Path]:
    evidence = parent / name
    evidence.mkdir()
    project = evidence / "project"
    shutil.copytree(PROJECT_FIXTURE, project)
    install_service_fixture(project)
    return evidence, project, make_tools(evidence)


def validate_wordpress_compose(path: Path) -> None:
    environment = os.environ.copy()
    environment.update(
        {
            "WP_DB_PASSWORD": "compose-validation-only",
            "WPHX_INTERNAL_WORDPRESS_DB_PASSWORD": "compose-validation-only",
            "WPHX_INTERNAL_WORDPRESS_DB_ROOT_PASSWORD": "compose-validation-root-only",
            "WPHX_INTERNAL_WORDPRESS_RELOAD_CLIENT": "http://127.0.0.1:45000/wordpresshx/reload/"
            + "a" * 64
            + "/client.js",
            "WPHX_INTERNAL_WORDPRESS_RELOAD_EVENTS": "http://127.0.0.1:45000/wordpresshx/reload/"
            + "a" * 64
            + "/events",
        }
    )
    result = subprocess.run(
        ["docker", "compose", "--file", str(path), "config", "--quiet"],
        text=True,
        capture_output=True,
        check=False,
        env=environment,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"real Docker Compose rejected generated provider config: {result.stderr}"
        )
    assert not result.stdout


def run_healthy_service_case(runtime: Path, parent: Path) -> dict[str, object]:
    evidence, project, tools = prepare_service_case(parent, "services-healthy")
    session = DevSession(
        runtime, evidence, project, tools, service_mode="healthy"
    )
    try:
        api_index, api = session.wait_for(
            "service-ready",
            predicate=lambda value: value["payload"].get("serviceId") == "api",
        )
        _, frontend = session.wait_for(
            "service-ready",
            after=api_index + 1,
            predicate=lambda value: value["payload"].get("serviceId") == "frontend",
        )
        session.wait_for("watch-ready")
        assert service_ids(session.events, "service-starting") == ["api", "frontend"]
        assert service_ids(session.events, "service-ready") == ["api", "frontend"]
        api_port = int(
            str(api["payload"]["url"])
            .removeprefix("http://127.0.0.1:")
            .removesuffix("/")
        )
        frontend_port = int(
            str(frontend["payload"]["url"])
            .removeprefix("http://127.0.0.1:")
            .removesuffix("/")
        )
        assert 44100 <= api_port <= 44200
        assert 44100 <= frontend_port <= 44200
        assert api_port != frontend_port

        running = [
            value for value in service_trace(project) if value["event"] == "started"
        ]
        assert [value["serviceId"] for value in running] == ["api", "frontend"]
        assert [value["port"] for value in running] == [api_port, frontend_port]
        assert all(value["secretPresent"] is False for value in running)

        session.stop()
        session.wait_for("command-completed", timeout=2)
        validate_event_stream(session.events)
        assert service_ids(session.events, "service-stopped") == [
            "frontend",
            "api",
            "compiler",
        ]
        stopped = [
            value["serviceId"]
            for value in service_trace(project)
            if value["event"] == "stopped"
        ]
        assert stopped == ["frontend", "api"]
        assert not session.stderr_lines
        session.assert_container_removed()
        return {
            "readyOrder": ["api", "frontend"],
            "distinctLoopbackPorts": 2,
            "portSearchRange": [44100, 44200],
            "shutdownOrder": ["frontend", "api", "compiler"],
        }
    finally:
        session.force_cleanup()


def run_restart_service_case(runtime: Path, parent: Path) -> dict[str, object]:
    evidence, project, tools = prepare_service_case(parent, "services-restart")
    session = DevSession(
        runtime, evidence, project, tools, service_mode="healthy"
    )
    try:
        _, first_api = session.wait_for(
            "service-ready",
            predicate=lambda value: value["payload"].get("serviceId") == "api",
        )
        first_frontend_index, _ = session.wait_for(
            "service-ready",
            predicate=lambda value: value["payload"].get("serviceId") == "frontend",
        )
        first_running = [
            value for value in service_trace(project) if value["event"] == "started"
        ]
        session.signal_pid(
            int(
                next(
                    value["pid"]
                    for value in first_running
                    if value["serviceId"] == "api"
                )
            )
        )

        second_api_index, second_api = session.wait_for(
            "service-ready",
            after=first_frontend_index + 1,
            predicate=lambda value: value["payload"].get("serviceId") == "api",
        )
        session.wait_for(
            "service-ready",
            after=second_api_index + 1,
            predicate=lambda value: value["payload"].get("serviceId") == "frontend",
        )
        assert first_api["payload"]["url"] == second_api["payload"]["url"]
        restarted = [
            value for value in service_trace(project) if value["event"] == "started"
        ]
        assert [value["serviceId"] for value in restarted] == [
            "api",
            "frontend",
            "api",
            "frontend",
        ]
        assert all(value["secretPresent"] is False for value in restarted)
        session.signal_pid(
            int(
                [
                    value["pid"]
                    for value in restarted
                    if value["serviceId"] == "api"
                ][-1]
            )
        )

        diagnostic_index, _ = session.wait_for(
            "diagnostic",
            predicate=lambda value: value["payload"]
            .get("diagnostic", {})
            .get("code")
            == "WPHX2325",
        )
        session.wait_for("command-completed", after=diagnostic_index + 1)
        session.wait_exit(7)
        validate_event_stream(session.events, expected_exit=7)
        assert service_ids(session.events, "service-stopped") == [
            "frontend",
            "api",
            "frontend",
            "api",
            "compiler",
        ]
        assert not session.stderr_lines
        session.assert_container_removed()
        return {"starts": 4, "restartAttempts": 1, "exitCode": 7}
    finally:
        session.force_cleanup()


def run_timeout_service_case(runtime: Path, parent: Path) -> dict[str, object]:
    evidence, project, tools = prepare_service_case(parent, "services-timeout")
    session = DevSession(
        runtime, evidence, project, tools, service_mode="timeout"
    )
    try:
        session.wait_for(
            "diagnostic",
            predicate=lambda value: value["payload"]
            .get("diagnostic", {})
            .get("code")
            == "WPHX2323",
        )
        session.wait_for("watch-ready")
        timed_out = service_trace(project)
        assert [value["event"] for value in timed_out] == ["started", "stopped"]
        assert [value["serviceId"] for value in timed_out] == [
            "timeout",
            "timeout",
        ]
        assert timed_out[0]["secretPresent"] is False

        session.stop()
        session.wait_for("command-completed", timeout=2)
        validate_event_stream(session.events)
        assert service_ids(session.events, "service-stopped") == [
            "timeout",
            "compiler",
        ]
        assert not session.stderr_lines
        session.assert_container_removed()
        return {"diagnostic": "WPHX2323", "exitCode": 130}
    finally:
        session.force_cleanup()


def run_wordpress_service_case(
    runtime: Path, parent: Path, browser_tooling: Path
) -> dict[str, object]:
    evidence, project, tools = prepare_service_case(parent, "services-wordpress")
    session = DevSession(
        runtime, evidence, project, tools, service_mode="wordpress"
    )
    browser_name = session.name + "-browser"
    browser: subprocess.Popen[str] | None = None
    try:
        _, ready = session.wait_for(
            "service-ready",
            predicate=lambda value: value["payload"].get("serviceId")
            == "wordpress",
        )
        session.wait_for("watch-ready")
        assert ready["payload"]["url"] == "http://127.0.0.1:44200/"
        assert ready["payload"]["readiness"] == "http"
        assert ready["payload"]["reload"] == "full-page"
        assert service_ids(session.events, "service-starting") == ["wordpress"]

        compose_files = list(
            (project / ".wphx/runtime").glob("wphx-*.compose.json")
        )
        assert len(compose_files) == 1
        compose_bytes = compose_files[0].read_bytes()
        compose = json.loads(compose_bytes)
        assert compose_bytes == canonical(compose, newline=True)
        assert stat.S_IMODE(compose_files[0].stat().st_mode) == 0o600
        assert b"declared-test-only" not in compose_bytes
        assert b"/wordpresshx/reload/" not in compose_bytes
        plugin_directories = list(
            (project / ".wphx/runtime").glob("wphx-*.mu-plugins")
        )
        assert len(plugin_directories) == 1
        plugin_path = plugin_directories[0] / "wordpresshx-dev-reload.php"
        assert stat.S_IMODE(plugin_directories[0].stat().st_mode) == 0o700
        assert stat.S_IMODE(plugin_path.stat().st_mode) == 0o600
        plugin_source = plugin_path.read_text()
        assert "add_action('wp_footer'" in plugin_source
        assert "WPHX_DEV_RELOAD_CLIENT" in plugin_source
        assert "/wordpresshx/reload/" not in plugin_source
        plugin_lint = subprocess.run(
            ["php", "-l", str(plugin_path)],
            text=True,
            capture_output=True,
            check=False,
        )
        assert plugin_lint.returncode == 0, plugin_lint.stderr
        validate_wordpress_compose(compose_files[0])

        started = [
            value for value in docker_trace(project) if value["event"] == "up"
        ]
        assert [value["event"] for value in started] == ["up"], started
        assert started[0]["port"] == 44200
        assert started[0]["declaredPresent"] is False
        assert started[0]["internalPresent"] is True
        assert started[0]["reloadClientPresent"] is True
        assert started[0]["secretPresent"] is False
        security = wait_for_docker_event(project, "reload-security")
        assert {
            key: security[key]
            for key in (
                "allowedClient",
                "allowedEvents",
                "badReferer",
                "invalidCapability",
                "wrongOrigin",
            )
        } == {
            "allowedClient": 200,
            "allowedEvents": 200,
            "badReferer": 403,
            "invalidCapability": 404,
            "wrongOrigin": 403,
        }

        browser_evidence = evidence / "browser"
        browser_evidence.mkdir()
        browser = subprocess.Popen(
            [
                "docker",
                "run",
                "--rm",
                "--name",
                browser_name,
                "--network",
                f"container:{session.name}",
                "--ipc=host",
                "--mount",
                f"type=bind,src={browser_tooling.resolve()},dst=/tooling,readonly",
                "--mount",
                f"type=bind,src={browser_evidence.resolve()},dst=/browser",
                "-w",
                "/tooling",
                PLAYWRIGHT_IMAGE,
                "node",
                "test-browser-reload.mjs",
                "http://127.0.0.1:44200/",
                "/browser",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        # A fresh hosted runner may need to pull the immutable browser image
        # before Docker creates the named container. Keep that acquisition
        # outside the page-readiness semantics while retaining a hard bound.
        wait_for_path(
            browser_evidence / "browser-ready",
            browser,
            BROWSER_READY_TIMEOUT_SECONDS,
        )
        assert browser_page_loads(project) == 1

        failed_start = len(session.events)
        session.run_node(
            "const fs=require('fs');"
            "fs.appendFileSync('src/acme/site/Site.hx','\\n// BROKEN_HAXE\\n');"
        )
        session.wait_for("diagnostic", after=failed_start)
        session.wait_for("build-retained", after=failed_start)
        time.sleep(0.75)
        assert browser_page_loads(project) == 1
        assert browser.poll() is None

        rebuild_start = len(session.events)
        session.run_node(
            "const fs=require('fs');"
            "const path='src/acme/site/Site.hx';"
            "fs.writeFileSync(path,fs.readFileSync(path,'utf8').replace('// BROKEN_HAXE\\n','// wordpress reload\\n'));"
        )
        published_index, _ = session.wait_for(
            "build-published",
            after=rebuild_start,
            predicate=lambda value: value["payload"].get("generation") == 2,
        )
        _, reload_event = session.wait_for(
            "reload-requested",
            after=published_index + 1,
            predicate=lambda value: value["payload"].get("serviceId")
            == "wordpress",
        )
        assert reload_event["payload"]["reason"] == (
            "complete ownership transaction published"
        )
        browser_status = browser.wait(timeout=20)
        browser_stdout, browser_stderr = browser.communicate()
        assert browser_status == 0, (
            f"browser reload proof exited {browser_status}\n"
            f"stdout:{browser_stdout}\nstderr:{browser_stderr}"
        )
        browser_result = json.loads(
            (browser_evidence / "browser-result.json").read_text()
        )
        assert browser_result["loads"] == 2
        assert browser_result["navigation"] == "reload"
        assert browser_page_loads(project) == 2
        assert service_ids(session.events, "service-starting") == ["wordpress"]
        assert service_ids(session.events, "service-stopped") == []
        assert [value["event"] for value in docker_trace(project)] == [
            "up",
            "reload-security",
        ]
        assert all(
            b"wordpresshx/reload" not in payload
            and b"WPHX_DEV_RELOAD" not in payload
            for payload in owned_bytes(project).values()
        )
        assert all(
            "/wordpresshx/reload/" not in line for line in session.stdout_lines
        )

        session.stop()
        session.wait_for("command-completed", timeout=2)
        validate_event_stream(session.events)
        assert service_ids(session.events, "service-stopped") == [
            "wordpress",
            "compiler",
        ]
        assert [value["event"] for value in docker_trace(project)] == [
            "up",
            "reload-security",
            "stopped",
            "down",
        ]
        assert not list((project / ".wphx/runtime").glob("wphx-*.compose.json"))
        assert not list((project / ".wphx/runtime").glob("wphx-*.mu-plugins"))
        assert not session.stderr_lines
        session.assert_container_removed()
        return {
            "provider": "docker-compose-v2",
            "browser": browser_result,
            "failedBuildReloads": 0,
            "reloadAfterGeneration": 2,
            "serviceRestartsOnSourceEdit": 0,
        }
    finally:
        if browser is not None and browser.poll() is None:
            stop_browser_process(browser, browser_name)
        session.force_cleanup()


def run_service_cases(
    runtime: Path, parent: Path, browser_tooling: Path
) -> dict[str, object]:
    return {
        "healthy": run_healthy_service_case(runtime, parent),
        "restart": run_restart_service_case(runtime, parent),
        "timeout": run_timeout_service_case(runtime, parent),
        "wordpress": run_wordpress_service_case(runtime, parent, browser_tooling),
    }


def run(runtime: Path, browser_tooling: Path) -> dict[str, object]:
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
            hxml_source = hxml.read_text()
            hxml.write_text(hxml_source + "# compiler identity change\n")
            _, replacement_server = session.wait_for(
                "compiler-server-ready", after=restart_start
            )
            assert replacement_server["payload"]["serverCompatibilityDigest"] != server_event[
                "payload"
            ]["serverCompatibilityDigest"]
            session.wait_for(
                "diagnostic",
                after=restart_start,
                predicate=lambda value: value["payload"]
                .get("diagnostic", {})
                .get("code")
                == "WPHX3008",
            )
            projection_retained_index, _ = session.wait_for(
                "build-retained", after=restart_start
            )
            assert not any(
                value["event"] == "build-published"
                for value in session.events[
                    restart_start : projection_retained_index + 1
                ]
            )

            projection_repair_start = len(session.events)
            hxml.write_text(hxml_source)
            _, restored_server = session.wait_for(
                "compiler-server-ready", after=projection_repair_start
            )
            assert restored_server["payload"]["serverCompatibilityDigest"] == server_event[
                "payload"
            ]["serverCompatibilityDigest"]
            session.wait_for(
                "build-published",
                after=projection_repair_start,
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

            service_cases = run_service_cases(runtime, evidence, browser_tooling)

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
                "serviceCases": service_cases,
            }
        finally:
            session.force_cleanup()


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: test-production.py <compiled-runtime-root> <browser-tooling-root>"
        )
    summary = run(Path(sys.argv[1]), Path(sys.argv[2]))
    print(json.dumps(summary, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
