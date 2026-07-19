package wordpresshx.cli.closedjson;

import haxe.Exception;
import wordpresshx.cli.closedjson.CanonicalJson.CanonicalJsonError;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Checked access to a closed JSON object. */
class JsonReader {
	final fields:Array<JsonField>;
	final label:String;

	public static function from(value:JsonValue, label:String, code:String):JsonReader {
		return switch value {
			case ObjectValue(fields): new JsonReader(fields, label);
			case _: invalid(code, label + " must be an object");
		};
	}

	function new(fields:Array<JsonField>, label:String) {
		this.fields = fields;
		this.label = label;
	}

	public function exact(expected:Array<String>, code:String):Void {
		final actual = [for (field in fields) field.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\n") != wanted.join("\n")) {
			invalid(code, label + " fields must be exactly [" + wanted.join(", ") + "]");
		}
	}

	public function has(name:String):Bool {
		return find(name) != null;
	}

	public function string(name:String, code:String):String {
		return switch require(name, code) {
			case StringValue(value):
				try {
					CanonicalJson.requireCanonicalString(value, label + "." + name);
				} catch (error:CanonicalJsonError) {
					invalid(code, error.message);
				}
				value;
			case _: invalid(code, label + "." + name + " must be a string");
		};
	}

	public function boolean(name:String, code:String):Bool {
		return switch require(name, code) {
			case BoolValue(value): value;
			case _: invalid(code, label + "." + name + " must be a boolean");
		};
	}

	public function integer(name:String, code:String):Int {
		return switch require(name, code) {
			case NumberValue(source):
				if (!~/^(?:0|-?[1-9][0-9]*)$/.match(source)) {
					invalid(code, label + "." + name + " must be an integer");
				}
				final value = Std.parseInt(source);
				if (value == null || Std.string(value) != source) {
					invalid(code, label + "." + name + " is outside the supported integer range");
				}
				value;
			case _: invalid(code, label + "." + name + " must be an integer");
		};
	}

	public function array(name:String, code:String):Array<JsonValue> {
		return switch require(name, code) {
			case ArrayValue(values): values;
			case _: invalid(code, label + "." + name + " must be an array");
		};
	}

	public function strings(name:String, code:String):Array<String> {
		final result:Array<String> = [];
		final values = array(name, code);
		for (index in 0...values.length) {
			switch values[index] {
				case StringValue(value):
					try {
						CanonicalJson.requireCanonicalString(value, label + "." + name + "[" + index + "]");
					} catch (error:CanonicalJsonError) {
						invalid(code, error.message);
					}
					result.push(value);
				case _:
					invalid(code, label + "." + name + "[" + index + "] must be a string");
			}
		}
		return result;
	}

	public function object(name:String, code:String):JsonReader {
		return JsonReader.from(require(name, code), label + "." + name, code);
	}

	public function value(name:String, code:String):JsonValue {
		return require(name, code);
	}

	function require(name:String, code:String):JsonValue {
		final value = find(name);
		if (value == null) {
			return invalid(code, label + " is missing field " + name);
		}
		return value;
	}

	function find(name:String):Null<JsonValue> {
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

	static function invalid<T>(code:String, message:String):T {
		throw new JsonReadError(code, message);
	}
}

class JsonReadError extends Exception {
	public final code:String;

	public function new(code:String, message:String) {
		this.code = code;
		super(message);
	}
}
