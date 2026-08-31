#!/usr/bin/env node
"use strict";

// This observer intentionally does not import the Python ABI model or generator.
// It uses the pinned TypeScript parser to challenge their JavaScript source view.
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const inputRoot = path.resolve(process.argv[2] || path.join(root, "fixtures/adoption-contract/inputs"));
const contractRoot = path.resolve(process.argv[3] || path.join(root, "fixtures/adoption-contract/contract"));
const ts = require(path.join(root, "packages/gutenberg/build-tooling/node_modules/typescript"));

const forbiddenBindings = new Set([
  "arguments", "await", "break", "case", "catch", "class", "const", "continue",
  "debugger", "default", "delete", "do", "else", "enum", "eval", "export",
  "extends", "false", "finally", "for", "function", "if", "implements", "import",
  "in", "instanceof", "interface", "let", "new", "null", "package", "private",
  "protected", "public", "return", "static", "super", "switch", "this", "throw",
  "true", "try", "typeof", "var", "void", "while", "with", "yield",
]);

function fail(message) {
  throw new Error(`independent JavaScript source observer: ${message}`);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function exported(node) {
  return Boolean(node.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword));
}

function sourceFunctions(sourceText) {
  const source = ts.createSourceFile(
    "index.js",
    sourceText,
    ts.ScriptTarget.ES2022,
    true,
    ts.ScriptKind.JS,
  );
  if (source.parseDiagnostics.length !== 0) {
    const diagnostic = source.parseDiagnostics[0];
    fail(`module syntax is invalid: ${ts.flattenDiagnosticMessageText(diagnostic.messageText, " ")}`);
  }
  const functions = [];
  for (const statement of source.statements) {
    if (!ts.isFunctionDeclaration(statement) || !exported(statement)) {
      continue;
    }
    const modifierKinds = (statement.modifiers || []).map((modifier) => modifier.kind);
    if (
      modifierKinds.length !== 1
      || modifierKinds[0] !== ts.SyntaxKind.ExportKeyword
      || statement.asteriskToken
    ) {
      fail("exported functions must be named, non-default, synchronous, and non-generator declarations");
    }
    if (!statement.name || !ts.isIdentifier(statement.name)) {
      fail("an exported function has no plain identifier name");
    }
    const names = [];
    for (const parameter of statement.parameters) {
      if (
        !ts.isIdentifier(parameter.name)
        || parameter.dotDotDotToken
        || parameter.initializer
        || parameter.questionToken
        || parameter.modifiers?.length
      ) {
        fail(`unsupported parameter form in ${statement.name.text}`);
      }
      const name = parameter.name.text;
      if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) || forbiddenBindings.has(name)) {
        fail(`unsupported parameter identifier ${name} in ${statement.name.text}`);
      }
      if (parameter.getFullText(source).trim() !== name) {
        fail(`comments or unsupported tokens surround parameter ${name} in ${statement.name.text}`);
      }
      if (names.includes(name)) {
        fail(`duplicate parameter ${name} in ${statement.name.text}`);
      }
      names.push(name);
    }
    functions.push({ name: statement.name.text, parameters: names });
  }
  functions.sort((left, right) => left.name.localeCompare(right.name));
  return functions;
}

function main() {
  const source = fs.readFileSync(path.join(inputRoot, "index.js"), "utf8");
  const observed = sourceFunctions(source);
  const contract = readJson(path.join(contractRoot, "acme-calendar.contract.json"));
  const capability = readJson(path.join(contractRoot, "acme-calendar.capability.json"));
  const generatedHaxe = fs.readFileSync(
    path.join(
      contractRoot,
      "generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx",
    ),
    "utf8",
  );

  const bindings = contract.bindings
    .filter((binding) => binding.target === "javascript" && binding.kind !== "exported-value")
    .map((binding) => ({
      id: binding.id,
      name: binding.nativeName.split(".").at(-1),
      nativeName: binding.nativeName,
      parameters: binding.parameters.map((parameter) => parameter.nativeName),
    }))
    .sort((left, right) => left.name.localeCompare(right.name));
  const expectedFunctions = bindings.map(({ name, parameters }) => ({ name, parameters }));
  if (JSON.stringify(observed) !== JSON.stringify(expectedFunctions)) {
    fail("runtime export formals differ from the adoption contract");
  }

  const browserCapabilities = capability.capabilities.filter((entry) => entry.target === "javascript");
  if (browserCapabilities.length !== 1) {
    fail("the capability set must contain one JavaScript capability");
  }
  const probe = browserCapabilities[0].probe;
  if (
    JSON.stringify(probe.requiredBindings) !== JSON.stringify(bindings.map((binding) => binding.id))
    || JSON.stringify(probe.requiredNativeSymbols) !== JSON.stringify(bindings.map((binding) => binding.nativeName))
  ) {
    fail("capability bindings or native symbols differ from parsed module exports");
  }

  const compactHaxe = generatedHaxe.replace(/\s+/g, " ");
  for (const binding of bindings) {
    if (!compactHaxe.includes(`"${binding.id}"`)) {
      fail(`generated Haxe omits browser binding ${binding.id}`);
    }
  }
  if (!compactHaxe.includes(`"${browserCapabilities[0].id}"`)
      || !compactHaxe.includes(`"${probe.executableClosureSha256}"`)
      || !compactHaxe.includes("function formatLabel(count:")
      || !compactHaxe.includes("function renderBadge(props:")) {
    fail("generated Haxe browser capability or facade differs from the admitted module surface");
  }

  process.stdout.write(`${JSON.stringify({ functions: observed, outcome: "passed" })}\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : "independent JavaScript source observer failed"}\n`);
  process.exit(1);
}
