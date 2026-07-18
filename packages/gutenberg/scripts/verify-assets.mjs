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
assert.equal(webpack.version, "5.108.4", "unexpected locked Webpack runtime");

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

function assertNoMachinePath(label, content) {
  const text = Buffer.isBuffer(content) ? content.toString("utf8") : content;
  const posixRoot = (...segments) => ["", ...segments, ""].join("/");
  const windowsRoot = (...segments) => ["", ...segments, ""].join("\\");
  const forbiddenPaths = new Set([
    posixRoot("Users"),
    posixRoot("home", "runner"),
    posixRoot("private", "var"),
    posixRoot("repo"),
    posixRoot("tooling"),
    windowsRoot("Users"),
    packageRoot,
    workRoot,
    replayRoot,
    toolingRoot,
    "wordpresshx-sdk033-build.",
    "wordpresshx-sdk033-replay.",
  ]);
  for (const forbidden of forbiddenPaths) {
    assert.ok(!text.includes(forbidden), `${label} leaks ${forbidden}`);
  }
}

const profile = readJson(
  path.join(
    packageRoot,
    "src/wordpress/hx/gutenberg/profile/wp70-release.browser-assets.json"
  )
);
const entryPlan = readJson(
  path.join(packageRoot, "test/assets-runtime/entry-plan.json")
);
const mappings = new Map(
  profile.mappings.map((mapping) => [mapping.request, mapping])
);

const directPackages = {
  "@babel/core": {
    version: "7.25.7",
    license: "MIT",
    repository: "github.com/babel/babel",
  },
  "@babel/plugin-transform-typescript": {
    version: "7.29.7",
    license: "MIT",
    repository: "github.com/babel/babel",
  },
  "@playwright/test": {
    version: "1.58.2",
    license: "Apache-2.0",
    repository: "github.com/microsoft/playwright",
  },
  "@types/react": {
    version: "18.3.27",
    license: "MIT",
    repository: "github.com/DefinitelyTyped/DefinitelyTyped",
  },
  "@types/react-dom": {
    version: "18.3.7",
    license: "MIT",
    repository: "github.com/DefinitelyTyped/DefinitelyTyped",
  },
  "@wordpress/components": {
    version: "32.2.0",
    license: "GPL-2.0-or-later",
    repository: "github.com/WordPress/gutenberg",
  },
  "@wordpress/dependency-extraction-webpack-plugin": {
    version: "6.40.0",
    license: "GPL-2.0-or-later",
    repository: "github.com/WordPress/gutenberg",
  },
  "@wordpress/element": {
    version: "6.40.0",
    license: "GPL-2.0-or-later",
    repository: "github.com/WordPress/gutenberg",
  },
  "@wordpress/i18n": {
    version: "6.13.0",
    license: "GPL-2.0-or-later",
    repository: "github.com/WordPress/gutenberg",
  },
  "@wordpress/scripts": {
    version: "31.5.0",
    license: "GPL-2.0-or-later",
    repository: "github.com/WordPress/gutenberg",
  },
  react: {
    version: "18.3.1",
    license: "MIT",
    repository: "github.com/facebook/react",
  },
  "react-dom": {
    version: "18.3.1",
    license: "MIT",
    repository: "github.com/facebook/react",
  },
  typescript: {
    version: "5.9.3",
    license: "Apache-2.0",
    repository: "github.com/microsoft/TypeScript",
  },
  webpack: {
    version: "5.108.4",
    license: "MIT",
    repository: "github.com/webpack/webpack",
  },
};

function installedPackage(name) {
  return readJson(path.join(toolingRoot, "node_modules", name, "package.json"));
}

for (const [name, expected] of Object.entries(directPackages)) {
  const installed = installedPackage(name);
  const repository =
    typeof installed.repository === "string"
      ? installed.repository
      : installed.repository?.url;
  assert.equal(installed.version, expected.version, `${name} version drifted`);
  assert.equal(installed.license, expected.license, `${name} license drifted`);
  assert.ok(
    repository?.includes(expected.repository),
    `${name} source repository drifted`
  );
}

