import assert from "node:assert/strict";
import fs from "node:fs";
import process from "node:process";

import axe from "axe-core";
import { chromium } from "playwright";

const [baseUrl, postId, pageId, pluginName, screenshotPath] = process.argv.slice(2);
assert.match(baseUrl, /^http:\/\/[a-z0-9-]+(?::[0-9]+)?$/);
assert.match(postId, /^[1-9][0-9]*$/);
assert.match(pageId, /^[1-9][0-9]*$/);
assert.match(pluginName, /^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$/);
assert.ok(screenshotPath, "screenshot path is required");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
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

async function waitForEditor() {
  await page
    .locator(".edit-post-layout, .interface-interface-skeleton")
    .first()
    .waitFor({ state: "visible", timeout: 60_000 });
  await dismissWelcomeGuide();
}

async function openOptions() {
  const options = page.getByRole("button", { name: /Options/i }).first();
  await options.waitFor({ state: "visible" });
  await options.focus();
  await options.press("Enter");
  return options;
}

async function waitForSyncState(state) {
  await page.waitForFunction(
    ({ selector, value }) =>
      document.querySelector(selector)?.getAttribute("data-state") === value,
    { selector: ".wphx-todo-lab__sync", value: state }
  );
}

await login();
await page.goto(`${baseUrl}/wp-admin/post.php?post=${postId}&action=edit`, {
  waitUntil: "domcontentloaded",
});
await waitForEditor();

await openOptions();
const menuItem = page.getByRole("menuitemcheckbox", {
  name: "Todo data-store lab",
});
try {
  await menuItem.waitFor({ state: "visible" });
} catch (error) {
  const buttonNames = await page
    .locator("button")
    .evaluateAll((buttons) =>
      buttons.map((button) => ({
        ariaLabel: button.getAttribute("aria-label"),
        text: button.textContent?.trim() ?? "",
        title: button.getAttribute("title"),
      }))
    )
    .catch(() => []);
  console.error(
    JSON.stringify(
      { buttonNames, consoleErrors, pageErrors, title: await page.title(), url: page.url() },
      null,
      2
    )
  );
  throw error;
}
await menuItem.focus();
await menuItem.press("Enter");

const sidebar = page.getByTestId("wphx-todo-data-sidebar");
await sidebar.waitFor({ state: "visible" });
assert.equal(
  await page.getByText("TODOSTUDIO / NATIVE DATA", { exact: true }).count(),
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
assert.equal(focusEnteredSidebar, true, "focus did not enter the data-store sidebar");

const remaining = sidebar.locator(".wphx-todo-lab__meter strong");
assert.equal(await remaining.textContent(), "2");
const footer = sidebar.locator(".wphx-todo-lab__footer");
assert.match((await footer.textContent()) ?? "", /REV 0/);
assert.match((await footer.textContent()) ?? "", /SUB 0/);

const taskToggle = page.getByRole("button", {
  name: "Complete Invite an editorial review",
});
await taskToggle.focus();
await taskToggle.press("Enter");
await remaining.waitFor({ state: "visible" });
await page.waitForFunction(
  (selector) => document.querySelector(selector)?.textContent === "1",
  ".wphx-todo-lab__meter strong"
);
assert.equal(
  await page.getByRole("button", { name: "Reopen Invite an editorial review" }).count(),
  1
);

const reviewToggle = page.getByRole("checkbox", {
  name: "Require editorial review",
});
await reviewToggle.focus();
await reviewToggle.press("Space");
assert.equal(await reviewToggle.isChecked(), true);

assert.equal(await sidebar.locator(".wphx-todo-lab__priority strong").textContent(), "calm");
await sidebar.getByRole("button", { name: "Cycle run priority" }).click();
await page.waitForFunction(
  (selector) => document.querySelector(selector)?.textContent === "focused",
  ".wphx-todo-lab__priority strong"
);

const rehearse = sidebar.getByRole("button", {
  name: "Rehearse preview synchronization",
});
await rehearse.click();
await waitForSyncState("loading");
assert.equal(await rehearse.isDisabled(), true);
await waitForSyncState("error");
assert.equal(
  await sidebar.getByText("Offline rehearsal: no task data was lost.", { exact: true }).count(),
  1
);

const retry = sidebar.getByRole("button", {
  name: "Retry preview synchronization",
});
await retry.click();
await waitForSyncState("loading");
assert.equal(
  await sidebar.locator(".wphx-todo-lab__sync button").isDisabled(),
  true
);
await waitForSyncState("ready");
assert.equal(
  await sidebar.getByText("Preview synchronized through the native registry.", { exact: true }).count(),
  1
);

const finalFooter = (await footer.textContent()) ?? "";
const revision = Number(finalFooter.match(/REV ([0-9]+)/)?.[1] ?? "-1");
const subscriptions = Number(finalFooter.match(/SUB ([0-9]+)/)?.[1] ?? "-1");
assert.equal(revision, 7, `unexpected reducer revision: ${finalFooter}`);
assert.ok(subscriptions >= 7, `native subscription did not observe every action: ${finalFooter}`);

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

const sidebarToggle = page.getByRole("button", { name: "Todo data-store lab" });
await sidebarToggle.focus();
await sidebarToggle.press("Enter");
await sidebar.waitFor({ state: "hidden" });
const focusAfterClose = await page.evaluate(() => ({
  ariaLabel: document.activeElement?.getAttribute("aria-label") ?? "",
  tagName: document.activeElement?.tagName ?? "",
}));
assert.ok(
  focusAfterClose.tagName === "BUTTON" &&
    /Todo data-store lab/i.test(focusAfterClose.ariaLabel),
  `focus was not restored to an editor control: ${JSON.stringify(focusAfterClose)}`
);

await page.goto(`${baseUrl}/wp-admin/post.php?post=${pageId}&action=edit`, {
  waitUntil: "domcontentloaded",
});
await waitForEditor();
await openOptions();
assert.equal(
  await page.getByRole("menuitemcheckbox", { name: "Todo data-store lab" }).count(),
  0,
  "post-only data-store extension leaked into the page editor"
);
await page.keyboard.press("Escape");

const unregister = await page.evaluate((name) => {
  const before = window.wp.plugins.getPlugin(name) !== undefined;
  const removed = window.wp.plugins.unregisterPlugin(name);
  const after = window.wp.plugins.getPlugin(name) !== undefined;
  return { after, before, removed: removed !== undefined };
}, pluginName);
assert.deepEqual(unregister, { after: false, before: true, removed: true });

assert.deepEqual(pageErrors, [], `page errors: ${pageErrors.join("\n")}`);
assert.deepEqual(consoleErrors, [], `console errors: ${consoleErrors.join("\n")}`);
await browser.close();

fs.writeFileSync(
  `${screenshotPath}.json`,
  `${JSON.stringify(
    {
      accessibility: {
        engine: "axe-core 4.10.2",
        seriousOrCriticalViolations: 0,
      },
      check: "wordpresshx-sdk064-real-data-store-v1",
      consoleErrors: 0,
      finalRevision: revision,
      focusAfterClose,
      focusEnteredSidebar,
      keyboardAction: true,
      mouseActions: true,
      nativeSubscriptionCount: subscriptions,
      outcome: "passed",
      pagePostTypeHidden: true,
      syncErrorAndRecovery: true,
      unregister,
    },
    null,
    2
  )}\n`
);
console.log(fs.readFileSync(`${screenshotPath}.json`, "utf8"));
