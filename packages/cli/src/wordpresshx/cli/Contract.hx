package wordpresshx.cli;

import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Closed-contract accessors for trace index and map JSON. */
class Contract {
	public static function object(value:JsonValue, label:String):Array<JsonField> {
		return switch value {
			case ObjectValue(fields): fields;
			case _: fail(label + " must be an object");
		};
	}

	public static function fields(value:JsonValue, expected:Array<String>, label:String):Void {
		final actual = [for (field in object(value, label)) field.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail(label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "));
		}
	}

	public static function has(value:JsonValue, field:String, label:String):Bool {
		return find(object(value, label), field) != null;
	}

	public static function fieldValue(value:JsonValue, field:String, label:String):JsonValue {
		final result = find(object(value, label), field);
		if (result == null) {
			return fail(label + "." + field + " is required");
		}
		return result;
	}

	public static function string(value:JsonValue, field:String, label:String):String {
		return stringValue(fieldValue(value, field, label), label + "." + field);
	}

	public static function text(value:JsonValue, field:String, label:String):String {
		return textValue(fieldValue(value, field, label), label + "." + field);
	}

	public static function stringValue(value:JsonValue, label:String):String {
		return switch value {
			case StringValue(result) if (result.length > 0): result;
			case _: fail(label + " must be a non-empty string");
		};
	}

	public static function textValue(value:JsonValue, label:String):String {
		return switch value {
			case StringValue(result): result;
			case _: fail(label + " must be a string");
		};
	}

	public static function nullableStringValue(value:JsonValue, label:String):Null<String> {
		return switch value {
			case NullValue: null;
			case StringValue(result): result;
			case _: fail(label + " must be a string or null");
		};
	}

	public static function integer(value:JsonValue, field:String, label:String):Int {
		return integerValue(fieldValue(value, field, label), label + "." + field);
	}

	public static function integerValue(value:JsonValue, label:String):Int {
		return switch value {
			case NumberValue(source) if (~/^(?:0|-?[1-9][0-9]*)$/.match(source)):
				final result = Std.parseInt(source);
				if (result == null || Std.string(result) != source) {
					fail(label + " is outside the supported integer range");
				}
				result;
			case _: fail(label + " must be an integer");
		};
	}

	public static function boolean(value:JsonValue, field:String, label:String):Bool {
		return switch fieldValue(value, field, label) {
			case BoolValue(result): result;
			case _: fail(label + "." + field + " must be a boolean");
		};
	}

	public static function array(value:JsonValue, field:String, label:String):Array<JsonValue> {
		return arrayValue(fieldValue(value, field, label), label + "." + field);
	}

	public static function arrayValue(value:JsonValue, label:String):Array<JsonValue> {
		return switch value {
			case ArrayValue(result): result;
			case _: fail(label + " must be an array");
		};
	}

	public static function strings(value:JsonValue, field:String, label:String):Array<String> {
		final values = array(value, field, label);
		return [
			for (index in 0...values.length)
				stringValue(values[index], label + "." + field + "[" + index + "]")
		];
	}

	public static function require(value:Bool, message:String, ambiguity:Bool = false):Void {
		if (!value) {
			fail(message, ambiguity ? 4 : 3);
		}
	}

	public static function fail<T>(message:String, exitCode:Int = 3):T {
		throw new TraceFailure(message, exitCode);
	}

	static function find(fields:Array<JsonField>, name:String):Null<JsonValue> {
		for (field in fields) {
			if (field.name == name) {
				return field.value;
			}
		}
		return null;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
