package wordpress.hx.contracts;

import haxe.io.Bytes;
import haxe.io.Encoding;
import wordpress.hx.contracts.WireValue.WireField;

/** Deterministic JSON projection for the closed wire algebra. */
class CanonicalWireJson {
	static inline final MAX_CONTAINER_DEPTH = 64;

	/**
		Projects a public `WireValue` into decoder-compatible JSON bytes.

		The first traversal validates and snapshots the complete mutable wire
		tree. Container depth counts only arrays and objects: a root container
		has depth one, and every nested container adds one regardless of whether
		it is empty. Encoding then consumes only the private snapshot, so callers
		cannot mutate the checked arrays or fields between validation and output.
	**/
	public static function encodeChecked(value:WireValue, maxDepth:Int = 64):WireJsonEncoding {
		if (!Std.isOfType(maxDepth, Int)) {
			return JsonRejected("json-depth-limit-must-be-integer");
		}
		if (maxDepth < 1) {
			return JsonRejected("json-depth-limit-must-be-positive");
		}
		if (maxDepth > MAX_CONTAINER_DEPTH) {
			return JsonRejected("json-depth-limit-exceeds-supported-maximum");
		}
		return switch snapshot(value, "$", 0, maxDepth) {
			case SnapshotRejected(reason): JsonRejected(reason);
			case SnapshotAccepted(value): JsonEncoded(encodeValue(value));
		};
	}

	static function snapshot(value:Null<WireValue>, path:String, containerDepth:Int, maxDepth:Int):WireJsonSnapshotResult {
		if (value == null) {
			return SnapshotRejected(path + ": null-wire-value");
		}
		if (!hasValidWireEnvelope(value)) {
			return SnapshotRejected(path + ": invalid-wire-value");
		}
		try {
			return switch value {
				case NullValue:
					SnapshotAccepted(CanonicalNull);
				case BoolValue(value):
					Std.isOfType(value, Bool) ? SnapshotAccepted(CanonicalBool(value)) : SnapshotRejected(path + ": invalid-bool");
				case IntegerValue(value): Std.isOfType(value,
						Int) && value >= -2147483648 && value <= 2147483647 ? SnapshotAccepted(CanonicalInteger(value)) : SnapshotRejected(path
						+ ": invalid-integer");
				case StringValue(value):
					snapshotString(value, path);
				case ArrayValue(values):
					snapshotArray(values, path, containerDepth + 1, maxDepth);
				case ObjectValue(fields):
					snapshotObject(fields, path, containerDepth + 1, maxDepth);
			};
		} catch (exception:haxe.Exception) {
			return SnapshotRejected(path + ": invalid-wire-value");
		}
	}

	static function hasValidWireEnvelope(value:WireValue):Bool {
		try {
			if (Type.getEnum(value) != WireValue) {
				return false;
			}
			final constructorIndex = Type.enumIndex(value);
			final constructorName = Type.enumConstructor(value);
			// The standard enum API exposes erased payload values. We observe only
			// their count here and never propagate them into the typed codec.
			final parameterCount:Int = Type.enumParameters(value).length;
			return switch constructorIndex {
				case 0: constructorName == "NullValue" && parameterCount == 0;
				case 1: constructorName == "BoolValue" && parameterCount == 1;
				case 2: constructorName == "IntegerValue" && parameterCount == 1;
				case 3: constructorName == "StringValue" && parameterCount == 1;
				case 4: constructorName == "ArrayValue" && parameterCount == 1;
				case 5: constructorName == "ObjectValue" && parameterCount == 1;
				case _: false;
			};
		} catch (exception:haxe.Exception) {
			return false;
		}
	}

	static function snapshotArray(values:Null<Array<WireValue>>, path:String, containerDepth:Int, maxDepth:Int):WireJsonSnapshotResult {
		if (values == null || !Std.isOfType(values, Array)) {
			return SnapshotRejected(path + ": invalid-array");
		}
		if (containerDepth > maxDepth) {
			return SnapshotRejected(path + ": json-depth-limit-exceeded");
		}
		var valueCount = 0;
		try {
			valueCount = values.length;
		} catch (exception:haxe.Exception) {
			return SnapshotRejected(path + ": invalid-array");
		}
		final valuesSnapshot:Array<CanonicalJsonValue> = [];
		for (index in 0...valueCount) {
			var current:Null<WireValue> = null;
			try {
				current = values[index];
			} catch (exception:haxe.Exception) {
				return SnapshotRejected(path + "[" + index + "]: invalid-array-element");
			}
			switch snapshot(current, path + "[" + index + "]", containerDepth, maxDepth) {
				case SnapshotRejected(reason):
					return SnapshotRejected(reason);
				case SnapshotAccepted(value):
					valuesSnapshot.push(value);
			}
		}
		return SnapshotAccepted(CanonicalArray(valuesSnapshot));
	}

