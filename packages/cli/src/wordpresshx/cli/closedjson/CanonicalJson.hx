package wordpresshx.cli.closedjson;

import haxe.Exception;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Canonical JSON v1 encoder for authenticated CLI data. */
class CanonicalJson {
	public static function encode(value:JsonValue):String {
		return encodeValue(value, "$");
	}

	public static function digest(value:JsonValue):String {
		return Sha256.make(Bytes.ofString(encode(value))).toHex().toLowerCase();
	}

	public static function withoutField(value:JsonValue, name:String):JsonValue {
		return switch value {
			case ObjectValue(fields):
				final filtered:Array<JsonField> = [for (field in fields) if (field.name != name) field];
				if (filtered.length != fields.length - 1) {
					throw new CanonicalJsonError("expected exactly one field named " + name);
				}
				ObjectValue(filtered);
			case _:
				throw new CanonicalJsonError("document root must be an object");
		};
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
				final encoded:Array<String> = [];
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
				throw new CanonicalJsonError(location + ": canonical data accepts printable ASCII strings only");
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
