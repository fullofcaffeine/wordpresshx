import assert from "node:assert/strict";

import { chromium } from "playwright";

const [baseUrl, postId] = process.argv.slice(2);
assert.match(baseUrl, /^http:\/\/[a-z0-9-]+(?::[0-9]+)?$/);
assert.match(postId, /^[1-9][0-9]*$/);

const expected = {
  manyBooks: "3 libros",
  manyShelfItems: "3 elementos de estante",
  oneBook: "1 libro",
  openAction: "Abrir",
  openTitle: "Abrir Atlas",
  ready: "Biblioteca lista.",
};
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const consoleMessages = [];
const pageErrors = [];
const scriptResponses = [];
page.on("console", (message) => consoleMessages.push(message.text()));
page.on("pageerror", (error) => pageErrors.push(error.message));
page.on("response", (response) => {
  if (response.url().includes("wordpresshx-sdk055")) {
    scriptResponses.push({ status: response.status(), url: response.url() });
  }
});

async function translatedProbe(surface) {
  try {
    await page.waitForFunction(
      () => window.wordpressHxSdk055 !== undefined,
      null,
      { timeout: 60_000 }
    );
  } catch (error) {
    const scripts = await page
      .locator("script[src]")
      .evaluateAll((nodes) => nodes.map((node) => node.src));
    console.error(
      JSON.stringify(
        {
          consoleMessages,
          pageErrors,
          scriptResponses,
          scripts,
          surface,
          url: page.url(),
        },
        null,
        2
      )
    );
    throw error;
  }
  return page.evaluate(() => window.wordpressHxSdk055);
}

await page.goto(baseUrl, { waitUntil: "domcontentloaded" });
assert.deepEqual(await translatedProbe("frontend"), expected);

await page.goto(`${baseUrl}/wp-login.php`, { waitUntil: "domcontentloaded" });
await page.locator("#user_login").fill("wordpresshx_admin");
await page.locator("#user_pass").fill("wordpresshx-test-only");
await Promise.all([
  page.waitForURL(/\/wp-admin\//),
  page.locator("#wp-submit").click(),
]);
await page.goto(`${baseUrl}/wp-admin/post.php?post=${postId}&action=edit`, {
  waitUntil: "domcontentloaded",
});
await page
  .locator(".edit-post-layout, .interface-interface-skeleton")
  .first()
  .waitFor({ state: "visible", timeout: 60_000 });
assert.deepEqual(await translatedProbe("editor"), expected);
assert.deepEqual(pageErrors, []);
await browser.close();

console.log(
  JSON.stringify(
    {
      check: "wordpresshx-sdk055-real-browser-i18n-v1",
      editor: expected,
      frontend: expected,
      locale: "es_MX",
      outcome: "passed",
      pageErrors: 0,
    },
    null,
    2
  )
);
