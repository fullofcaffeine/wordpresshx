package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.Exception;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.build._internal.JsonValue.JsonField;

/** Deterministic JSON encoder for normal WordPress metadata values. */
class BlockJson {
	static final NUMBER = ~/^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/;

	public static function encode(value:JsonValue):String {
		return encodeValue(value, "$");
	}

	static function encodeValue(value:JsonValue, location:String):String {
		return switch value {
			case NullValue: "null";
			case BoolValue(value): value ? "true" : "false";
			case NumberValue(source):
				if (!NUMBER.match(source)) {
					throw new BlockJsonError(location + ": invalid JSON number " + source);
				}
				source;
			case StringValue(value): encodeString(value);
			case ArrayValue(values):
				"[" + [
					for (index in 0...values.length)
						encodeValue(values[index], location + "[" + index + "]")
				].join(",") + "]";
			case ObjectValue(fields): encodeObject(fields, location);
		};
	}

	static function encodeObject(fields:Array<JsonField>, location:String):String {
		final sorted = fields.copy();
		sorted.sort((left, right) -> compareText(left.name, right.name));
		final output:Array<String> = [];
		for (index in 0...sorted.length) {
			final field = sorted[index];
			if (index > 0 && sorted[index - 1].name == field.name) {
				throw new BlockJsonError(location + ": duplicate field " + field.name);
			}
			output.push(encodeString(field.name) + ":" + encodeValue(field.value, location + "." + field.name));
		}
		return "{" + output.join(",") + "}";
	}

	static function encodeString(value:String):String {
		final output = new StringBuf();
		output.add('"');
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			switch code {
				case 0x22:
					output.add('\\"');
				case 0x5c:
					output.add('\\\\');
				case 0x08:
					output.add('\\b');
				case 0x0c:
					output.add('\\f');
				case 0x0a:
					output.add('\\n');
				case 0x0d:
					output.add('\\r');
				case 0x09:
					output.add('\\t');
				case value if (value < 0x20):
					output.add('\\u00' + StringTools.hex(value, 2).toLowerCase());
				case _:
					output.addChar(code);
			}
		}
		output.add('"');
		return output.toString();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

class BlockJsonError extends Exception {
	public function new(message:String) {
		super(message);
	}
}
#end
