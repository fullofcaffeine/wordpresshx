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

function rejected(label, value, expectedReason) {
  const result = CanonicalWireJson.encodeChecked(value);
  assert.equal(result._hx_index, 1, `${label} emitted bytes`);
  assert.equal(result.reason, expectedReason, `${label} returned a different reason`);
  assert.equal(Object.hasOwn(result, "value"), false, `${label} retained encoded bytes`);
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

console.log("Genes foreign WireValue rejection passed");
