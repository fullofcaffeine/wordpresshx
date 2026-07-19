package wordpresshx.cli.scaffold;

import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Small typed constructors plus readable deterministic JSON documents. */
class ScaffoldJson {
	public static inline function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	public static inline function text(value:String):JsonValue {
		return StringValue(value);
	}

	public static inline function number(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}

	public static inline function boolean(value:Bool):JsonValue {
		return BoolValue(value);
	}

	public static inline function array(values:Array<JsonValue>):JsonValue {
		return ArrayValue(values);
	}

	public static inline function object(fields:Array<JsonField>):JsonValue {
		return ObjectValue(fields);
	}

	public static function document(value:JsonValue, readable:Bool):String {
		return (readable ? encodeReadable(value, 0) : CanonicalJson.encode(value)) + "\n";
	}

	static function encodeReadable(value:JsonValue, depth:Int):String {
		return switch value {
			case NullValue | BoolValue(_) | NumberValue(_) | StringValue(_):
				CanonicalJson.encode(value);
			case ArrayValue(values):
				if (values.length == 0) {
					"[]";
				} else {final childIndent = indent(depth + 1);
					"[\n" + childIndent + [for (child in values) encodeReadable(child, depth + 1)].join(",\n" + childIndent)
						+ "\n"
						+ indent(depth)
						+ "]";
				}
			case ObjectValue(fields):
				ensureUnique(fields);
				if (fields.length == 0) {
					"{}";
				} else {final childIndent = indent(depth + 1);
					final encoded = [
						for (entry in fields)
							CanonicalJson.encode(StringValue(entry.name)) + ": " + encodeReadable(entry.value, depth + 1)
					];
					"{\n"
					+ childIndent
					+ encoded.join(",\n" + childIndent)
					+ "\n"
					+ indent(depth)
					+ "}";
				}
		};
	}

	static function ensureUnique(fields:Array<JsonField>):Void {
		final seen = new Map<String, Bool>();
		for (entry in fields) {
			CanonicalJson.requireCanonicalString(entry.name, "scaffold JSON field");
			if (seen.exists(entry.name)) {
				throw new haxe.Exception("duplicate scaffold JSON field " + entry.name);
			}
			seen.set(entry.name, true);
		}
	}

	static function indent(depth:Int):String {
		return StringTools.lpad("", " ", depth * 2);
	}
}
