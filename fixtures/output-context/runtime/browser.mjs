import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const toolingRoot = process.argv[2];
const planPath = process.argv[3];
assert.ok(toolingRoot, "exact Gutenberg build-tooling root is required");
assert.ok(planPath, "Haxe-generated output-context plan is required");
const toolingRequire = createRequire(
  pathToFileURL(resolve(toolingRoot, "package.json"))
);
const React = toolingRequire("react");
const { renderToStaticMarkup } = toolingRequire("react-dom/server");

const planBytes = readFileSync(planPath);
const plan = JSON.parse(planBytes);
assert.equal(plan.schema, "wordpresshx.output-context-runtime-plan.v2");
assert.equal(plan.restJson.failureReason, "");
assert.equal(plan.scriptData.failureReason, "");
assert.equal(plan.encodingFailure.failureReason, "invalid-control-character");
assert.equal(plan.encodingFailure.encoded, "");

for (const accepted of ["https", "schemeCase", "relative", "fragment"]) {
  assert.equal(plan.urlMatrix[accepted].accepted, true);
}
for (const rejected of [
  "javascript",
  "schemeWhitespace",
  "protocolRelative",
  "data"
]) {
  assert.equal(plan.urlMatrix[rejected].accepted, false);
}

const style = Object.fromEntries(
  plan.inlineStyle
    .split(";")
    .filter(Boolean)
    .map((declaration) => {
      const separator = declaration.indexOf(":");
      const property = declaration.slice(0, separator);
      const value = declaration.slice(separator + 1);
      const reactProperty =
        property === "gap"
          ? property
          : property.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
      return [reactProperty, value];
    })
);

const markup = renderToStaticMarkup(
  React.createElement(
    "section",
    {
      "aria-label": plan.attribute,
      "data-source": plan.attribute,
      style
    },
    React.createElement("h2", null, plan.text),
    React.createElement("a", { href: plan.url }, "Open todo"),
    React.createElement("textarea", {
      readOnly: true,
      value: plan.textarea
    })
  )
);

const scriptData = JSON.stringify(JSON.parse(plan.scriptData.encoded))
  .replaceAll("<", "\\u003c")
  .replaceAll(">", "\\u003e")
  .replaceAll("&", "\\u0026")
  .replaceAll("\u2028", "\\u2028")
  .replaceAll("\u2029", "\\u2029");

assert.equal(markup.includes("<script>"), false);
assert.equal(markup.includes(' onfocus="alert(1)"'), false);
assert.equal(markup.includes("javascript:"), false);
assert.equal(scriptData.includes("</script>"), false);
assert.equal(
  plan.stylesheet,
  ".todo-card{color:#c43b27;display:grid;gap:16px;}.todo-card__title{display:block;}"
);
assert.deepEqual(plan.markup, {
  fragmentId: "TodoCard.render@fixture",
  sourceFile: "fixtures/output-context/test/Main.hx",
  sourceLine: 68,
  sourceColumn: 41
});

console.log(JSON.stringify({
  check: "wordpresshx-adr012-browser-output-context-v1",
  markup,
  planSha256: createHash("sha256").update(planBytes).digest("hex"),
  scriptData,
  textEscaped: markup.includes(
    "&lt;script&gt;alert(&quot;text&quot;)&lt;/script&gt;&amp;&quot;&#x27;"
  ),
  attributeEscaped: markup.includes(
    "aria-label=\"&quot; autofocus onfocus=&quot;alert(1)&quot; data-note=&quot;&lt;unsafe&gt;&quot;\""
  ),
  textareaEscaped: markup.includes("&lt;/textarea&gt;&lt;script&gt;alert(&quot;textarea&quot;)&lt;/script&gt;&amp;"),
  unsafeHtmlApiUsed: false
}));
