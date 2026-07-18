import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const bundlePath = process.argv[2];
assert.ok(bundlePath, "bundle path is required");

const module = await import(pathToFileURL(bundlePath).href);
assert.deepEqual(Object.keys(module), ["BrowserApi"]);

const api = new module.BrowserApi("Hello");
assert.equal(api.greet("Haxe"), "Hello, Haxe");
assert.equal(api.identity(42), 42);
assert.equal(api.nullableLabel(null), "none");

const signals = api.observeSignals();
assert.deepEqual(signals, {
  before: 7,
  after: 8,
  setupCount: 1
});

console.log(JSON.stringify({
  exports: Object.keys(module),
  greeting: api.greet("World"),
  identity: api.identity("typed"),
  nullable: api.nullableLabel(null),
  signals
}));
