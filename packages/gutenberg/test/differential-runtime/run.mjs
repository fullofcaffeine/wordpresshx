import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { JSDOM } from "jsdom";
import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";

const bundlePath = process.argv[2];
assert.ok(bundlePath, "differential bundle path is required");

const { DifferentialApi } = await import(pathToFileURL(bundlePath).href);
assert.equal(typeof DifferentialApi, "function");
assert.equal(typeof DifferentialApi.summarize, "function");
assert.equal(typeof DifferentialApi.describe, "function");
assert.equal(typeof DifferentialApi.Counter, "function");

const summary = DifferentialApi.summarize("item", [3, 1, 3]);
const description = DifferentialApi.describe("SDK-035", summary);
const props = {
  initial: 2,
  step: 3,
  label: "Differential count"
};
const serverHtml = renderToStaticMarkup(
  React.createElement(DifferentialApi.Counter, props)
);

const dom = new JSDOM("<!doctype html><div id=\"root\"></div>", {
  url: "https://wordpresshx.invalid/"
});
globalThis.IS_REACT_ACT_ENVIRONMENT = true;
globalThis.window = dom.window;
globalThis.document = dom.window.document;
Object.defineProperty(globalThis, "navigator", {
  configurable: true,
  value: dom.window.navigator
});
globalThis.HTMLElement = dom.window.HTMLElement;
globalThis.Node = dom.window.Node;
globalThis.Event = dom.window.Event;
globalThis.MouseEvent = dom.window.MouseEvent;
globalThis.requestAnimationFrame = (callback) => setTimeout(callback, 0);
globalThis.cancelAnimationFrame = (handle) => clearTimeout(handle);

const container = document.querySelector("#root");
assert.ok(container);
const root = createRoot(container);
await act(async () => {
  root.render(React.createElement(DifferentialApi.Counter, props));
});

const readClient = () => {
  const section = container.querySelector("section");
  const output = container.querySelector(".differential-counter__value");
  const button = container.querySelector("button");
  assert.ok(section && output && button);
  return {
    count: section.getAttribute("data-state"),
    output: output.textContent,
    action: button.textContent,
    label: section.getAttribute("aria-label")
  };
};

const clientBefore = readClient();
await act(async () => {
  const button = container.querySelector("button");
  assert.ok(button);
  button.dispatchEvent(new dom.window.MouseEvent("click", {
    bubbles: true,
    cancelable: true
  }));
});
const clientAfter = readClient();
await act(async () => root.unmount());
dom.window.close();

console.log(JSON.stringify({
  summary,
  description,
  serverHtml,
  clientBefore,
  clientAfter
}));
