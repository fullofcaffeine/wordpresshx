import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import ts from "typescript";
import webpack from "webpack";

const [packageRoot, workRoot, replayRoot, toolingRoot] = process.argv.slice(2);
for (const [label, value] of Object.entries({
  packageRoot,
  workRoot,
  replayRoot,
  toolingRoot,
})) {
  assert.ok(value, `${label} is required`);
}

assert.equal(process.version, "v22.17.0", "unexpected Node runtime");
assert.equal(
  execFileSync("npm", ["--version"], { encoding: "utf8" }).trim(),
  "10.9.2",
  "unexpected npm runtime"
);
assert.equal(ts.version, "5.9.3", "unexpected TypeScript runtime");
assert.equal(webpack.version, "5.108.4", "unexpected Webpack runtime");

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function walkFiles(root, ignored = new Set()) {
  const output = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (ignored.has(entry.name)) {
      continue;
    }
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      output.push(...walkFiles(fullPath, ignored));
    } else if (entry.isFile()) {
      output.push(fullPath);
    }
  }
  return output.sort();
}

function relativeTree(root, ignored = new Set()) {
  return new Map(
    walkFiles(root, ignored).map((file) => [
      path.relative(root, file).split(path.sep).join("/"),
      fs.readFileSync(file),
    ])
  );
}

function assertSameTree(firstRoot, secondRoot, ignored = new Set()) {
  const first = relativeTree(firstRoot, ignored);
  const second = relativeTree(secondRoot, ignored);
  assert.deepEqual([...first.keys()], [...second.keys()], "file set drifted");
  for (const [relativePath, content] of first) {
    assert.deepEqual(
      content,
      second.get(relativePath),
      `bytes drifted for ${relativePath}`
    );
  }
}

function treeDigest(root, ignored = new Set()) {
  const hash = createHash("sha256");
  for (const [relativePath, content] of relativeTree(root, ignored)) {
    hash.update(relativePath);
    hash.update("\0");
    hash.update(content);
    hash.update("\0");
  }
  return hash.digest("hex");
}

function assertNoMachinePath(label, content) {
  const text = Buffer.isBuffer(content) ? content.toString("utf8") : content;
  for (const forbidden of [
    ["", "Users", ""].join("/"),
    ["", "home", "runner", ""].join("/"),
    "\\Users\\",
    packageRoot,
    workRoot,
    replayRoot,
    toolingRoot,
    "wordpresshx-sdk063-build.",
    "wordpresshx-sdk063-replay.",
  ]) {
    assert.ok(!text.includes(forbidden), `${label} leaks ${forbidden}`);
  }
}

const profile = readJson(
  path.join(
    packageRoot,
    "src/wordpress/hx/gutenberg/profile/wp70-release.editor-plugin.browser-hxx.json"
  )
);
assert.equal(profile.profileId, "wp70-release");
assert.equal(profile.catalogId, "editor-plugin");
const mappings = new Map(
  profile.mappings.map(({ request, handle }) => [request, handle])
);

const ignoredGenerated = new Set(["asset-plan.json", "build", "node_modules"]);
assertSameTree(workRoot, replayRoot, ignoredGenerated);
for (const [relativePath, content] of relativeTree(workRoot, ignoredGenerated)) {
  assertNoMachinePath(relativePath, content);
}
const generatedTreeSha256 = treeDigest(workRoot, ignoredGenerated);

const generatedMainPath = path.join(workRoot, "sdk063/fixture/Main.tsx");
const generatedEntryPath = path.join(workRoot, "editor.tsx");
const generatedMain = fs.readFileSync(generatedMainPath, "utf8");
const generatedEntry = fs.readFileSync(generatedEntryPath, "utf8");
for (const required of [
  'from "@wordpress/plugins"',
  'from "@wordpress/data"',
  'from "@wordpress/editor"',
  'from "@wordpress/element"',
  'from "@wordpress/i18n"',
  'from "@wordpress/components"',
  "registerPlugin(Main.pluginName",
  "unregisterPlugin(Main.pluginName)",
  "<PluginSidebarMoreMenuItem",
  "<PluginSidebar",
  "<PanelBody>",
  "<ToggleControl",
  'CurrentPost.STORE = "core/editor"',
]) {
  const source = required.startsWith("CurrentPost")
    ? fs.readFileSync(
        path.join(
          workRoot,
          "wordpress/hx/gutenberg/editor/CurrentPost.tsx"
        ),
        "utf8"
      )
    : generatedMain;
  assert.ok(source.includes(required), `generated source omitted ${required}`);
}
assert.ok(generatedEntry.includes("Main.main()"), "generated entry omitted main");
for (const forbidden of [
  "__experimental",
  "__unstable",
  "dangerouslySetInnerHTML",
  "Register.unsafeCast",
]) {
  assert.ok(!generatedMain.includes(forbidden), `generated source retained ${forbidden}`);
}

