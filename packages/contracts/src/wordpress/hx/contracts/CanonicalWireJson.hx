package wordpress.hx.contracts;

import haxe.io.Bytes;
import haxe.io.Encoding;
import wordpress.hx.contracts.WireValue.WireField;

/** Deterministic JSON projection for the closed wire algebra. */
class CanonicalWireJson {
	public static function encode(value:WireValue):String {
		return encodeValue(value, "$");
	}

	/**
		Encode only after proving the complete value fits the bounded,
		decoder-compatible JSON domain.
	**/
	public static function encodeChecked(value:WireValue, maxDepth:Int = 64):WireJsonEncoding {
		if (maxDepth < 1) {
			return JsonRejected("json-depth-limit-must-be-positive");
		}
		return switch validate(value, "$", 0, maxDepth) {
			case Invalid(reason): JsonRejected(reason);
			case Valid: JsonEncoded(encode(value));
		};
	}

	static function validate(value:WireValue, path:String, depth:Int, maxDepth:Int):WireJsonValidation {
		if (depth > maxDepth) {
			return Invalid(path + ": json-depth-limit-exceeded");
		}
		return switch value {
			case NullValue | BoolValue(_) | IntegerValue(_):
				Valid;
			case StringValue(value):
				validateString(value, path);
			case ArrayValue(values):
				validateArray(values, path, depth, maxDepth);
			case ObjectValue(fields):
				validateObject(fields, path, depth, maxDepth);
		};
	}

	static function validateArray(values:Array<WireValue>, path:String, depth:Int, maxDepth:Int):WireJsonValidation {
		for (index in 0...values.length) {
			switch validate(values[index], path + "[" + index + "]", depth + 1, maxDepth) {
				case Invalid(reason):
					return Invalid(reason);
				case Valid:
			}
		}
		return Valid;
	}

	static function validateObject(fields:Array<WireField>, path:String, depth:Int, maxDepth:Int):WireJsonValidation {
		final sorted = fields.copy();
		sorted.sort((left, right) -> UnicodeScalarOrder.compare(left.name, right.name));
		for (index in 0...sorted.length) {
			final current = sorted[index];
			switch validateString(current.name, path + "/<field-name>") {
				case Invalid(reason):
					return Invalid(reason);
				case Valid:
			}
			if (index > 0 && sorted[index - 1].name == current.name) {
				return Invalid(path + ": duplicate field " + current.name);
			}
			switch validate(current.value, path + "/" + current.name, depth + 1, maxDepth) {
				case Invalid(reason):
					return Invalid(reason);
				case Valid:
			}
		}
		return Valid;
	}

	static function validateString(value:String, path:String):WireJsonValidation {
		return isValidUnicode(value) ? Valid : Invalid(path + ": invalid-unicode");
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

	static function encodeValue(value:WireValue, path:String):String {
		return switch value {
			case NullValue:
				"null";
			case BoolValue(value):
				value ? "true" : "false";
			case IntegerValue(value):
				Std.string(value);
			case StringValue(value):
				encodeString(value);
			case ArrayValue(values):
				"[" + [
					for (index in 0...values.length)
						encodeValue(values[index], path + "[" + index + "]")
				].join(",") + "]";
			case ObjectValue(fields):
				encodeObject(fields, path);
		};
	}

	static function encodeObject(fields:Array<WireField>, path:String):String {
		final sorted = fields.copy();
		sorted.sort((left, right) -> UnicodeScalarOrder.compare(left.name, right.name));
		final encoded:Array<String> = [];
		for (index in 0...sorted.length) {
			final current = sorted[index];
			if (index > 0 && sorted[index - 1].name == current.name) {
				throw new ContractError(path + ": duplicate field " + current.name);
			}
			encoded.push(encodeString(current.name) + ":" + encodeValue(current.value, path + "/" + current.name));
		}
		return "{" + encoded.join(",") + "}";
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

private enum WireJsonValidation {
	Valid;
	Invalid(reason:String);
}
