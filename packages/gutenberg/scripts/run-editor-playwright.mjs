import assert from "node:assert/strict";
import fs from "node:fs";
import process from "node:process";

import { chromium } from "playwright";
import axe from "axe-core";

const [baseUrl, postId, pageId, pluginName, screenshotPath] = process.argv.slice(2);
assert.match(baseUrl, /^http:\/\/[a-z0-9-]+(?::[0-9]+)?$/);
assert.match(postId, /^[1-9][0-9]*$/);
assert.match(pageId, /^[1-9][0-9]*$/);
assert.match(pluginName, /^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$/);
assert.ok(screenshotPath, "screenshot path is required");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") {
    consoleErrors.push(message.text());
  }
});
page.on("pageerror", (error) => pageErrors.push(error.message));

async function login() {
  await page.goto(`${baseUrl}/wp-login.php`, { waitUntil: "domcontentloaded" });
  await page.locator("#user_login").fill("wordpresshx_admin");
  await page.locator("#user_pass").fill("wordpresshx-test-only");
  await Promise.all([
    page.waitForURL(/\/wp-admin\//),
    page.locator("#wp-submit").click(),
  ]);
}

async function dismissWelcomeGuide() {
  const guide = page.locator(".components-guide").first();
  if (await guide.isVisible().catch(() => false)) {
    await guide.getByRole("button", { name: /^Close$/i }).click();
  }
}

async function openOptions() {
  const options = page.getByRole("button", { name: /Options/i }).first();
  try {
    await options.waitFor({ state: "visible" });
  } catch (error) {
    const buttonNames = await page
      .locator("button")
      .evaluateAll((buttons) =>
        buttons.map((button) => ({
          ariaLabel: button.getAttribute("aria-label"),
          className: button.className,
          text: button.textContent?.trim() ?? "",
          title: button.getAttribute("title"),
        }))
      )
      .catch(() => []);
    console.error(
      JSON.stringify(
        {
          buttonNames,
          consoleErrors,
          pageErrors,
          title: await page.title(),
          url: page.url(),
        },
        null,
        2
      )
    );
    throw error;
  }
  await options.focus();
  await options.press("Enter");
  return options;
}

await login();
await page.goto(`${baseUrl}/wp-admin/post.php?post=${postId}&action=edit`, {
  waitUntil: "domcontentloaded",
});
await page.locator(".edit-post-layout, .interface-interface-skeleton").first().waitFor({
  state: "visible",
  timeout: 60_000,
});
await dismissWelcomeGuide();

const optionsButton = await openOptions();
const menuItem = page.getByRole("menuitemcheckbox", {
  name: "Todo Studio readiness",
});
await menuItem.waitFor({ state: "visible" });
await menuItem.focus();
await menuItem.press("Enter");

const sidebar = page.getByTestId("wphx-readiness-sidebar");
await sidebar.waitFor({ state: "visible" });
assert.equal(
  await page.getByText("TODOSTUDIO / EDITOR CHECK", { exact: true }).count(),
  1
);
let focusEntryTabs = 0;
let focusEnteredSidebar = await sidebar.evaluate((element) =>
  element.contains(document.activeElement)
);
while (!focusEnteredSidebar && focusEntryTabs < 40) {
  await page.keyboard.press("Tab");
  focusEntryTabs += 1;
  focusEnteredSidebar = await sidebar.evaluate((element) =>
    element.contains(document.activeElement)
  );
}
assert.equal(focusEnteredSidebar, true, "focus did not enter the plugin sidebar");

const reviewToggle = page.getByRole("checkbox", {
  name: "Require editorial review",
});
await reviewToggle.focus();
await reviewToggle.press("Space");
assert.equal(await reviewToggle.isChecked(), true);
await reviewToggle.click();
assert.equal(await reviewToggle.isChecked(), false);

const priority = sidebar.locator('[aria-live="polite"]');
await priority.waitFor({ state: "visible" });
assert.equal(await priority.textContent(), "CALM");
await sidebar.getByRole("button", { name: "Cycle publishing priority" }).click();
await page.waitForFunction(
  (selector) => document.querySelector(selector)?.textContent === "FOCUSED",
  '[data-testid="wphx-readiness-sidebar"] [aria-live="polite"]'
);

await page.addScriptTag({ content: axe.source });
const accessibility = await page.evaluate(async () => {
  const result = await window.axe.run(document, {
    runOnly: { type: "tag", values: ["wcag2a", "wcag2aa"] },
  });
  return result.violations.map((violation) => ({
    id: violation.id,
    impact: violation.impact,
    targets: violation.nodes.map((node) => node.target),
  }));
});
const seriousOrCritical = accessibility.filter(
  ({ impact }) => impact === "serious" || impact === "critical"
);
assert.deepEqual(seriousOrCritical, []);
await page.screenshot({ path: screenshotPath, fullPage: true });

const sidebarToggle = page.getByRole("button", {
  name: "Todo Studio readiness",
});
await sidebarToggle.focus();
await sidebarToggle.press("Enter");
await sidebar.waitFor({ state: "hidden" });
const focusAfterClose = await page.evaluate(() => ({
  ariaLabel: document.activeElement?.getAttribute("aria-label") ?? "",
  tagName: document.activeElement?.tagName ?? "",
}));
assert.ok(
  focusAfterClose.tagName === "BUTTON" &&
    /Todo Studio readiness/i.test(focusAfterClose.ariaLabel),
  `focus was not restored to an editor control: ${JSON.stringify(focusAfterClose)}`
);

const unregister = await page.evaluate((name) => {
  const before = window.wp.plugins.getPlugin(name) !== undefined;
  const removed = window.wp.plugins.unregisterPlugin(name);
  const after = window.wp.plugins.getPlugin(name) !== undefined;
  return { after, before, removed: removed !== undefined };
}, pluginName);
assert.deepEqual(unregister, { after: false, before: true, removed: true });

await page.goto(`${baseUrl}/wp-admin/post.php?post=${pageId}&action=edit`, {
  waitUntil: "domcontentloaded",
});
await page.locator(".edit-post-layout, .interface-interface-skeleton").first().waitFor({
  state: "visible",
  timeout: 60_000,
});
await dismissWelcomeGuide();
await openOptions();
assert.equal(
  await page
    .getByRole("menuitemcheckbox", { name: "Todo Studio readiness" })
    .count(),
  0,
  "post-only extension leaked into the page editor"
);
await page.keyboard.press("Escape");

assert.deepEqual(pageErrors, [], `page errors: ${pageErrors.join("\n")}`);
assert.deepEqual(
  consoleErrors,
  [],
  `console errors: ${consoleErrors.join("\n")}`
);
await browser.close();

fs.writeFileSync(
  `${screenshotPath}.json`,
  `${JSON.stringify(
    {
      accessibility: {
        engine: "axe-core 4.10.2",
        seriousOrCriticalViolations: 0,
      },
      check: "wordpresshx-sdk063-real-editor-v1",
      consoleErrors: 0,
      focusAfterClose,
      focusEntryTabs,
      focusEnteredSidebar,
      keyboardToggle: true,
      mousePriority: true,
      outcome: "passed",
      pagePostTypeHidden: true,
      unregister,
    },
    null,
    2
  )}\n`
);
console.log(fs.readFileSync(`${screenshotPath}.json`, "utf8"));