const ownedGeneratedFiles = walkFiles(workRoot).filter((file) =>
  [
    "/sdk063/fixture/",
    "/wordpress/hx/gutenberg/editor/",
    "/wordpress/hx/gutenberg/components/PanelBodyProps.tsx",
    "/wordpress/hx/gutenberg/components/ToggleControlProps.tsx",
  ].some((segment) => file.split(path.sep).join("/").includes(segment))
);
for (const file of ownedGeneratedFiles) {
  if (!file.endsWith(".tsx")) {
    continue;
  }
  const text = fs.readFileSync(file, "utf8");
  const source = ts.createSourceFile(
    file,
    text,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TSX
  );
  const weak = [];
  const visit = (node) => {
    if (
      node.kind === ts.SyntaxKind.AnyKeyword ||
      node.kind === ts.SyntaxKind.UnknownKeyword
    ) {
      const position = source.getLineAndCharacterOfPosition(node.getStart(source));
      weak.push(`${position.line + 1}:${position.character + 1}`);
    }
    ts.forEachChild(node, visit);
  };
  visit(source);
  assert.deepEqual(weak, [], `${path.relative(workRoot, file)} has weak types`);
}

const mainMap = readJson(`${generatedMainPath}.map`);
assert.ok(
  mainMap.sources.some((source) =>
    source.endsWith(
      "test/editor-plugin-fixture/src/sdk063/fixture/Main.hx"
    )
  ),
  "generated source map does not point to the Haxe editor fixture"
);

const sourceFiles = walkFiles(workRoot).filter((file) => file.endsWith(".tsx"));
const compilerOptions = {
  allowJs: false,
  exactOptionalPropertyTypes: false,
  jsx: ts.JsxEmit.ReactJSX,
  lib: ["lib.es2023.d.ts", "lib.dom.d.ts"],
  module: ts.ModuleKind.ESNext,
  moduleResolution: ts.ModuleResolutionKind.Bundler,
  noEmit: true,
  noImplicitAny: true,
  skipLibCheck: false,
  strict: true,
  target: ts.ScriptTarget.ES2023,
};
const program = ts.createProgram(sourceFiles, compilerOptions);
const diagnostics = ts.getPreEmitDiagnostics(program);
if (diagnostics.length > 0) {
  throw new Error(
    ts.formatDiagnosticsWithColorAndContext(diagnostics, {
      getCanonicalFileName: (file) => file,
      getCurrentDirectory: () => workRoot,
      getNewLine: () => "\n",
    })
  );
}