	static function snapshotObject(fields:Null<Array<WireField>>, path:String, containerDepth:Int, maxDepth:Int):WireJsonSnapshotResult {
		if (fields == null || !Std.isOfType(fields, Array)) {
			return SnapshotRejected(path + ": invalid-object");
		}
		if (containerDepth > maxDepth) {
			return SnapshotRejected(path + ": json-depth-limit-exceeded");
		}
		var fieldCount = 0;
		try {
			fieldCount = fields.length;
		} catch (exception:haxe.Exception) {
			return SnapshotRejected(path + ": invalid-object");
		}
		final fieldsSnapshot:Array<CanonicalJsonField> = [];
		for (index in 0...fieldCount) {
			try {
				final current:Null<WireField> = fields[index];
				if (current == null) {
					return SnapshotRejected(path + "[" + index + "]: null-field");
				}
				final fieldName:Null<String> = current.name;
				final fieldValue:Null<WireValue> = current.value;
				if (fieldName == null || fieldValue == null) {
					return SnapshotRejected(path + "[" + index + "]: invalid-field");
				}
				final nameResult = snapshotString(fieldName, path + "[" + index + "]/<field-name>");
				final name = switch nameResult {
					case SnapshotRejected(reason): return SnapshotRejected(reason);
					case SnapshotAccepted(CanonicalString(value)): value;
					case SnapshotAccepted(_): return SnapshotRejected(path + "[" + index + "]: invalid-field-name");
				};
				switch snapshot(fieldValue, path + "/" + name, containerDepth, maxDepth) {
					case SnapshotRejected(reason):
						return SnapshotRejected(reason);
					case SnapshotAccepted(value):
						fieldsSnapshot.push({name: name, value: value});
				}
			} catch (exception:haxe.Exception) {
				return SnapshotRejected(path + "[" + index + "]: invalid-field");
			}
		}
		fieldsSnapshot.sort((left, right) -> UnicodeScalarOrder.compare(left.name, right.name));
		for (index in 1...fieldsSnapshot.length) {
			if (fieldsSnapshot[index - 1].name == fieldsSnapshot[index].name) {
				return SnapshotRejected(path + ": duplicate field " + fieldsSnapshot[index].name);
			}
		}
		return SnapshotAccepted(CanonicalObject(fieldsSnapshot));
	}

	static function snapshotString(value:Null<String>, path:String):WireJsonSnapshotResult {
		if (value == null || !Std.isOfType(value, String)) {
			return SnapshotRejected(path + ": invalid-string");
		}
		return isValidUnicode(value) ? SnapshotAccepted(CanonicalString(value)) : SnapshotRejected(path + ": invalid-unicode");
	}

	static function isValidUnicode(value:String):Bool {
		#if target.utf16
		var index = 0;
		while (index < value.length) {
			final code = StringTools.fastCodeAt(value, index);
			if (code >= 0xd800 && code <= 0xdbff) {
				if (index + 1 >= value.length) {
					return false;
				}
				final low = StringTools.fastCodeAt(value, index + 1);
				if (low < 0xdc00 || low > 0xdfff) {
					return false;
				}
				index += 2;
			} else {
				if (code >= 0xdc00 && code <= 0xdfff) {
					return false;
				}
				index++;
			}
		}
		return true;
		#else
		return UnicodeString.validate(Bytes.ofString(value), Encoding.UTF8);
		#end
	}

	static function encodeValue(value:CanonicalJsonValue):String {
		return switch value {
			case CanonicalNull:
				"null";
			case CanonicalBool(value):
				value ? "true" : "false";
			case CanonicalInteger(value):
				Std.string(value);
			case CanonicalString(value):
				encodeString(value);
			case CanonicalArray(values):
				"[" + values.map(encodeValue).join(",") + "]";
			case CanonicalObject(fields):
				"{" + fields.map(field -> encodeString(field.name) + ":" + encodeValue(field.value)).join(",") + "}";
		};
	}

	static function encodeString(value:String):String {
		final result = new StringBuf();
		result.add('"');
		for (index in 0...value.length) {
			final code = StringTools.fastCodeAt(value, index);
			switch code {
				case 0x22:
					result.add('\\"');
				case 0x5c:
					result.add("\\\\");
				case 0x08:
					result.add("\\b");
				case 0x0c:
					result.add("\\f");
				case 0x0a:
					result.add("\\n");
				case 0x0d:
					result.add("\\r");
				case 0x09:
					result.add("\\t");
				case code if (code < 0x20):
					result.add("\\u" + StringTools.hex(code, 4).toLowerCase());
				case _:
					result.addChar(code);
			}
		}
		result.add('"');
		return result.toString();
	}
}

private enum WireJsonSnapshotResult {
	SnapshotAccepted(value:CanonicalJsonValue);
	SnapshotRejected(reason:String);
}

private enum CanonicalJsonValue {
	CanonicalNull;
	CanonicalBool(value:Bool);
	CanonicalInteger(value:Int);
	CanonicalString(value:String);
	CanonicalArray(values:Array<CanonicalJsonValue>);
	CanonicalObject(fields:Array<CanonicalJsonField>);
}

private typedef CanonicalJsonField = {
	final name:String;
	final value:CanonicalJsonValue;
}
