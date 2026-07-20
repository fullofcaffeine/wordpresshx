import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";

const [generatedRoot, metadataPath, planPath, outputPath] =
  process.argv.slice(2);
for (const [label, value] of Object.entries({
  generatedRoot,
  metadataPath,
  planPath,
  outputPath,
})) {
  assert.ok(value, `${label} is required`);
}

const require = createRequire(path.join(process.cwd(), "package.json"));
const webpack = require("webpack");
const babelLoader = require.resolve("babel-loader");
const scriptsRequire = createRequire(
  require.resolve("@wordpress/scripts/package.json"),
);
const babelPreset = scriptsRequire.resolve("@wordpress/babel-preset-default");
const transformTypeScript = require.resolve(
  "@babel/plugin-transform-typescript",
);

const setupPath = path.join(generatedRoot, "runtime-setup.js");
const probePath = path.join(generatedRoot, "runtime-probe.tsx");
const bundleRoot = path.join(generatedRoot, "runtime-bundle");
const bundlePath = path.join(bundleRoot, "probe.cjs");

fs.writeFileSync(
  setupPath,
  `const { JSDOM } = require("jsdom");
const dom = new JSDOM("<!doctype html><html><body></body></html>", { url: "http://localhost" });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, "navigator", {
  configurable: true,
  value: dom.window.navigator,
});
globalThis.Node = dom.window.Node;
globalThis.Element = dom.window.Element;
globalThis.HTMLElement = dom.window.HTMLElement;
globalThis.DOMParser = dom.window.DOMParser;
globalThis.MutationObserver = dom.window.MutationObserver;
globalThis.File = dom.window.File;
globalThis.Blob = dom.window.Blob;
globalThis.getComputedStyle = dom.window.getComputedStyle;
`,
  "utf8",
);

fs.writeFileSync(
  probePath,
  `import fs from "node:fs";
import {
  createBlock,
  parse,
  registerBlockType,
  serialize,
  unregisterBlockType,
} from "@wordpress/blocks";
import { CalloutBlock } from "./sdk061/fixture/CalloutBlock";

const metadata = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const plan = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const oldSchema = plan.blocks[0].deprecations[0].attributes;
const deprecated = [{
  attributes: oldSchema,
  save: CalloutBlock.legacySave,
  migrate: CalloutBlock.migrate,
  isEligible: CalloutBlock.legacyIsEligible,
}];
const registered = registerBlockType(metadata, {
  edit: CalloutBlock.edit,
  save: CalloutBlock.save,
  deprecated,
});
if (registered === undefined) throw new Error("static block registration failed");

const current = createBlock("wordpresshx/callout", {
  label: "SHIP NOTE",
  message: "Typed bytes survive.",
});
const serializedCurrent = serialize([current]);
const parsedCurrent = parse(serializedCurrent)[0];
const serializedReplay = serialize([parsedCurrent]);

const missingDefault = createBlock("wordpresshx/callout", {
  message: "Defaulted label.",
});
const serializedDefault = serialize([missingDefault]);

const legacyBytes = '<!-- wp:wordpresshx/callout -->\\n<div class="wp-block-wordpresshx-callout wphx-callout-legacy"><p class="wphx-callout__message">Legacy bytes.</p></div>\\n<!-- /wp:wordpresshx/callout -->';
const parsedLegacy = parse(legacyBytes)[0];
const migratedBytes = serialize([parsedLegacy]);

const removed = unregisterBlockType("wordpresshx/callout");
if (removed === undefined) throw new Error("static block unregister failed");

process.stdout.write("\\nSDK061_RESULT=" + JSON.stringify({
  current: {
    attributes: parsedCurrent.attributes,
    isValid: parsedCurrent.isValid,
    serialized: serializedCurrent,
    replay: serializedReplay,
  },
  defaults: {
    attributes: missingDefault.attributes,
    serialized: serializedDefault,
  },
  legacy: {
    input: legacyBytes,
    attributes: parsedLegacy.attributes,
    isValid: parsedLegacy.isValid,
    migrated: migratedBytes,
  },
}, null, 2));
`,
  "utf8",
);

const configuration = {
  mode: "production",
  target: "node",
  devtool: "source-map",
  entry: [setupPath, probePath],
  output: {
    path: bundleRoot,
    filename: "probe.cjs",
    library: { type: "commonjs2" },
  },
  resolve: {
    extensions: [".tsx", ".ts", ".mjs", ".js", ".json"],
    fullySpecified: false,
  },
  module: {
    rules: [
      {
        test: /\.m?js$/,
        resolve: { fullySpecified: false },
      },
      {
        test: /\.tsx?$/,
        use: {
          loader: babelLoader,
          options: {
            presets: [babelPreset],
            plugins: [
              [
                transformTypeScript,
                { allExtensions: true, allowDeclareFields: true, isTSX: true },
              ],
            ],
          },
        },
      },
    ],
  },
};

await new Promise((resolve, reject) => {
  webpack(configuration, (error, stats) => {
    if (error) {
      reject(error);
      return;
    }
    if (stats?.hasErrors()) {
      reject(new Error(stats.toString({ all: false, errors: true })));
      return;
    }
    resolve();
  });
});

const raw = execFileSync(
  process.execPath,
  [bundlePath, metadataPath, planPath],
  {
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
  },
);
const resultMarker = "SDK061_RESULT=";
const resultOffset = raw.lastIndexOf(resultMarker);
assert.notEqual(resultOffset, -1, "runtime probe omitted its result marker");
const result = JSON.parse(raw.slice(resultOffset + resultMarker.length));
assert.deepEqual(result.current.attributes, {
  label: "SHIP NOTE",
  message: "Typed bytes survive.",
});
assert.equal(result.current.isValid, true);
assert.equal(result.current.serialized, result.current.replay);
assert.deepEqual(result.defaults.attributes, {
  label: "NOTE",
  message: "Defaulted label.",
});
assert.equal(result.legacy.input.includes("wphx-callout-legacy"), true);
assert.deepEqual(result.legacy.attributes, {
  label: "NOTE",
  message: "Legacy bytes.",
});
assert.equal(result.legacy.isValid, true);
assert.equal(result.legacy.migrated.includes("wphx-callout-legacy"), false);
assert.equal(result.legacy.migrated.includes("<aside"), true);

fs.writeFileSync(
  outputPath,
  `${JSON.stringify(
    {
      check: "wordpresshx-sdk061-native-gutenberg-serialization-v1",
      currentBytes: result.current.serialized,
      defaultBytes: result.defaults.serialized,
      legacyBytes: result.legacy.input,
      migratedBytes: result.legacy.migrated,
      outcome: "passed",
      parser: "@wordpress/blocks 15.13.0",
      replayByteExact: true,
    },
    null,
    2,
  )}\n`,
  "utf8",
);
console.log(fs.readFileSync(outputPath, "utf8"));
