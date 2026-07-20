package wordpress.hx.contracts;

import wordpress.hx.contracts.WireValue.WireField;

/** Deterministic JSON projection for the closed wire algebra. */
class CanonicalWireJson {
	public static function encode(value:WireValue):String {
		return encodeValue(value, "$");
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
