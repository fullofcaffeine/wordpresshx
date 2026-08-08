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

function renderMarkupNode(node) {
  if (node.kind === "text" || node.kind === "static-text") {
    return node.value;
  }
  assert.equal(node.kind, "element");
  const properties = {};
  for (const attribute of node.attributes) {
    assert.ok(attribute.kind === "attribute" || attribute.kind === "url");
    const name = attribute.name === "class" ? "className" : attribute.name;
    properties[name] = attribute.value;
  }
  return React.createElement(
    node.tag,
    properties,
    ...node.children.map(renderMarkupNode)
  );
}

const planBytes = readFileSync(planPath);
const plan = JSON.parse(planBytes);
assert.equal(plan.schema, "wordpresshx.output-context-runtime-plan.v3");
assert.equal(plan.restJson.status, "encoded");
assert.equal(plan.scriptData.status, "encoded");
assert.equal(Object.hasOwn(plan.restJson, "reason"), false);
assert.equal(Object.hasOwn(plan.scriptData, "reason"), false);
assert.equal(plan.encodingFailure.status, "rejected");
assert.equal(plan.encodingFailure.reason, "invalid-domain-id");
assert.equal(Object.hasOwn(plan.encodingFailure, "encoded"), false);
assert.equal(plan.emptyFailure.status, "rejected");
assert.equal(plan.emptyFailure.reason, "codec-rejected-without-reason");
assert.equal(Object.hasOwn(plan.emptyFailure, "encoded"), false);
assert.equal(plan.controlJson.length, 0x20);
for (let code = 0; code < 0x20; code += 1) {
  const result = plan.controlJson[code];
  assert.equal(result.status, "encoded");
  assert.equal(Object.hasOwn(result, "reason"), false);
  assert.equal(JSON.parse(result.encoded).title, `before-${String.fromCharCode(code)}-after`);
}
assert.equal(plan.depthFailure.status, "rejected");
assert.match(plan.depthFailure.reason, /json-depth-limit-exceeded$/);
assert.equal(Object.hasOwn(plan.depthFailure, "encoded"), false);
assert.equal(plan.invalidUnicodeFailure.status, "rejected");
assert.match(plan.invalidUnicodeFailure.reason, /invalid-unicode$/);
assert.equal(Object.hasOwn(plan.invalidUnicodeFailure, "encoded"), false);
assert.equal(plan.richHtml.length, 4);
assert.equal(
  plan.richHtml[2].canonicalPolicy,
  "profile=wp70-release;version=todo-rich.v1;tags=a[href,title],p,strong;protocols=http,https"
);
assert.notEqual(plan.richHtml[2].policyIdentity, plan.richHtml[3].policyIdentity);

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
const generatedMarkup = renderToStaticMarkup(renderMarkupNode(plan.markup.root));

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
  createHash("sha256").update(plan.markup.canonicalAst).digest("hex"),
  plan.markup.astSha256
);
assert.equal(
  plan.markup.canonicalAst,
  "article[class:attribute](h2[](text),a[href:url](static-text))"
);
assert.equal(generatedMarkup.includes("<script>"), false);
assert.equal(generatedMarkup.includes('data-forged="true"'), false);
assert.equal(generatedMarkup.includes("javascript:"), false);
assert.equal(
  plan.stylesheet,
  ".todo-card{color:#c43b27;display:grid;gap:16px;}.todo-card__title{display:block;}"
);
assert.equal(plan.markup.fragmentId, "TodoCard.render@fixture");
assert.equal(plan.markup.sourceFile, "fixtures/output-context/test/Main.hx");

console.log(JSON.stringify({
  check: "wordpresshx-adr012-browser-output-context-v1",
  generatedMarkup,
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
