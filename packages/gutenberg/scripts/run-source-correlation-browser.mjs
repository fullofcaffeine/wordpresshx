import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";

import { chromium } from "playwright-core";

const [evidenceRootValue, outputRootValue] = process.argv.slice(2);
assert.ok(evidenceRootValue, "combined G2.4 evidence root is required");
assert.ok(outputRootValue, "G2.4 browser output root is required");

const evidenceRoot = fs.realpathSync(evidenceRootValue);
const outputRoot = path.resolve(outputRootValue);
const host = "127.0.0.1";
const port = 41735;
const modes = Object.freeze({
  development: "runtime/development/editor.js",
  production: "wordpresshx-sdk033-assets/build/editor.js",
});
const runtimeArchitecture = process.arch === "x64" ? "amd64" : process.arch;
const runtimePlatform = `${process.platform}/${runtimeArchitecture}`;
const browserVersions = Object.freeze({
  "linux/amd64": "145.0.7632.6",
  "linux/arm64": "145.0.7632.0",
});
const expectedBrowserVersion = browserVersions[runtimePlatform];

assert.equal(process.version, "v24.13.0", "unexpected Playwright image Node runtime");
assert.equal(
  execFileSync("npm", ["--version"], { encoding: "utf8" }).trim(),
  "11.6.2",
  "unexpected Playwright image npm runtime"
);
assert.ok(expectedBrowserVersion, `unsupported Playwright runtime: ${runtimePlatform}`);
if (fs.existsSync(outputRoot)) {
  assert.ok(
    !fs.lstatSync(outputRoot).isSymbolicLink(),
    "G2.4 browser output root must not be a symlink"
  );
}
fs.mkdirSync(outputRoot, { recursive: true });
assert.deepEqual(
  fs.readdirSync(outputRoot),
  [],
  "G2.4 browser output root must be empty"
);

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function safeEvidencePath(relativePath) {
  assert.match(
    relativePath,
    /^[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*$/u,
    "unsafe evidence request path"
  );
  const resolved = path.resolve(evidenceRoot, relativePath);
  assert.ok(
    resolved.startsWith(`${evidenceRoot}${path.sep}`),
    "evidence request escaped its root"
  );
  return resolved;
}

function harness(mode) {
  const runtimePath = modes[mode];
  assert.ok(runtimePath, `unknown browser harness mode: ${mode}`);
  return `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>WordPressHx G2.4</title></head>
  <body>
    <script>
      window.wordpressHxG24SourceCorrelationProbe = true;
      window.wp = { components: {}, element: {}, i18n: {} };
      window.ReactJSXRuntime = {};
    </script>
    <script src="/${runtimePath}"></script>
  </body>
</html>`;
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${host}:${port}`);
  const harnessMatch = url.pathname.match(
    /^\/harness\/(development|production)\.html$/u
  );
  if (harnessMatch) {
    response.writeHead(200, {
      "cache-control": "no-store",
      "content-type": "text/html; charset=utf-8",
      "x-content-type-options": "nosniff",
    });
    response.end(harness(harnessMatch[1]));
    return;
  }
  const relativePath = url.pathname.slice(1);
  if (!Object.values(modes).includes(relativePath)) {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("not found\n");
    return;
  }
  response.writeHead(200, {
    "cache-control": "no-store",
    "content-type": "text/javascript; charset=utf-8",
    "x-content-type-options": "nosniff",
  });
  response.end(fs.readFileSync(safeEvidencePath(relativePath)));
});

await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(port, host, resolve);
});

let browser;
try {
  browser = await chromium.launch({ headless: true });
  const browserVersion = browser.version();
  assert.equal(
    browserVersion,
    expectedBrowserVersion,
    `unexpected browser version for ${runtimePlatform}`
  );
  const failures = [];
  for (const [mode, runtimePath] of Object.entries(modes)) {
    let expectedStack = null;
    for (let replay = 0; replay < 2; replay += 1) {
      const page = await browser.newPage();
      const failure = new Promise((resolve, reject) => {
        const timer = setTimeout(
          () => reject(new Error(`timed out waiting for ${mode} pageerror`)),
          10_000
        );
        page.once("pageerror", (error) => {
          clearTimeout(timer);
          resolve(error);
        });
      });
      await page.goto(`http://${host}:${port}/harness/${mode}.html`, {
        waitUntil: "load",
      });
      const error = await failure;
      assert.equal(
        error.message,
        "G24_WORDPRESS_SCRIPTS_SOURCE_CORRELATION_FAILURE"
      );
      assert.ok(error.stack, `${mode} browser error has no native stack`);
      assert.match(
        error.stack,
        new RegExp(
          `http:\\/\\/${host}:${port}\\/${runtimePath.replaceAll("/", "\\/")}` +
            ":[0-9]+:[0-9]+"
        ),
        `${mode} native stack lost its exact runtime line and column`
      );
      if (expectedStack === null) {
        expectedStack = error.stack;
      } else {
        assert.equal(
          error.stack,
          expectedStack,
          `${mode} native stack is not replay-stable`
        );
      }
      await page.close();
    }
    fs.writeFileSync(
      path.join(outputRoot, `${mode}.stack`),
      `${expectedStack}\n`,
      "utf8"
    );
    failures.push({
      mode,
      runtimePath,
      stack: `${mode}.stack`,
      replayStable: true,
    });
  }
  fs.writeFileSync(
    path.join(outputRoot, "browser-receipt.json"),
    `${canonicalJson({
      schemaVersion: 1,
      check: "wordpresshx-g2.4-real-browser-v1",
      engine: "chromium",
      runtimePlatform,
      browserVersion,
      playwright: "1.58.2",
      host,
      port,
      failures,
    })}\n`,
    "utf8"
  );
  console.log(
    `G2.4 real Chromium throws passed on ${runtimePlatform} ` +
      `(${browserVersion}): ${Object.keys(modes).join(", ")}; native stacks replay-stable`
  );
} finally {
  if (browser) {
    await browser.close();
  }
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve()))
  );
}
