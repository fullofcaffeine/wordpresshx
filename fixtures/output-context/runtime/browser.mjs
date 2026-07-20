import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const toolingRoot = process.argv[2];
assert.ok(toolingRoot, "exact Gutenberg build-tooling root is required");
const toolingRequire = createRequire(
  pathToFileURL(resolve(toolingRoot, "package.json"))
);
const React = toolingRequire("react");
const { renderToStaticMarkup } = toolingRequire("react-dom/server");

const payload = '<script>alert("react")</script>&"\'';
const textareaPayload = '</textarea><script>alert("textarea")</script>&';
const validatedUrl = "https://example.test/todos/7?a=1&b=2";
const markup = renderToStaticMarkup(
  React.createElement(
    "section",
    {
      "aria-label": payload,
      "data-source": payload
    },
    React.createElement("h2", null, payload),
    React.createElement("a", { href: validatedUrl }, "Open todo"),
    React.createElement("textarea", { readOnly: true, value: textareaPayload })
  )
);

const scriptData = JSON.stringify({
  id: 7,
  title: '</script><script>alert("json")</script>&\'',
  lineSeparator: "\u2028",
  paragraphSeparator: "\u2029"
})
  .replaceAll("<", "\\u003c")
  .replaceAll(">", "\\u003e")
  .replaceAll("&", "\\u0026")
  .replaceAll("\u2028", "\\u2028")
  .replaceAll("\u2029", "\\u2029");

assert.equal(markup.includes("<script>"), false);
assert.equal(markup.includes("onfocus="), false);
assert.equal(markup.includes("javascript:"), false);
assert.equal(scriptData.includes("</script>"), false);

console.log(JSON.stringify({
  check: "wordpresshx-adr012-browser-output-context-v1",
  markup,
  scriptData,
  textEscaped: markup.includes("&lt;script&gt;alert(&quot;react&quot;)&lt;/script&gt;&amp;&quot;&#x27;"),
  attributeEscaped: markup.includes("aria-label=\"&lt;script&gt;alert(&quot;react&quot;)&lt;/script&gt;&amp;&quot;&#x27;\""),
  textareaEscaped: markup.includes("&lt;/textarea&gt;&lt;script&gt;alert(&quot;textarea&quot;)&lt;/script&gt;&amp;"),
  unsafeHtmlApiUsed: false
}));
