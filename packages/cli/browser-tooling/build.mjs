import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { build, version as esbuildVersion } from "esbuild";

const [generatedRootValue, outputRootValue] = process.argv.slice(2);
assert.ok(generatedRootValue, "generated Genes root is required");
assert.ok(outputRootValue, "bundle output root is required");

const generatedRoot = fs.realpathSync(generatedRootValue);
const outputRoot = path.resolve(outputRootValue);
const twoStageRoot = path.join(outputRoot, "two-stage-input");
const entry = path.join(generatedRoot, "index.ts");
const fixtureMapPath = path.join(
  generatedRoot,
  "sdk034/fixture/Main.ts.map"
);

assert.equal(process.version, "v22.17.0", "unexpected Node runtime");
assert.equal(
  execFileSync("npm", ["--version"], { encoding: "utf8" }).trim(),
  "10.9.2",
  "unexpected npm runtime"
);
assert.equal(esbuildVersion, "0.27.2", "unexpected esbuild runtime");
assert.ok(fs.statSync(entry).isFile(), "Genes entry is missing");
assert.ok(fs.statSync(fixtureMapPath).isFile(), "Genes fixture map is missing");

function assertNoMachinePath(label, value) {
  for (const marker of [
    "/Us" + "ers/",
    "/ho" + "me/runner/",
    "workspace/code",
    "\\Us" + "ers\\",
  ]) {
    assert.ok(!value.includes(marker), `${label} leaks machine path ${marker}`);
  }
}

function validateGenesMap() {
  const source = fs.readFileSync(fixtureMapPath, "utf8");
  const map = JSON.parse(source);
  assert.deepEqual(
    Object.keys(map).sort(),
    ["file", "mappings", "names", "sourceRoot", "sources", "version"],
    "Genes map is not a closed regular Source Map v3 document"
  );
  assert.equal(map.version, 3);
  assert.equal(map.file, "Main.ts");
  assert.equal(map.sourceRoot, "");
  assert.ok(map.mappings.length > 0, "Genes map has no mappings");
  assert.ok(map.sources.length >= 1, "Genes map has no sources");
  assert.ok(
    map.sources.some((sourcePath) =>
      sourcePath.endsWith(
        "test/browser-source-correlation/src/sdk034/fixture/Main.hx"
      )
    ),
    "Genes map lost the deliberate Haxe fixture"
  );
  assert.ok(!("sourcesContent" in map), "Genes map unexpectedly retained sources");
  assertNoMachinePath("Genes map", source);
}

function copyGeneratedTree(sourceRoot, destinationRoot) {
  fs.mkdirSync(destinationRoot, { recursive: true });
  for (const entryValue of fs.readdirSync(sourceRoot, { withFileTypes: true })) {
    if (entryValue.name.startsWith(".genes-output-index") || entryValue.name === path.basename(outputRoot)) {
      continue;
    }
    const sourcePath = path.join(sourceRoot, entryValue.name);
    const destinationPath = path.join(destinationRoot, entryValue.name);
    if (entryValue.isDirectory()) {
      copyGeneratedTree(sourcePath, destinationPath);
    } else if (entryValue.isFile() && entryValue.name.endsWith(".ts")) {
      const source = fs.readFileSync(sourcePath, "utf8");
      const finalized = source.replace(/\n?\/\/# sourceMappingURL=[^\n]+\n?$/u, "\n");
      fs.writeFileSync(destinationPath, finalized, "utf8");
    }
  }
}

async function bundle(entryPoint, outfile, minify) {
  await build({
    absWorkingDir: path.dirname(entryPoint),
    entryPoints: [entryPoint],
    outfile,
    bundle: true,
    charset: "utf8",
    format: "esm",
    legalComments: "none",
    logLevel: "silent",
    minify,
    platform: "browser",
    sourcemap: "external",
    sourcesContent: false,
    target: ["es2022"],
    treeShaking: true,
  });
  const source = fs.readFileSync(outfile, "utf8");
  const finalized = source.replace(/\n?\/\/# sourceMappingURL=[^\n]+\n?$/u, "\n");
  fs.writeFileSync(outfile, finalized, "utf8");
  assertNoMachinePath(path.basename(outfile), finalized);
}

validateGenesMap();
fs.mkdirSync(outputRoot, { recursive: true });
copyGeneratedTree(generatedRoot, twoStageRoot);

await bundle(entry, path.join(outputRoot, "development.js"), false);
await bundle(entry, path.join(outputRoot, "production.js"), true);
await bundle(
  path.join(twoStageRoot, "index.ts"),
  path.join(outputRoot, "two-stage.js"),
  true
);

fs.writeFileSync(
  path.join(outputRoot, "toolchain.json"),
  `${JSON.stringify({
    schemaVersion: 1,
    node: process.version.slice(1),
    npm: "10.9.2",
    esbuild: esbuildVersion,
    genesLayerValidatedIndependently: true,
  })}\n`,
  "utf8"
);

console.log(
  "SDK-034 browser bundles built: independent Genes map, composed development/production, retained two-stage fallback"
);
