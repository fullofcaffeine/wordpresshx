package wordpresshx.cli.ownership;

import haxe.Json;
import haxe.crypto.Sha256;
import js.Syntax;
import js.node.Buffer;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Strict canonical JSON for ownership data, represented by a closed value algebra. **/
class OwnershipJson {
	static final INTEGER = ~/^(?:0|-?[1-9][0-9]*)$/;

	public static function parseCanonical(buffer:Buffer, label:String):JsonValue {
		final source = decodeUtf8(buffer, label);
		final value = try {
			JsonParser.parse(source);
		} catch (failure:JsonParseError) {
			fail(label + " " + failure.message, "malformed-json");
		}
		validateValue(value, "$");
		final expected = Buffer.from(encode(value) + "\n", "utf8");
		if (Buffer.compareBuffers(buffer, expected) != 0) {
			fail(label + " must use wordpress-hx.canonical-json.v1 plus exactly one final LF", "non-canonical-json");
		}
		return value;
	}

	public static function encode(value:JsonValue):String {
		validateValue(value, "$");
		return encodeValue(value, "$");
	}

	public static function encodeDocument(value:JsonValue):Buffer {
		return Buffer.from(encode(value) + "\n", "utf8");
	}

	public static function clone(value:JsonValue):JsonValue {
		return JsonParser.parse(encode(value));
	}

	public static function digest(buffer:Buffer):String {
		return Sha256.make(buffer.hxToBytes()).toHex().toLowerCase();
	}

	public static function digestValue(value:JsonValue):String {
		return digest(Buffer.from(encode(value), "utf8"));
	}

	public static function contentState(?buffer:Buffer):JsonValue {
		return buffer == null ? object(["state" => text("absent")]) : object([
			"state" => text("file"),
			"sha256" => text(digest(buffer)),
			"sizeBytes" => number(buffer.length)
		]);
	}

	public static function object(fields:Map<String, OwnershipJsonField>):JsonValue {
		return ObjectValue([for (name => value in fields) {name: name, value: value.json()}]);
	}

	public static inline function array(values:Array<JsonValue>):JsonValue {
		return ArrayValue(values);
	}

	public static inline function text(value:String):JsonValue {
		return StringValue(value);
	}

	public static inline function number(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}

	public static function numberFromFloat(value:Float, label:String):JsonValue {
		if (!isSafeInteger(value)) {
			return fail(label + " must be a safe integer", "contract-shape");
		}
		return NumberValue(Std.string(value));
	}

	public static inline function boolean(value:Bool):JsonValue {
		return BoolValue(value);
	}

	public static inline function nullableText(value:Null<String>):JsonValue {
		return value == null ? NullValue : StringValue(value);
	}

	public static function nfc(value:String):String {
		return Syntax.code("{0}.normalize('NFC')", value);
	}

	public static function isSafeInteger(value:Float):Bool {
		return Syntax.code("Number.isSafeInteger({0})", value);
	}

	public static function validateUnicode(value:String, label:String):Void {
		var index = 0;
		while (index < value.length) {
			final code = value.charCodeAt(index);
			if (code >= 0xd800 && code <= 0xdbff) {
				if (index + 1 >= value.length) {
					fail(label + " contains an unpaired UTF-16 surrogate", "invalid-unicode");
				}
				final next = value.charCodeAt(index + 1);
				if (next < 0xdc00 || next > 0xdfff) {
					fail(label + " contains an unpaired UTF-16 surrogate", "invalid-unicode");
				}
				index += 2;
				continue;
			}
			if (code >= 0xdc00 && code <= 0xdfff) {
				fail(label + " contains an unpaired UTF-16 surrogate", "invalid-unicode");
			}
			index++;
		}
	}

	public static function fail<T>(message:String, code:String = "ownership-json"):T {
		throw new OwnershipFailure(message, code);
	}

	static function decodeUtf8(buffer:Buffer, label:String):String {
		final value = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(value, "utf8")) != 0) {
			fail(label + " is not valid UTF-8", "invalid-utf8");
		}
		return value;
	}

	static function validateValue(value:JsonValue, location:String):Void {
		switch value {
			case NullValue | BoolValue(_):
			case NumberValue(source):
				if (!INTEGER.match(source)) {
					fail(location + " contains a floating-point JSON number", "non-integer-json");
				}
				final parsed = Std.parseFloat(source);
				if (!isSafeInteger(parsed)) {
					fail(location + " contains an unsafe JSON number", "non-integer-json");
				}
			case StringValue(value):
				validateUnicode(value, location);
				if (nfc(value) != value) {
					fail(location + " contains a non-NFC string", "non-nfc-json");
				}
			case ArrayValue(values):
				for (index in 0...values.length) {
					validateValue(values[index], location + "[" + index + "]");
				}
			case ObjectValue(fields):
				final normalized = new Map<String, Bool>();
				for (field in fields) {
					validateUnicode(field.name, location + " key");
					final name = nfc(field.name);
					if (name != field.name) {
						fail(location + " contains a non-NFC object key", "non-nfc-json");
					}
					if (normalized.exists(name)) {
						fail(location + " contains a duplicate object key after NFC normalization: " + name, "malformed-json");
					}
					normalized.set(name, true);
					validateValue(field.value, location + "." + name);
				}
		}
	}

	static function encodeValue(value:JsonValue, location:String):String {
		return switch value {
			case NullValue: "null";
			case BoolValue(value): value ? "true" : "false";
			case NumberValue(source): source;
			case StringValue(value): Json.stringify(value);
			case ArrayValue(values):
				"[" + [
					for (index in 0...values.length)
						encodeValue(values[index], location + "[" + index + "]")
				].join(",") + "]";
			case ObjectValue(fields):
				final sorted:Array<JsonField> = fields.copy();
				sorted.sort((left, right) -> compareText(left.name, right.name));
				"{" + [
					for (field in sorted)
						Json.stringify(field.name) + ":" + encodeValue(field.value, location + "." + field.name)
				].join(",") + "}";
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

/** Closed ergonomic inputs accepted by the canonical ownership object builder. **/
abstract OwnershipJsonField(JsonValue) {
	public inline function json():JsonValue {
		return this;
	}

	@:from public static inline function fromJson(value:JsonValue):OwnershipJsonField {
		return new OwnershipJsonField(value);
	}

	@:from public static inline function fromString(value:String):OwnershipJsonField {
		return new OwnershipJsonField(StringValue(value));
	}

	@:from public static inline function fromInt(value:Int):OwnershipJsonField {
		return new OwnershipJsonField(NumberValue(Std.string(value)));
	}

	@:from public static inline function fromBool(value:Bool):OwnershipJsonField {
		return new OwnershipJsonField(BoolValue(value));
	}

	@:from public static function fromStrings(values:Array<String>):OwnershipJsonField {
		return new OwnershipJsonField(ArrayValue([for (value in values) StringValue(value)]));
	}

	@:from public static inline function fromJsonValues(values:Array<JsonValue>):OwnershipJsonField {
		return new OwnershipJsonField(ArrayValue(values));
	}

	inline function new(value:JsonValue) {
		this = value;
	}
}
