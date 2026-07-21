package wordpresshx.cli;

import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Small typed JSON constructors for CLI events and diagnostics. */
class CliJson {
	public static function object(fields:Map<String, JsonValue>):JsonValue {
		return ObjectValue([for (name => value in fields) field(name, value)]);
	}

	public static inline function text(value:String):JsonValue {
		return StringValue(value);
	}

	public static inline function nullableText(value:Null<String>):JsonValue {
		return value == null ? NullValue : StringValue(value);
	}

	public static inline function number(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}

	public static inline function boolean(value:Bool):JsonValue {
		return BoolValue(value);
	}

	public static function texts(values:Array<String>):JsonValue {
		return ArrayValue(values.map(value -> StringValue(value)));
	}

	public static inline function array(values:Array<JsonValue>):JsonValue {
		return ArrayValue(values);
	}

	static inline function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}
}
