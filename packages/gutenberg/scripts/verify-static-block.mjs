import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import process from "node:process";

const require = createRequire(path.join(process.cwd(), "package.json"));
const ts = require("typescript");
const webpack = require("webpack");

const [
  packageRoot,
  workRoot,
  replayRoot,
  workPlugin,
  replayPlugin,
  evidenceOutput,
] = process.argv.slice(2);
for (const [label, value] of Object.entries({
  packageRoot,
  workRoot,
  replayRoot,
  workPlugin,
  replayPlugin,
  evidenceOutput,
})) {
  assert.ok(value, `${label} is required`);
}

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
    ]),
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
      `${relativePath} drifted`,
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
    "wordpresshx-sdk061-build.",
    "wordpresshx-sdk061-replay.",
  ]) {
    assert.ok(!text.includes(forbidden), `${label} leaks ${forbidden}`);
  }
}

const profile = readJson(
  path.join(
    packageRoot,
    "src/wordpress/hx/gutenberg/profile/wp70-release.static-block.browser-hxx.json",
  ),
);
const expected = readJson(
  path.join(packageRoot, "test/expected/static-block.json"),
);
const workPlanPath = path.join(workRoot, "static-block-plan.json");
const replayPlanPath = path.join(replayRoot, "static-block-plan.json");
const workPlan = readJson(workPlanPath);
const replayPlan = readJson(replayPlanPath);
assert.deepEqual(workPlan, expected.browserPlan);
assert.deepEqual(replayPlan, expected.browserPlan);

const workMetadataPath = path.join(workPlugin, "blocks/callout/block.json");
const replayMetadataPath = path.join(replayPlugin, "blocks/callout/block.json");
const workMetadata = readJson(workMetadataPath);
const replayMetadata = readJson(replayMetadataPath);
assert.deepEqual(workMetadata, expected.blockMetadata);
assert.deepEqual(replayMetadata, expected.blockMetadata);
assert.equal(workPlan.blocks[0].name, workMetadata.name);
assert.deepEqual(workPlan.blocks[0].attributes, workMetadata.attributes);
assert.equal(workPlan.blocks[0].deprecations.length, 1);
assert.equal(workPlan.blocks[0].deprecations[0].version, "0.9.0");

const generatedIgnored = new Set([
  "build",
  "node_modules",
  "package.json",
  "runtime-bundle",
  "runtime-probe.tsx",
  "runtime-setup.js",
  "serialization-evidence.json",
]);
assertSameTree(workRoot, replayRoot, generatedIgnored);
const generatedTreeSha256 = treeDigest(workRoot, generatedIgnored);
for (const [relativePath, content] of relativeTree(
  workRoot,
  generatedIgnored,
)) {
  assertNoMachinePath(relativePath, content);
}

const generatedMainPath = path.join(workRoot, "sdk061/fixture/Main.tsx");
const generatedBlockPath = path.join(
  workRoot,
  "sdk061/fixture/CalloutBlock.tsx",
);
const generatedMain = fs.readFileSync(generatedMainPath, "utf8");
const generatedBlock = fs.readFileSync(generatedBlockPath, "utf8");
for (const required of [
  'from "@wordpress/blocks"',
  'registerBlockType("wordpresshx/callout"',
  '"deprecated": [{"attributes": {"text"',
  '"migrate": CalloutBlock.migrate',
  '"isEligible": CalloutBlock.legacyIsEligible',
]) {
  assert.ok(
    generatedMain.includes(required),
    `registration omitted ${required}`,
  );
}
for (const required of [
  'from "@wordpress/block-editor"',
  "readonly setAttributes: (next: Partial<CalloutAttributes>) => void",
  'props.setAttributes({"label": next})',
  'props.setAttributes({"message": next})',
  "useBlockProps.save",
  "static migrate(attributes:",
]) {
  assert.ok(
    generatedBlock.includes(required),
    `block output omitted ${required}`,
  );
}
const saveSection = generatedBlock.slice(
  generatedBlock.indexOf("static save("),
  generatedBlock.indexOf("static legacySave("),
);
assert.ok(
  !saveSection.includes("setAttributes"),
  "save leaked an editor setter",
);
for (const forbidden of [
  "dangerouslySetInnerHTML",
  "__experimental",
  "__unstable",
  "Register.unsafeCast",
]) {
  assert.ok(!`${generatedMain}\n${generatedBlock}`.includes(forbidden));
}

const ownedGeneratedFiles = walkFiles(workRoot).filter((file) =>
  ["/sdk061/", "/wordpress/hx/gutenberg/block/"].some((segment) =>
    file.split(path.sep).join("/").includes(segment),
  ),
);
for (const file of ownedGeneratedFiles) {
  if (!file.endsWith(".tsx")) continue;
  const source = ts.createSourceFile(
    file,
    fs.readFileSync(file, "utf8"),
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TSX,
  );
  const weak = [];
  const visit = (node) => {
    if (
      node.kind === ts.SyntaxKind.AnyKeyword ||
      node.kind === ts.SyntaxKind.UnknownKeyword
    ) {
      weak.push(source.getLineAndCharacterOfPosition(node.getStart(source)));
    }
    ts.forEachChild(node, visit);
  };
  visit(source);
  assert.deepEqual(weak, [], `${path.relative(workRoot, file)} has weak types`);
}

