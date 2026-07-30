package wordpress.hx.contracts.boundary;

#if js
import js.Node;
#end
import haxe.io.Bytes;
import wordpress.hx.contracts.CanonicalWireJson;
import wordpress.hx.contracts.WireJsonEncoding;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireValue.WireField;

/**
	Runtime boundary corpus for malformed values originating outside strict Haxe.

	The production contracts package and ordinary application fixtures compile
	with strict null safety. This deliberately non-strict probe proves that
	foreign or legacy callers still receive a modeled rejection rather than an
	uncaught target exception.
**/
final class WireJsonBoundaryTest {
	static function main():Void {
		final lines:Array<String> = [];

		final nullRoot:WireValue = null;
		rejected(lines, "null-root", nullRoot, 64, "$: null-wire-value");
		rejected(lines, "null-string", StringValue(null), 64, "$: null-string");
		rejected(lines, "null-array", ArrayValue(null), 64, "$: null-array");
		final nullArrayElement:Array<WireValue> = [null];
		rejected(lines, "null-array-element", ArrayValue(nullArrayElement), 64, "$[0]: null-wire-value");
		rejected(lines, "null-object", ObjectValue(null), 64, "$: null-object");
		final nullField:Array<WireField> = [null];
		rejected(lines, "null-field", ObjectValue(nullField), 64, "$[0]: null-field");
		rejected(lines, "null-field-name", ObjectValue([{name: null, value: NullValue}]), 64, "$[0]/<field-name>: null-string");
		rejected(lines, "null-field-value", ObjectValue([{name: "value", value: null}]), 64, "$/value: null-wire-value");

		final invalidHigh = invalidHighSurrogate();
		rejected(lines, "invalid-high-surrogate-value", StringValue(invalidHigh), 64, "$: invalid-unicode");
		rejected(lines, "invalid-high-surrogate-key", ObjectValue([{name: invalidHigh, value: NullValue}]), 64, "$[0]/<field-name>: invalid-unicode");
		final invalidLow = invalidLowSurrogate();
		rejected(lines, "invalid-low-surrogate-value", StringValue(invalidLow), 64, "$: invalid-unicode");
		rejected(lines, "invalid-low-surrogate-key", ObjectValue([{name: invalidLow, value: NullValue}]), 64, "$[0]/<field-name>: invalid-unicode");
		rejected(lines, "duplicate-adjacent", ObjectValue([{name: "same", value: NullValue}, {name: "same", value: BoolValue(true)}]), 64,
			"$: duplicate field same");
		rejected(lines, "duplicate-non-adjacent", ObjectValue([
			{name: "same", value: NullValue},
			{name: "between", value: BoolValue(true)},
			{name: "same", value: IntegerValue(1)}
		]), 64, "$: duplicate field same");

		encoded(lines, "depth-1-scalar", StringValue("value"), 1);
		encoded(lines, "depth-1-array", ArrayValue([]), 1);
		encoded(lines, "depth-1-object", ObjectValue([]), 1);
		rejectedSuffix(lines, "depth-1-nested-array", nestedArrays(2, false), 1, "json-depth-limit-exceeded");
		rejectedSuffix(lines, "depth-1-nested-object", nestedObjects(2, false), 1, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-empty-array", nestedArrays(64, false), 64);
		rejectedSuffix(lines, "depth-65-empty-array", nestedArrays(65, false), 64, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-scalar-array", nestedArrays(64, true), 64);
		rejectedSuffix(lines, "depth-65-scalar-array", nestedArrays(65, true), 64, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-empty-object", nestedObjects(64, false), 64);
		rejectedSuffix(lines, "depth-65-empty-object", nestedObjects(65, false), 64, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-scalar-object", nestedObjects(64, true), 64);
		rejectedSuffix(lines, "depth-65-scalar-object", nestedObjects(65, true), 64, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-empty-mixed", nestedMixed(64, false), 64);
		rejectedSuffix(lines, "depth-65-empty-mixed", nestedMixed(65, false), 64, "json-depth-limit-exceeded");
		encoded(lines, "depth-64-scalar-mixed", nestedMixed(64, true), 64);
		rejectedSuffix(lines, "depth-65-scalar-mixed", nestedMixed(65, true), 64, "json-depth-limit-exceeded");
		rejected(lines, "depth-zero", NullValue, 0, "json-depth-limit-must-be-positive");
		rejected(lines, "depth-negative", NullValue, -1, "json-depth-limit-must-be-positive");
		rejected(lines, "depth-above-maximum", NullValue, 65, "json-depth-limit-exceeds-supported-maximum");

		final cyclicArrayValues:Array<WireValue> = [];
		final cyclicArray = ArrayValue(cyclicArrayValues);
		cyclicArrayValues.push(cyclicArray);
		rejectedSuffix(lines, "cyclic-array", cyclicArray, 64, "json-depth-limit-exceeded");
		final cyclicObjectFields:Array<WireField> = [];
		final cyclicObject = ObjectValue(cyclicObjectFields);
		cyclicObjectFields.push({name: "self", value: cyclicObject});
		rejectedSuffix(lines, "cyclic-object", cyclicObject, 64, "json-depth-limit-exceeded");

		final mutableValues:Array<WireValue> = [StringValue("before")];
		final immutableResult = CanonicalWireJson.encodeChecked(ArrayValue(mutableValues));
		mutableValues[0] = StringValue("after");
		mutableValues.push(StringValue("added"));
		switch immutableResult {
			case JsonEncoded(value) if (value == '["before"]'):
				lines.push("post-encoding-mutation=encoded");
			case JsonEncoded(value):
				throw new haxe.Exception("post-encoding mutation changed bytes: " + value);
			case JsonRejected(reason):
				throw new haxe.Exception("valid mutation fixture was rejected: " + reason);
		}

		final output = lines.join("\n") + "\n";
		#if js
		Node.process.stdout.write(output);
		#else
		Sys.print(output);
		#end
	}

	static function nestedArrays(count:Int, deepestHasScalar:Bool):WireValue {
		if (count < 1) {
			throw new haxe.Exception("nested array count must be positive");
		}
		var value:WireValue = deepestHasScalar ? ArrayValue([NullValue]) : ArrayValue([]);
		for (_ in 1...count) {
			value = ArrayValue([value]);
		}
		return value;
	}

	static function nestedObjects(count:Int, deepestHasScalar:Bool):WireValue {
		if (count < 1) {
			throw new haxe.Exception("nested object count must be positive");
		}
		var value:WireValue = deepestHasScalar ? ObjectValue([{name: "value", value: NullValue}]) : ObjectValue([]);
		for (_ in 1...count) {
			value = ObjectValue([{name: "value", value: value}]);
		}
		return value;
	}

	static function nestedMixed(count:Int, deepestHasScalar:Bool):WireValue {
		if (count < 1) {
			throw new haxe.Exception("nested mixed count must be positive");
		}
		var value:WireValue = deepestHasScalar ? ArrayValue([NullValue]) : ArrayValue([]);
		for (index in 1...count) {
			value = index % 2 == 0 ? ArrayValue([value]) : ObjectValue([{name: "value", value: value}]);
		}
		return value;
	}

	static function invalidHighSurrogate():String {
		#if target.utf16
		return String.fromCharCode(0xd800);
		#else
		return Bytes.ofHex("eda080").toString();
		#end
	}

	static function invalidLowSurrogate():String {
		#if target.utf16
		return String.fromCharCode(0xdc00);
		#else
		return Bytes.ofHex("edb080").toString();
		#end
	}

	static function encoded(lines:Array<String>, label:String, value:WireValue, maxDepth:Int):Void {
		switch CanonicalWireJson.encodeChecked(value, maxDepth) {
			case JsonEncoded(_):
				lines.push(label + "=encoded");
			case JsonRejected(reason):
				throw new haxe.Exception(label + " unexpectedly rejected: " + reason);
		}
	}

	static function rejected(lines:Array<String>, label:String, value:WireValue, maxDepth:Int, expectedReason:String):Void {
		switch CanonicalWireJson.encodeChecked(value, maxDepth) {
			case JsonEncoded(encoded):
				throw new haxe.Exception(label + " unexpectedly emitted bytes: " + encoded);
			case JsonRejected(reason):
				if (reason != expectedReason) {
					throw new haxe.Exception(label + " returned " + reason + " instead of " + expectedReason);
				}
				lines.push(label + "=rejected");
		}
	}

	static function rejectedSuffix(lines:Array<String>, label:String, value:WireValue, maxDepth:Int, expectedSuffix:String):Void {
		switch CanonicalWireJson.encodeChecked(value, maxDepth) {
			case JsonEncoded(encoded):
				throw new haxe.Exception(label + " unexpectedly emitted bytes: " + encoded);
			case JsonRejected(reason):
				if (!StringTools.endsWith(reason, expectedSuffix)) {
					throw new haxe.Exception(label + " returned " + reason + " instead of a " + expectedSuffix + " rejection");
				}
				lines.push(label + "=rejected");
		}
	}
}
