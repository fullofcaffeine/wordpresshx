package wordpress.hx.build._internal;

#if macro
import haxe.Json;

/** Canonical JSON v1 encoder for the collector's closed ASCII value subset. */
class CanonicalJson {
	public static function encode(value:Dynamic):String {
		return encodeValue(value, "$");
	}

	static function encodeValue(value:Dynamic, location:String):String {
		if (value == null) {
			return "null";
		}
		if (Std.isOfType(value, String)) {
			final string:String = cast value;
			requireCanonicalString(string, location);
			return Json.stringify(string);
		}
		if (Std.isOfType(value, Bool)) {
			return value ? "true" : "false";
		}
		return switch Type.typeof(value) {
			case TInt:
				Std.string(value);
			case TFloat:
				throw location + ": floating-point JSON values are forbidden";
			case TClass(type) if (type == Array):
				final values:Array<Dynamic> = cast value;
				"[" + [
					for (index in 0...values.length)
						encodeValue(values[index], location + "[" + index + "]")
				].join(",") + "]";
			case TObject:
				final fields = Reflect.fields(value);
				fields.sort(Reflect.compare);
				final encoded = [];
				for (field in fields) {
					requireCanonicalString(field, location + ".<key>");
					encoded.push(Json.stringify(field) + ":" + encodeValue(Reflect.field(value, field), location + "." + field));
				}
				"{" + encoded.join(",") + "}";
			case _:
				throw location + ": unsupported canonical JSON value";
		}
	}

	public static function requireCanonicalString(value:String, location:String):Void {
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code < 0x20 || code > 0x7e) {
				throw location + ": collector v1 accepts printable ASCII strings only";
			}
		}
	}
}
#end
