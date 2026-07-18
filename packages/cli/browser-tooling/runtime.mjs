import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";

import { chromium } from "playwright-core";

const [evidenceRootValue, outputRootValue] = process.argv.slice(2);
assert.ok(evidenceRootValue, "combined evidence root is required");
assert.ok(outputRootValue, "browser output root is required");

const evidenceRoot = fs.realpathSync(evidenceRootValue);
const outputRoot = path.resolve(outputRootValue);
const host = "127.0.0.1";
const port = 41734;
const modes = ["development", "production", "two-stage"];

assert.equal(process.version, "v24.13.0", "unexpected Playwright image Node runtime");
assert.equal(
  execFileSync("npm", ["--version"], { encoding: "utf8" }).trim(),
  "11.6.2",
  "unexpected Playwright image npm runtime"
);
fs.mkdirSync(outputRoot, { recursive: true });

function responseBody(requestPath) {
  if (requestPath.startsWith("/harness/")) {
    const mode = requestPath.slice("/harness/".length, -".html".length);
    assert.ok(modes.includes(mode), `unknown browser harness mode: ${mode}`);
    return {
      type: "text/html; charset=utf-8",
      body: `<!doctype html><meta charset="utf-8"><script type="module" src="/runtime/${mode}.js"></script>`,
    };
  }
  const match = requestPath.match(/^\/runtime\/(development|production|two-stage)\.js$/u);
  if (match) {
    return {
      type: "text/javascript; charset=utf-8",
      body: fs.readFileSync(path.join(evidenceRoot, "runtime", `${match[1]}.js`)),
    };
  }
  return null;
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${host}:${port}`);
  const payload = responseBody(url.pathname);
  if (!payload) {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("not found\n");
    return;
  }
  response.writeHead(200, {
    "cache-control": "no-store",
    "content-type": payload.type,
    "x-content-type-options": "nosniff",
  });
  response.end(payload.body);
});

await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(port, host, resolve);
});

let browser;
try {
  browser = await chromium.launch({ headless: true });
  const receipts = [];
  for (const mode of modes) {
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
      assert.equal(error.message, "SDK034_DELIBERATE_BROWSER_FAILURE");
      assert.ok(error.stack, `${mode} browser error has no native stack`);
      assert.match(
        error.stack,
        new RegExp(
          `http:\\/\\/${host}:${port}\\/runtime\\/${mode}\\.js:[0-9]+:[0-9]+`
        ),
        `${mode} native stack lost its exact runtime line and column`
      );
      if (expectedStack === null) {
        expectedStack = error.stack;
      } else {
        assert.equal(error.stack, expectedStack, `${mode} native stack is not replay-stable`);
      }
      await page.close();
    }
    fs.writeFileSync(path.join(outputRoot, `${mode}.stack`), `${expectedStack}\n`, "utf8");
    receipts.push({ mode, stack: `${mode}.stack`, replayStable: true });
  }
  fs.writeFileSync(
    path.join(outputRoot, "browser-receipt.json"),
    `${JSON.stringify({
      schemaVersion: 1,
      engine: "chromium",
      browserVersion: browser.version(),
      playwright: "1.58.2",
      host,
      port,
      failures: receipts,
    })}\n`,
    "utf8"
  );
  console.log(
    `SDK-034 real Chromium throws passed: ${modes.join(", ")}; native stacks replay-stable`
  );
} finally {
  if (browser) {
    await browser.close();
  }
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve()))
  );
}
