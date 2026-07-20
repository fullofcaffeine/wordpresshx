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
assert.equal(process.version, "v22.17.0");
assert.equal(
  execFileSync("npm", ["--version"], { encoding: "utf8" }).trim(),
  "10.9.2"
);
assert.equal(ts.version, "5.9.3");
assert.equal(webpack.version, "5.108.4");

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const sha256 = (value) => createHash("sha256").update(value).digest("hex");

function walkFiles(root, ignored = new Set()) {
  const output = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) output.push(...walkFiles(fullPath, ignored));
    else if (entry.isFile()) output.push(fullPath);
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
    "wordpresshx-sdk064-build.",
    "wordpresshx-sdk064-replay.",
  ]) {
    assert.ok(!text.includes(forbidden), `${label} leaks ${forbidden}`);
  }
}

const profile = readJson(
  path.join(
    packageRoot,
    "src/wordpress/hx/gutenberg/profile/wp70-release.data-store.browser-hxx.json"
  )
);
assert.equal(profile.profileId, "wp70-release");
assert.equal(profile.catalogId, "data-store");
const mappings = new Map(
  profile.mappings.map(({ request, handle }) => [request, handle])
);

const ignoredGenerated = new Set(["asset-plan.json", "build", "node_modules"]);
assertSameTree(workRoot, replayRoot, ignoredGenerated);
for (const [relativePath, content] of relativeTree(workRoot, ignoredGenerated)) {
  assertNoMachinePath(relativePath, content);
}
const generatedTreeSha256 = treeDigest(workRoot, ignoredGenerated);

const generatedMainPath = path.join(workRoot, "sdk064/fixture/Main.tsx");
const generatedStorePath = path.join(workRoot, "sdk064/fixture/TodoStore.tsx");
const generatedDomainPath = path.join(workRoot, "sdk064/fixture/TodoDomain.tsx");
const generatedEntryPath = path.join(workRoot, "editor.tsx");
const generatedMain = fs.readFileSync(generatedMainPath, "utf8");
const generatedStore = fs.readFileSync(generatedStorePath, "utf8");
const generatedDomain = fs.readFileSync(generatedDomainPath, "utf8");
const generatedEntry = fs.readFileSync(generatedEntryPath, "utf8");

for (const required of [
  "createReduxStore(TodoStore.key",
  "register(TodoStore.store)",
  "select(TodoStore.store).getState()",
  "subscribe(function ()",
]) {
  assert.ok(generatedStore.includes(required), `store omitted ${required}`);
}
for (const required of [
  "useDispatch(TodoStore.store)",
  "useSelect(function",
  "dispatch(TodoStore.store).dispatchAction",
  "<Main.TodoPanel />",
  'data-testid="wphx-todo-data-sidebar"',
  "commands.rehearseSync(shouldSucceed)",
]) {
  assert.ok(generatedMain.includes(required), `UI omitted ${required}`);
}
for (const required of [
  "export type TodoState",
  "export type TodoAction",
  "static reduce(state: TodoState, action: TodoAction): TodoState",
  "'toggle-task' | 'toggle-review' | 'cycle-priority'",
  "'offline-rehearsal' | 'preview-synchronized'",
]) {
  assert.ok(generatedDomain.includes(required), `domain omitted ${required}`);
}
assert.ok(generatedEntry.includes("Main.main()"), "entry omitted Main.main()");
for (const forbidden of [
  "__experimental",
  "__unstable",
  "dangerouslySetInnerHTML",
  "Register.unsafeCast",
]) {
  assert.ok(
    !`${generatedMain}\n${generatedStore}\n${generatedDomain}`.includes(forbidden),
    `generated source retained ${forbidden}`
  );
}

const ownedGeneratedFiles = walkFiles(workRoot).filter((file) =>
  ["/sdk064/", "/wordpress/hx/gutenberg/data/"].some((segment) =>
    file.split(path.sep).join("/").includes(segment)
  )
);
for (const file of ownedGeneratedFiles) {
  if (!file.endsWith(".tsx")) continue;
  const source = ts.createSourceFile(
    file,
    fs.readFileSync(file, "utf8"),
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
    source.endsWith("test/data-store-fixture/src/sdk064/fixture/Main.hx")
  ),
  "source map does not point to the Haxe data-store fixture"
);

