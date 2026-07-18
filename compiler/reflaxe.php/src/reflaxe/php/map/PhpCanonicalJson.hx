package reflaxe.php.map;

import haxe.Json;

/** Compact canonical JSON with recursively sorted object keys. **/
class PhpCanonicalJson {
	public static function encode(value:Dynamic):String {
		return encodeInline(value) + "\n";
	}

	public static function encodeInline(value:Dynamic):String {
		return encodeValue(value);
	}

	static function encodeValue(value:Dynamic):String {
		if (value == null) {
			return "null";
		}
		if (Std.isOfType(value, String)) {
			return Json.stringify(value);
		}
		if (Std.isOfType(value, Bool) || Std.isOfType(value, Int) || Std.isOfType(value, Float)) {
			return Std.string(value);
		}
		if (Std.isOfType(value, Array)) {
			final values:Array<Dynamic> = cast value;
			return "[" + values.map(item -> encodeValue(item)).join(",") + "]";
		}
		final fields = Reflect.fields(value);
		fields.sort(Reflect.compare);
		return "{" + fields.map(field -> Json.stringify(field) + ":" + encodeValue(Reflect.field(value, field))).join(",") + "}";
	}
}
