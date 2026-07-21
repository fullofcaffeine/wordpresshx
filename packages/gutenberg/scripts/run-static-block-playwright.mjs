import assert from "node:assert/strict";
import fs from "node:fs";
import process from "node:process";

import { chromium } from "playwright";

const [baseUrl, currentPostId, legacyPostId, screenshotPath, evidencePath] =
  process.argv.slice(2);
assert.match(baseUrl, /^http:\/\/[a-z0-9-]+(?::[0-9]+)?$/);
assert.match(currentPostId, /^[1-9][0-9]*$/);
assert.match(legacyPostId, /^[1-9][0-9]*$/);
assert.ok(screenshotPath, "screenshot path is required");
assert.ok(evidencePath, "evidence path is required");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

const expectedCurrent =
  '<!-- wp:wordpresshx/callout -->\n<aside class="wp-block-wordpresshx-callout wphx-callout"><span class="wphx-callout__label">SHIP READY</span><p class="wphx-callout__message">Typed editor round trip.</p></aside>\n<!-- /wp:wordpresshx/callout -->';
const expectedLegacy =
  '<!-- wp:wordpresshx/callout -->\n<div class="wp-block-wordpresshx-callout wphx-callout-legacy"><p class="wphx-callout__message">Legacy bytes.</p></div>\n<!-- /wp:wordpresshx/callout -->';
const expectedMigrated =
  '<!-- wp:wordpresshx/callout -->\n<aside class="wp-block-wordpresshx-callout wphx-callout"><span class="wphx-callout__label">NOTE</span><p class="wphx-callout__message">Legacy bytes.</p></aside>\n<!-- /wp:wordpresshx/callout -->';

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

async function openEditor(postId) {
  await page.goto(`${baseUrl}/wp-admin/post.php?post=${postId}&action=edit`, {
    waitUntil: "domcontentloaded",
  });
  await page
    .locator(".edit-post-layout, .interface-interface-skeleton")
    .first()
    .waitFor({ state: "visible", timeout: 60_000 });
  await dismissWelcomeGuide();
  await page.waitForFunction(
    () => window.wp?.blocks?.getBlockType("wordpresshx/callout") !== undefined,
    undefined,
    { timeout: 60_000 },
  );
}

async function editedContent() {
  return page.evaluate(() =>
    window.wp.data.select("core/editor").getEditedPostContent(),
  );
}

async function persistedContent(postId) {
  return page.evaluate(async (id) => {
    const post = await window.wp.apiFetch({
      path: `/wp/v2/posts/${id}?context=edit`,
    });
    return post.content.raw;
  }, Number(postId));
}

async function savePost() {
  await page.evaluate(async () => {
    await window.wp.data.dispatch("core/editor").savePost();
  });
  await page.waitForFunction(
    () =>
      !window.wp.data.select("core/editor").isSavingPost() &&
      !window.wp.data.select("core/editor").isEditedPostDirty(),
  );
}

async function editorSurface() {
  // Block API v3 can move the editing canvas into an iframe; classic setups
  // still render it in the top-level document.
  const iframeSelector = 'iframe[name="editor-canvas"]';
  if ((await page.locator(iframeSelector).count()) > 0) {
    return page.frameLocator(iframeSelector);
  }
  return page;
}

async function editorControl(label) {
  const surface = await editorSurface();
  return surface.locator(`[aria-label="${label}"]`);
}

async function assertNoRecoveryWarning() {
  const surface = await editorSurface();
  return assert.equal(
    await surface
      .locator(".block-editor-block-list__block-invalid-warning")
      .count(),
    0,
    "Gutenberg offered block recovery",
  );
}

await login();
await openEditor(currentPostId);
const insertion = await page.evaluate(() => {
  const block = window.wp.blocks.createBlock("wordpresshx/callout", {
    label: "DRAFT",
    message: "Before typed edit.",
  });
  window.wp.data.dispatch("core/block-editor").resetBlocks([]);
  window.wp.data.dispatch("core/block-editor").insertBlocks(block);
  const inserted = window.wp.data
    .select("core/block-editor")
    .getBlock(block.clientId);
  return {
    attributes: inserted.attributes,
    clientId: block.clientId,
    name: inserted.name,
  };
});
assert.equal(insertion.name, "wordpresshx/callout");
assert.deepEqual(insertion.attributes, {
  label: "DRAFT",
  message: "Before typed edit.",
});

const labelInput = await editorControl("Callout label");
const messageInput = await editorControl("Callout message");
await labelInput.waitFor({ state: "visible" });
await labelInput.fill("SHIP READY");
await page.waitForTimeout(1_200);
await messageInput.fill("Typed editor round trip.");
await page.waitForFunction(
  () =>
    window.wp.data.select("core/block-editor").getBlocks()[0]?.attributes
      .message === "Typed editor round trip.",
);
await page.waitForTimeout(1_200);