const sourceFiles = walkFiles(workRoot).filter((file) => file.endsWith(".tsx"));
const program = ts.createProgram(sourceFiles, {
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
});
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
    if (!file.endsWith(".tsx")) continue;
    const source = ts.createSourceFile(
      file,
      fs.readFileSync(file, "utf8"),
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
  "@wordpress/i18n",
  "@wordpress/plugins",
]);
assert.deepEqual(evidence.messages, [
  "A second set of eyes is part of this run.",
  "A tiny board with a real spine.",
  "Change priority",
  "Complete ",
  "Cycle run priority",
  "Every click crosses a closed Haxe action, a pure reducer, and WordPress’ own reactive registry.",
  "No handoff is required yet.",
  "Offline rehearsal: no task data was lost.",
  "Preview synchronized through the native registry.",
  "Rehearse an asynchronous save without leaving the editor.",
  "Rehearse preview synchronization",
  "Rehearse sync",
  "Reopen ",
  "Require editorial review",
  "Retry preview synchronization",
  "Retry sync",
  "Run priority",
  "Sending the typed command…",
  "Todo data-store lab",
  "tasks remain",
]);

function parseAssetPhp(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  const match = text.match(
    /^<\?php return array\('dependencies' => array\((.*)\), 'version' => '([0-9a-f]{20})'\);$/
  );
  assert.ok(match, `${file} is not the closed official asset shape`);
  const dependencies = match[1]
    ? match[1].split(", ").map((value) => {
        const dependency = value.match(/^'([a-z0-9-]+)'$/);
        assert.ok(dependency, `invalid dependency ${value}`);
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
  const report = readJson(path.join(outputRoot, "externalized-dependencies.json"));
  assert.deepEqual(report, expectedExternalized);
  const asset = parseAssetPhp(path.join(outputRoot, "editor.asset.php"));
  assert.deepEqual(asset.dependencies, expectedDependencies);
  const bundle = fs.readFileSync(path.join(outputRoot, "editor.js"));
  const hash = webpack.util.createHash("md4");
  hash.update(bundle);
  assert.equal(asset.version, hash.digest("hex").slice(0, 20));
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
  dataCatalogRevision: profile.catalogRevision,
  plugin: {
    slug: "wordpresshx-sdk064-data-store",
    name: "WordPressHx SDK-064 Data Store Lab",
    version: "0.0.0",
    requiresWordPress: "7.0",
    requiresPhp: "7.4",
  },
  editor: {
    pluginName: "wordpresshx-todo-data-lab",
    sidebarName: "todo-data-lab",
    supportedPostType: "post",
  },
  dataStore: {
    key: "wordpresshx/todo-studio-lab",
    actionTypeCount: 6,
    stateFields: [
      "priority",
      "reviewRequired",
      "revision",
      "syncResult",
      "syncStatus",
      "tasks",
    ],
    nativeApis: [
      "createReduxStore",
      "dispatch",
      "register",
      "select",
      "subscribe",
      "useDispatch",
      "useSelect",
    ],
  },
  source: {
    generatedTreeSha256,
    haxeEntry: "test/data-store-fixture/src/sdk064/fixture/Main.hx",
    sourceImports: evidence.imports,
  },
  script: {
    assetMetadataFilename: "editor.asset.php",
    dependencies: lanes.production.dependencies,
    filename: "editor.js",
    handle: "wordpresshx-sdk064-data-store",
    productionBundleSha256: lanes.production.bundleSha256,
    productionVersion: lanes.production.version,
  },
  translations: {
    domain: "wordpresshx-sdk064",
    finalHandle: "wordpresshx-sdk064-data-store",
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
    weakOwnedGeneratedTypesAllowed: false,
  },
};
const planBytes = `${JSON.stringify(plan, null, 2)}\n`;
for (const root of [workRoot, replayRoot]) {
  fs.writeFileSync(path.join(root, "asset-plan.json"), planBytes);
}
console.log(
  JSON.stringify(
    {
      check: "wordpresshx-sdk064-data-store-build-v1",
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
