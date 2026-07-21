package reflaxe.php.map;

import haxe.Json;

/** Closed JSON value representation owned by the generic PHP compiler. **/
enum PhpJsonValue {
	NullValue;
	BoolValue(value:Bool);
	IntegerValue(value:Int);
	StringValue(value:String);
	ArrayValue(values:Array<PhpJsonValue>);
	ObjectValue(fields:Array<PhpJsonField>);
}

typedef PhpJsonField = {
	final name:String;
	final value:PhpJsonValue;
}

/** Compact canonical JSON with recursively sorted object keys. **/
class PhpCanonicalJson {
	public static function encode(value:PhpJsonValue):String {
		return encodeInline(value) + "\n";
	}

	public static function encodeInline(value:PhpJsonValue):String {
		return encodeValue(value);
	}

	static function encodeValue(value:PhpJsonValue):String {
		return switch value {
			case NullValue: "null";
			case BoolValue(value): value ? "true" : "false";
			case IntegerValue(value): Std.string(value);
			case StringValue(value): Json.stringify(value);
			case ArrayValue(values):
				"[" + values.map(encodeValue).join(",") + "]";
			case ObjectValue(fields):
				final sorted = fields.copy();
				sorted.sort((left, right) -> compareText(left.name, right.name));
				final encoded:Array<String> = [];
				for (index in 0...sorted.length) {
					final field = sorted[index];
					if (index > 0 && sorted[index - 1].name == field.name) {
						throw "Duplicate canonical PHP JSON field: " + field.name;
					}
					encoded.push(Json.stringify(field.name) + ":" + encodeValue(field.value));
				}
				"{" + encoded.join(",") + "}";
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