await page.evaluate(() => window.wp.data.dispatch("core/editor").undo());
await page.waitForFunction(
  () =>
    window.wp.data.select("core/block-editor").getBlocks()[0]?.attributes
      .message !== "Typed editor round trip.",
);
const undone = await page.evaluate(
  () => window.wp.data.select("core/block-editor").getBlocks()[0].attributes,
);
await page.evaluate(() => window.wp.data.dispatch("core/editor").redo());
await page.waitForFunction(
  () =>
    window.wp.data.select("core/block-editor").getBlocks()[0]?.attributes
      .message === "Typed editor round trip.",
);
const redone = await page.evaluate(
  () => window.wp.data.select("core/block-editor").getBlocks()[0].attributes,
);
assert.deepEqual(undone, {
  label: "SHIP READY",
  message: "Before typed edit.",
});
assert.deepEqual(redone, {
  label: "SHIP READY",
  message: "Typed editor round trip.",
});
assert.equal(await editedContent(), expectedCurrent);
await assertNoRecoveryWarning();
await savePost();
assert.equal(await persistedContent(currentPostId), expectedCurrent);
await page.screenshot({ path: screenshotPath, fullPage: true });

await page.reload({ waitUntil: "domcontentloaded" });
await page
  .locator(".edit-post-layout, .interface-interface-skeleton")
  .first()
  .waitFor({ state: "visible", timeout: 60_000 });
const reloadedLabelInput = await editorControl("Callout label");
const reloadedMessageInput = await editorControl("Callout message");
await reloadedLabelInput.waitFor({ state: "visible" });
assert.equal(
  await reloadedLabelInput.inputValue(),
  "SHIP READY",
);
assert.equal(
  await reloadedMessageInput.inputValue(),
  "Typed editor round trip.",
);
await assertNoRecoveryWarning();

await page.goto(`${baseUrl}/?p=${currentPostId}`, { waitUntil: "networkidle" });
const currentFrontend = page.locator("aside.wphx-callout");
await currentFrontend.waitFor({ state: "visible" });
assert.equal(
  await currentFrontend.locator(".wphx-callout__label").textContent(),
  "SHIP READY",
);
assert.equal(
  await currentFrontend.locator(".wphx-callout__message").textContent(),
  "Typed editor round trip.",
);
assert.equal(
  await page.getByText("STATIC / TYPED / NATIVE", { exact: true }).count(),
  0,
);
assert.equal(await currentFrontend.locator("textarea").count(), 0);

await openEditor(legacyPostId);
const legacyLabelInput = await editorControl("Callout label");
const legacyMessageInput = await editorControl("Callout message");
await legacyMessageInput.waitFor({ state: "visible" });
assert.equal(
  await legacyLabelInput.inputValue(),
  "NOTE",
);
assert.equal(
  await legacyMessageInput.inputValue(),
  "Legacy bytes.",
);
// Gutenberg migrates a valid deprecated block into current in-memory
// attributes, but preserves the post's original bytes until an actual edit
// makes the post dirty. Exercise the typed onChange boundary, restore the
// migrated value, and then require current save bytes.
assert.equal(await editedContent(), expectedLegacy);
await assertNoRecoveryWarning();
await legacyLabelInput.fill("MIGRATION CHECK");
await page.waitForFunction(
  () =>
    window.wp.data.select("core/block-editor").getBlocks()[0]?.attributes
      .label === "MIGRATION CHECK",
);
await legacyLabelInput.fill("NOTE");
await page.waitForFunction(
  () =>
    window.wp.data.select("core/block-editor").getBlocks()[0]?.attributes
      .label === "NOTE" &&
    window.wp.data.select("core/editor").isEditedPostDirty(),
);
assert.equal(await editedContent(), expectedMigrated);
await savePost();
assert.equal(await persistedContent(legacyPostId), expectedMigrated);

await page.goto(`${baseUrl}/?p=${legacyPostId}`, { waitUntil: "networkidle" });
const legacyFrontend = page.locator("aside.wphx-callout");
await legacyFrontend.waitFor({ state: "visible" });
assert.equal(
  await legacyFrontend.locator(".wphx-callout__label").textContent(),
  "NOTE",
);
assert.equal(
  await legacyFrontend.locator(".wphx-callout__message").textContent(),
  "Legacy bytes.",
);
assert.equal(await page.locator(".wphx-callout-legacy").count(), 0);

assert.deepEqual(pageErrors, [], `page errors: ${pageErrors.join("\n")}`);
assert.deepEqual(
  consoleErrors,
  [],
  `console errors: ${consoleErrors.join("\n")}`,
);
await browser.close();

fs.writeFileSync(
  evidencePath,
  `${JSON.stringify(
    {
      blockName: insertion.name,
      check: "wordpresshx-sdk061-real-static-block-v1",
      consoleErrors: 0,
      currentBytes: expectedCurrent,
      frontendCurrent: true,
      frontendMigration: true,
      insertEditSaveReload: true,
      migratedBytes: expectedMigrated,
      nativeInsertion: insertion,
      outcome: "passed",
      pageErrors: 0,
      recoveryWarnings: 0,
      undoRedo: { redone, undone },
      wordpressVersion: "7.0",
    },
    null,
    2,
  )}\n`,
  "utf8",
);
console.log(fs.readFileSync(evidencePath, "utf8"));
