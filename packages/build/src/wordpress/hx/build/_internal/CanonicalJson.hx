package wordpress.hx.build._internal;

#if macro
import haxe.Exception;

/** Canonical JSON v1 encoder for the collector's closed ASCII value subset. */
class CanonicalJson {
	public static function encode(value:JsonValue):String {
		return encodeValue(value, "$");
	}

	static function encodeValue(value:JsonValue, location:String):String {
		return switch value {
			case NullValue: "null";
			case BoolValue(value): value ? "true" : "false";
			case NumberValue(source):
				if (!~/^(?:0|-?[1-9][0-9]*)$/.match(source)) {
					throw new CanonicalJsonError(location + ": floating-point or non-canonical JSON numbers are forbidden");
				}
				source;
			case StringValue(value): encodeString(value, location);
			case ArrayValue(values):
				"[" + [
					for (index in 0...values.length)
						encodeValue(values[index], location + "[" + index + "]")
				].join(",") + "]";
			case ObjectValue(fields):
				final sorted = fields.copy();
				sorted.sort((left, right) -> compareText(left.name, right.name));
				final encoded = [];
				for (index in 0...sorted.length) {
					final field = sorted[index];
					if (index > 0 && sorted[index - 1].name == field.name) {
						throw new CanonicalJsonError(location + ": duplicate object field " + field.name);
					}
					encoded.push(encodeString(field.name, location + ".<key>") + ":" + encodeValue(field.value, location + "." + field.name));
				}
				"{" + encoded.join(",") + "}";
		};
	}

	static function encodeString(value:String, location:String):String {
		requireCanonicalString(value, location);
		return '"' + value.split("\\").join("\\\\").split('"').join('\\"') + '"';
	}

	public static function requireCanonicalString(value:String, location:String):Void {
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code < 0x20 || code > 0x7e) {
				throw new CanonicalJsonError(location + ": collector v1 accepts printable ASCII strings only");
			}
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

class CanonicalJsonError extends Exception {
	public function new(message:String) {
		super(message);
	}
}
#end
