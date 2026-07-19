import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { chromium } from "playwright-core";

const [pageUrl, evidenceRootValue] = process.argv.slice(2);
assert.ok(pageUrl, "WordPress page URL is required");
assert.ok(evidenceRootValue, "browser evidence root is required");

const evidenceRoot = path.resolve(evidenceRootValue);
const runtimeArchitecture = process.arch === "x64" ? "amd64" : process.arch;
const runtimePlatform = `${process.platform}/${runtimeArchitecture}`;
const browserVersions = Object.freeze({
  "linux/amd64": "145.0.7632.6",
  "linux/arm64": "145.0.7632.0",
});
const expectedBrowserVersion = browserVersions[runtimePlatform];

assert.equal(process.version, "v24.13.0", "unexpected Playwright image Node runtime");
assert.ok(expectedBrowserVersion, `unsupported Playwright runtime: ${runtimePlatform}`);

const browser = await chromium.launch({ headless: true });
try {
  assert.equal(
    browser.version(),
    expectedBrowserVersion,
    `unexpected browser version for ${runtimePlatform}`
  );
  const page = await browser.newPage();
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.goto(pageUrl, { waitUntil: "load" });
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.wordpresshxReloadReady === "true" &&
      document.documentElement.dataset.wordpresshxPageLoads === "1",
    undefined,
    { timeout: 10_000 }
  );
  fs.writeFileSync(path.join(evidenceRoot, "browser-ready"), "ready\n", "utf8");

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.wordpresshxReloadReady === "true" &&
      document.documentElement.dataset.wordpresshxPageLoads === "2",
    undefined,
    { timeout: 20_000 }
  );
  const result = await page.evaluate(() => ({
    loads: Number(document.documentElement.dataset.wordpresshxPageLoads),
    navigation: performance.getEntriesByType("navigation")[0]?.type ?? "missing",
  }));
  assert.deepEqual(result, { loads: 2, navigation: "reload" });
  assert.deepEqual(pageErrors, []);
  fs.writeFileSync(
    path.join(evidenceRoot, "browser-result.json"),
    `${JSON.stringify({
      browserVersion: browser.version(),
      loads: result.loads,
      navigation: result.navigation,
      playwright: "1.58.2",
      runtimePlatform,
    })}\n`,
    "utf8"
  );
  await page.close();
} finally {
  await browser.close();
}