const mappingSource = fs.readFileSync(
  path.join(
    toolingRoot,
    "node_modules/@wordpress/dependency-extraction-webpack-plugin/lib/util.js"
  )
);
assert.equal(
  sha256(mappingSource),
  profile.mappingSource.sha256,
  "installed official mapping source differs from the exact profile"
);

const ignoredGenerated = new Set([
  "asset-plan.json",
  "build",
  "node_modules",
  "wordpress-plugin",
]);
assertSameTree(workRoot, replayRoot, ignoredGenerated);
for (const [relativePath, content] of relativeTree(workRoot, ignoredGenerated)) {
  assertNoMachinePath(relativePath, content);
}
const generatedTreeSha256 = treeDigest(workRoot, ignoredGenerated);

function sourceEvidence(root) {
  const sourceRoot = path.join(root, "src");
  const imports = new Set();
  const messages = new Set();
  const domains = new Set();
  for (const file of walkFiles(sourceRoot)) {
    if (!/\.[cm]?[jt]sx?$/.test(file)) {
      continue;
    }
    const text = fs.readFileSync(file, "utf8");
    const source = ts.createSourceFile(
      file,
      text,
      ts.ScriptTarget.Latest,
      true,
      file.endsWith("x") ? ts.ScriptKind.TSX : ts.ScriptKind.TS
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
        node.arguments.every(ts.isStringLiteral)
      ) {
        messages.add(node.arguments[0].text);
        domains.add(node.arguments[1].text);
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
  return {
    imports: [...imports].sort(),
    messages: [...messages].sort(),
    domains: [...domains].sort(),
  };
}

const firstSourceEvidence = sourceEvidence(workRoot);
const replaySourceEvidence = sourceEvidence(replayRoot);
assert.deepEqual(firstSourceEvidence, replaySourceEvidence);
assert.deepEqual(firstSourceEvidence.imports, [
  "@wordpress/components",
  "@wordpress/element",
  "@wordpress/i18n",
]);
assert.deepEqual(firstSourceEvidence.domains, [entryPlan.textDomain]);
assert.deepEqual(firstSourceEvidence.messages, [
  "Bundle metadata, under proof.",
  "Inspect final dependencies",
]);

const browserManifest = readJson(path.join(workRoot, "browser-exports.json"));
assert.equal(browserManifest.schemaVersion, 1);
assert.equal(browserManifest.profileId, entryPlan.profileId);
assert.equal(browserManifest.compilerProfile, "strict-typescript-source");
assert.equal(browserManifest.entries.length, 1);
const browserExport = browserManifest.entries[0];
assert.equal(browserExport.stableExportId, entryPlan.browserExportId);
assert.equal(browserExport.generatedModule, "sdk033/fixture/EditorPanel");
assert.equal(browserExport.exportName, "EditorPanel");
assert.deepEqual(browserExport.profileCapabilityRefs, [
  "gutenberg.package.@wordpress/components",
  "gutenberg.package.@wordpress/i18n",
]);

const expectedExternalized = [
  ...firstSourceEvidence.imports,
  "react/jsx-runtime",
].sort();
const expectedDependencies = expectedExternalized
  .map((request) => {
    assert.ok(mappings.has(request), `profile does not map ${request}`);
    return mappings.get(request).handle;
  })
  .sort();
assert.deepEqual(expectedExternalized, [
  "@wordpress/components",
  "@wordpress/element",
  "@wordpress/i18n",
  "react/jsx-runtime",
]);
assert.deepEqual(expectedDependencies, [
  "react-jsx-runtime",
  "wp-components",
  "wp-element",
  "wp-i18n",
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

function laneEvidence(root, lane) {
  const outputRoot = path.join(root, "build", lane);
  const expectedFiles =
    lane === "development"
      ? [
          "editor.asset.php",
          "editor.js",
          "editor.js.map",
          "externalized-dependencies.json",
        ]
      : ["editor.asset.php", "editor.js", "externalized-dependencies.json"];
  assert.deepEqual(
    fs.readdirSync(outputRoot).sort(),
    expectedFiles,
    `${lane} output set drifted`
  );
  const report = readJson(
    path.join(outputRoot, "externalized-dependencies.json")
  );
  assert.deepEqual(report, expectedExternalized, `${lane} externals drifted`);
  const asset = parseAssetPhp(path.join(outputRoot, "editor.asset.php"));
  assert.deepEqual(
    asset.dependencies,
    expectedDependencies,
    `${lane} handles drifted`
  );
  const bundle = fs.readFileSync(path.join(outputRoot, "editor.js"));
  const hash = webpack.util.createHash("md4");
  hash.update(bundle);
  assert.equal(
    asset.version,
    hash.digest("hex").slice(0, 20),
    `${lane} asset version is not derived from final JS bytes`
  );
  const bundleText = bundle.toString("utf8");
  for (const globalName of ["components", "element", "i18n"]) {
    const developmentGlobal = `window[\"wp\"][\"${globalName}\"]`;
    const productionGlobal = `window.wp.${globalName}`;
    assert.ok(
      bundleText.includes(developmentGlobal) ||
        bundleText.includes(productionGlobal),
      `${lane} did not externalize wp.${globalName}`
    );
  }
  assert.ok(
    bundleText.includes("ReactJSXRuntime"),
    `${lane} did not externalize ReactJSXRuntime`
  );
  if (lane === "production") {
    for (const request of expectedExternalized) {
      assert.ok(
        !bundleText.includes(request),
        `production bundle retained package request ${request}`
      );
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

const firstLanes = {
  development: laneEvidence(workRoot, "development"),
  production: laneEvidence(workRoot, "production"),
};
const replayLanes = {
  development: laneEvidence(replayRoot, "development"),
  production: laneEvidence(replayRoot, "production"),
};
assert.deepEqual(firstLanes, replayLanes, "clean replay lane evidence drifted");
assert.deepEqual(
  firstLanes.development.dependencies,
  firstLanes.production.dependencies,
  "development and production dependency sets differ"
);
for (const lane of ["development", "production"]) {
  assertSameTree(
    path.join(workRoot, "build", lane),
    path.join(replayRoot, "build", lane)
  );
}

function makePlan() {
  return {
    schemaVersion: 1,
    profileId: entryPlan.profileId,
    entryId: entryPlan.entryId,
    plugin: entryPlan.plugin,
    source: {
      browserExportId: entryPlan.browserExportId,
      generatedModule: browserExport.generatedModule,
      generatedTreeSha256,
      sourceEntry: entryPlan.sourceEntry,
      sourceImports: firstSourceEvidence.imports,
    },
    script: {
      assetMetadataFilename: "editor.asset.php",
      dependencies: firstLanes.production.dependencies,
      filename: entryPlan.scriptFilename,
      handle: entryPlan.scriptHandle,
      productionBundleSha256: firstLanes.production.bundleSha256,
      productionVersion: firstLanes.production.version,
    },
    translations: {
      domain: entryPlan.textDomain,
      finalHandle: entryPlan.scriptHandle,
      messages: firstSourceEvidence.messages,
      relativePath: entryPlan.translationRelativePath,
    },
    lanes: firstLanes,
    nativePlan: {
      enqueueApi: "wp_enqueue_script",
      registerApi: "wp_register_script",
      translationApi: "wp_set_script_translations",
    },
    authority: {
      dependencyExtraction:
        "@wordpress/dependency-extraction-webpack-plugin@6.40.0",
      dependencySource: "final-bundle",
      developmentProductionDependencyParity: true,
      manualAssetPhpEditingAllowed: false,
    },
  };
}

const planBytes = `${JSON.stringify(makePlan(), null, 2)}\n`;
for (const root of [workRoot, replayRoot]) {
  fs.writeFileSync(path.join(root, "asset-plan.json"), planBytes);
}
assert.deepEqual(
  fs.readFileSync(path.join(workRoot, "asset-plan.json")),
  fs.readFileSync(path.join(replayRoot, "asset-plan.json")),
  "asset plan replay drifted"
);

console.log(
  JSON.stringify(
    {
      check: "wordpresshx-sdk033-final-assets-v1",
      dependencies: firstLanes.production.dependencies,
      developmentVersion: firstLanes.development.version,
      generatedTreeSha256,
      outcome: "passed",
      productionBundleSha256: firstLanes.production.bundleSha256,
      productionVersion: firstLanes.production.version,
      sourceImports: firstSourceEvidence.imports,
    },
    null,
    2
  )
);
