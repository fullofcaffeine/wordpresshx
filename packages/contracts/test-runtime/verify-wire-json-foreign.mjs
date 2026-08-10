import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const generatedRoot = process.argv[2];
assert.ok(generatedRoot, "generated Genes root is required");

const contractsRoot = resolve(generatedRoot, "wordpress/hx/contracts");
const { CanonicalWireJson } = await import(
  pathToFileURL(resolve(contractsRoot, "CanonicalWireJson.js"))
);
const { WireValue } = await import(
  pathToFileURL(resolve(contractsRoot, "WireValue.js"))
);

function assertRejected(label, result, expectedReason) {
  assert.equal(result._hx_index, 1, `${label} emitted bytes`);
  assert.equal(result.reason, expectedReason, `${label} returned a different reason`);
  assert.equal(Object.hasOwn(result, "value"), false, `${label} retained encoded bytes`);
}

function rejected(label, value, expectedReason) {
  assertRejected(label, CanonicalWireJson.encodeChecked(value), expectedReason);
}

function rejectedAtDepth(label, value, maxDepth, expectedReason) {
  assertRejected(
    label,
    CanonicalWireJson.encodeChecked(value, maxDepth),
    expectedReason
  );
}

function nestedArrays(count) {
  let value = WireValue.NullValue;
  for (let index = 0; index < count; index += 1) {
    value = WireValue.ArrayValue([value]);
  }
  return value;
}

rejected("null-bool", WireValue.BoolValue(null), "$: invalid-bool");
rejected("string-bool", WireValue.BoolValue("true"), "$: invalid-bool");
rejected("number-bool", WireValue.BoolValue(1), "$: invalid-bool");
rejected("null-integer", WireValue.IntegerValue(null), "$: invalid-integer");
rejected("fractional-integer", WireValue.IntegerValue(1.5), "$: invalid-integer");
rejected("large-integer", WireValue.IntegerValue(2147483648), "$: invalid-integer");
rejected("small-integer", WireValue.IntegerValue(-2147483649), "$: invalid-integer");
rejected("nan-integer", WireValue.IntegerValue(Number.NaN), "$: invalid-integer");
rejected("infinite-integer", WireValue.IntegerValue(Number.POSITIVE_INFINITY), "$: invalid-integer");
rejected("wrong-string", WireValue.StringValue(7), "$: invalid-string");
rejected("wrong-array", WireValue.ArrayValue({}), "$: invalid-array");
rejected("wrong-object", WireValue.ObjectValue({}), "$: invalid-object");
rejected(
  "unknown-tag",
  {_hx_index: 99, __enum__: "wordpress.hx.contracts.WireValue"},
  "$: invalid-wire-value"
);
rejected(
  "wrong-enum-identity",
  {_hx_index: 0, __enum__: "wordpress.hx.contracts.UnknownWireValue"},
  "$: invalid-wire-value"
);
rejected(
  "bool-without-payload",
  {_hx_index: 1, __enum__: "wordpress.hx.contracts.WireValue"},
  "$: invalid-bool"
);
rejected("field-without-name", WireValue.ObjectValue([{}]), "$[0]: invalid-field");
rejected(
  "field-without-value",
  WireValue.ObjectValue([{name: "valid"}]),
  "$[0]: invalid-field"
);
rejected("non-object-field", WireValue.ObjectValue([7]), "$[0]: invalid-field");

const nested65 = nestedArrays(65);
for (const [label, maxDepth] of [
  ["nan-depth", Number.NaN],
  ["fractional-depth", 1.5],
  ["string-depth", "64"],
  ["boolean-depth", true],
  ["infinite-depth", Number.POSITIVE_INFINITY],
]) {
  rejectedAtDepth(
    label,
    nested65,
    maxDepth,
    "json-depth-limit-must-be-integer"
  );
}

const cycle = [];
const cycleValue = WireValue.ArrayValue(cycle);
cycle.push(cycleValue);
rejectedAtDepth(
  "nan-depth-cycle",
  cycleValue,
  Number.NaN,
  "json-depth-limit-must-be-integer"
);

const throwingElement = [];
Object.defineProperty(throwingElement, "0", {
  configurable: true,
  get() {
    throw new Error("wire-array-getter");
  },
});
throwingElement.length = 1;
rejected(
  "throwing-array-element",
  WireValue.ArrayValue(throwingElement),
  "$[0]: invalid-array-element"
);

const throwingArrayLength = new Proxy([], {
  get(target, property, receiver) {
    if (property === "length") {
      throw new Error("wire-array-length");
    }
    return Reflect.get(target, property, receiver);
  },
});
rejected(
  "throwing-array-length",
  WireValue.ArrayValue(throwingArrayLength),
  "$: invalid-array"
);

const throwingObjectLength = new Proxy([], {
  get(target, property, receiver) {
    if (property === "length") {
      throw new Error("wire-object-length");
    }
    return Reflect.get(target, property, receiver);
  },
});
rejected(
  "throwing-object-length",
  WireValue.ObjectValue(throwingObjectLength),
  "$: invalid-object"
);

console.log("Genes foreign WireValue rejection passed");