function sourceEvidence(root) {
  const imports = new Set();
  const messages = new Set();
  for (const file of walkFiles(root)) {
    if (!file.endsWith(".tsx")) {
      continue;
    }
    const text = fs.readFileSync(file, "utf8");
    const source = ts.createSourceFile(
      file,
      text,
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.TSX
    );
    const visit = (node) => {
      if (
        ts.isImportDeclaration(node) &&
        ts.isStringLiteral(node.moduleSpecifier)
      ) {
        const request = node.moduleSpecifier.text;
        if (request.startsWith("@wordpress/") || request.startsWith("react")) {
          imports.add(request);
        }
      }
      if (
        ts.isCallExpression(node) &&
        ts.isIdentifier(node.expression) &&
        node.expression.text === "__" &&
        node.arguments.length === 2 &&
        ts.isStringLiteral(node.arguments[0])
      ) {
        messages.add(node.arguments[0].text);
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
  return { imports: [...imports].sort(), messages: [...messages].sort() };
}

const evidence = sourceEvidence(workRoot);
assert.deepEqual(evidence, sourceEvidence(replayRoot));
assert.deepEqual(evidence.imports, [
  "@wordpress/components",
  "@wordpress/data",
  "@wordpress/editor",
  "@wordpress/element",
  "@wordpress/i18n",
  "@wordpress/plugins",
]);
assert.deepEqual(evidence.messages, [
  "A second set of eyes is now part of the runway.",
  "A typed publishing runway beside the work—not another settings maze.",
  "Before this ships",
  "Change pace",
  "Current pace",
  "Cycle publishing priority",
  "Publish without an editorial handoff.",
  "Require editorial review",
  "Todo Studio readiness",
]);

function parseAssetPhp(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  const match = text.match(
    /^<\?php return array\('dependencies' => array\((.*)\), 'version' => '([0-9a-f]{20})'\);$/
  );
  assert.ok(match, `${file} is not the closed official asset.php shape`);
  const dependencies = match[1]
    ? match[1].split(", ").map((value) => {
        const dependency = value.match(/^'([a-z0-9-]+)'$/);
        assert.ok(dependency, `invalid asset dependency ${value}`);
        return dependency[1];
      })
    : [];
  return { dependencies, version: match[2] };
}

const expectedExternalized = [...evidence.imports, "react/jsx-runtime"].sort();
const expectedDependencies = expectedExternalized
  .map((request) => {
    assert.ok(mappings.has(request), `profile does not map ${request}`);
    return mappings.get(request);
  })
  .sort();

function laneEvidence(root, lane) {
  const outputRoot = path.join(root, "build", lane);
  assert.deepEqual(fs.readdirSync(outputRoot).sort(), [
    "editor.asset.php",
    "editor.js",
    "editor.js.map",
    "externalized-dependencies.json",
  ]);
  const report = readJson(
    path.join(outputRoot, "externalized-dependencies.json")
  );
  assert.deepEqual(report, expectedExternalized, `${lane} externals drifted`);
  const asset = parseAssetPhp(path.join(outputRoot, "editor.asset.php"));
  assert.deepEqual(asset.dependencies, expectedDependencies);
  const bundle = fs.readFileSync(path.join(outputRoot, "editor.js"));
  const hash = webpack.util.createHash("md4");
  hash.update(bundle);
  assert.equal(asset.version, hash.digest("hex").slice(0, 20));
  const text = bundle.toString("utf8");
  for (const globalName of [
    "components",
    "data",
    "editor",
    "element",
    "i18n",
    "plugins",
  ]) {
    assert.ok(
      text.includes(`window["wp"]["${globalName}"]`) ||
        text.includes(`window.wp.${globalName}`),
      `${lane} did not externalize wp.${globalName}`
    );
  }
  assert.ok(text.includes("ReactJSXRuntime"));
  if (lane === "production") {
    for (const request of expectedExternalized) {
      assert.ok(!text.includes(request), `bundle retained ${request}`);
    }
  }
  for (const [relativePath, content] of relativeTree(outputRoot)) {
    assertNoMachinePath(`${lane}/${relativePath}`, content);
  }
  return {
    assetMetadataFile: "editor.asset.php",
    bundleSha256: sha256(bundle),
    dependencies: asset.dependencies,
    externalizedRequests: report,
    version: asset.version,
  };
}

const lanes = {
  development: laneEvidence(workRoot, "development"),
  production: laneEvidence(workRoot, "production"),
};
assert.deepEqual(lanes, {
  development: laneEvidence(replayRoot, "development"),
  production: laneEvidence(replayRoot, "production"),
});
for (const lane of ["development", "production"]) {
  assertSameTree(
    path.join(workRoot, "build", lane),
    path.join(replayRoot, "build", lane)
  );
}

const plan = {
  schemaVersion: 1,
  profileId: profile.profileId,
  editorCatalogRevision: profile.catalogRevision,
  plugin: {
    slug: "wordpresshx-sdk063-editor",
    name: "WordPressHx SDK-063 Editor Proof",
    version: "0.0.0",
    requiresWordPress: "7.0",
    requiresPhp: "7.4",
  },
  editor: {
    pluginName: "wordpresshx-todo-readiness",
    sidebarName: "todo-readiness",
    supportedPostType: "post",
  },
  source: {
    generatedTreeSha256,
    haxeEntry: "test/editor-plugin-fixture/src/sdk063/fixture/Main.hx",
    sourceImports: evidence.imports,
  },
  script: {
    assetMetadataFilename: "editor.asset.php",
    dependencies: lanes.production.dependencies,
    filename: "editor.js",
    handle: "wordpresshx-sdk063-editor",
    productionBundleSha256: lanes.production.bundleSha256,
    productionVersion: lanes.production.version,
  },
  translations: {
    domain: "wordpresshx-sdk063",
    finalHandle: "wordpresshx-sdk063-editor",
    messages: evidence.messages,
    relativePath: "languages",
  },
  lanes,
  nativePlan: {
    enqueueHook: "enqueue_block_editor_assets",
    registerApi: "wp_register_script",
    translationApi: "wp_set_script_translations",
  },
  policy: {
    manualJavaScriptEntryAllowed: false,
    privateOrExperimentalApisAllowed: false,
    postTypeGatingOwner: "typed-haxe-render-component",
  },
};
const planBytes = `${JSON.stringify(plan, null, 2)}\n`;
for (const root of [workRoot, replayRoot]) {
  fs.writeFileSync(path.join(root, "asset-plan.json"), planBytes);
}
console.log(
  JSON.stringify(
    {
      check: "wordpresshx-sdk063-editor-build-v1",
      dependencies: lanes.production.dependencies,
      generatedTreeSha256,
      outcome: "passed",
      productionBundleSha256: lanes.production.bundleSha256,
      publicWeakTypes: [],
      sourceImports: evidence.imports,
    },
    null,
    2
  )
);