const sourceFiles = walkFiles(workRoot, generatedIgnored).filter(
  (file) => file.endsWith(".tsx") || file.endsWith("setup.d.ts"),
);
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
    }),
  );
}

const mainMap = readJson(`${generatedMainPath}.map`);
const blockMap = readJson(`${generatedBlockPath}.map`);
assert.ok(
  mainMap.sources.some((source) =>
    source.endsWith("test/static-block-fixture/src/sdk061/fixture/Main.hx"),
  ),
);
assert.ok(
  blockMap.sources.some((source) =>
    source.endsWith(
      "test/static-block-fixture/src/sdk061/fixture/CalloutBlock.hx",
    ),
  ),
);

function parseAssetPhp(file) {
  const text = fs.readFileSync(file, "utf8").trim();
  const match = text.match(
    /^<\?php return array\('dependencies' => array\((.*)\), 'version' => '([0-9a-f]{20})'\);$/,
  );
  assert.ok(match, `${file} is not the closed official asset shape`);
  return {
    dependencies: match[1]
      ? match[1].split(", ").map((entry) => entry.slice(1, -1))
      : [],
    version: match[2],
  };
}

function laneEvidence(root, lane) {
  const outputRoot = path.join(root, "build", lane);
  assert.deepEqual(fs.readdirSync(outputRoot).sort(), [
    "editor.asset.php",
    "editor.js",
    "editor.js.map",
    "externalized-dependencies.json",
  ]);
  const externalized = readJson(
    path.join(outputRoot, "externalized-dependencies.json"),
  );
  assert.deepEqual(externalized, [
    "@wordpress/block-editor",
    "@wordpress/blocks",
    "react/jsx-runtime",
  ]);
  const asset = parseAssetPhp(path.join(outputRoot, "editor.asset.php"));
  assert.deepEqual(asset.dependencies, [
    "react-jsx-runtime",
    "wp-block-editor",
    "wp-blocks",
  ]);
  const bundle = fs.readFileSync(path.join(outputRoot, "editor.js"));
  const versionHash = webpack.util.createHash("md4");
  versionHash.update(bundle);
  assert.equal(asset.version, versionHash.digest("hex").slice(0, 20));
  for (const [relativePath, content] of relativeTree(outputRoot)) {
    assertNoMachinePath(`${lane}/${relativePath}`, content);
  }
  return {
    assetSha256: sha256(
      fs.readFileSync(path.join(outputRoot, "editor.asset.php")),
    ),
    bundleSha256: sha256(bundle),
    dependencies: asset.dependencies,
    externalized,
    version: asset.version,
  };
}

const lanes = {
  development: laneEvidence(workRoot, "development"),
  production: laneEvidence(workRoot, "production"),
};
assert.deepEqual(lanes.development, laneEvidence(replayRoot, "development"));
assert.deepEqual(lanes.production, laneEvidence(replayRoot, "production"));
assertSameTree(path.join(workRoot, "build"), path.join(replayRoot, "build"));
assertSameTree(workPlugin, replayPlugin);

const workSerialization = readJson(
  path.join(workRoot, "serialization-evidence.json"),
);
const replaySerialization = readJson(
  path.join(replayRoot, "serialization-evidence.json"),
);
assert.deepEqual(workSerialization, replaySerialization);
for (const key of [
  "currentBytes",
  "defaultBytes",
  "legacyBytes",
  "migratedBytes",
]) {
  assert.equal(workSerialization[key], expected.serialization[key]);
}
assert.equal(workSerialization.outcome, "passed");
assert.equal(workSerialization.replayByteExact, true);

const finalEvidence = {
  schemaVersion: 1,
  check: "wordpresshx-sdk061-static-block-compiler-v1",
  profileId: profile.profileId,
  catalogRevision: profile.catalogRevision,
  blockName: workMetadata.name,
  generatedTreeSha256,
  browserPlanSha256: sha256(fs.readFileSync(workPlanPath)),
  blockMetadataSha256: sha256(fs.readFileSync(workMetadataPath)),
  pluginTreeSha256: treeDigest(workPlugin),
  deprecationVersions: workPlan.blocks[0].deprecations.map(
    ({ version }) => version,
  ),
  compileNegativeFixtures: 6,
  serialization: workSerialization,
  lanes,
  policy: workPlan.policy,
  outcome: "passed",
};
fs.writeFileSync(evidenceOutput, `${JSON.stringify(finalEvidence, null, 2)}\n`);
console.log(fs.readFileSync(evidenceOutput, "utf8"));
