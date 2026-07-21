package wordpresshx.cli.project;

import haxe.crypto.Sha256;
import js.node.Buffer;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Closed JSON boundary for human-authored project files and generated project data. **/
class ProjectJson {
	public static function parseStrict(buffer:Buffer, label:String):JsonValue {
		final source = decodeUtf8(buffer, label);
		final value = try {
			JsonParser.parse(source);
		} catch (failure:JsonParseError) {
			fail(label + " " + failure.message, "malformed-json");
		}
		// Encoding validates Unicode, NFC, integer bounds, duplicate keys, and the closed value algebra.
		OwnershipJson.encode(value);
		return value;
	}

	public static function parseCanonical(buffer:Buffer, label:String):JsonValue {
		final value = parseStrict(buffer, label);
		final expected = encodeDocument(value);
		if (Buffer.compareBuffers(buffer, expected) != 0) {
			fail(label + " must use wordpress-hx.canonical-json.v1 plus exactly one final LF", "non-canonical-json");
		}
		return value;
	}

	public static inline function encode(value:JsonValue):String {
		return OwnershipJson.encode(value);
	}

	public static inline function encodeDocument(value:JsonValue):Buffer {
		return OwnershipJson.encodeDocument(value);
	}

	public static inline function clone(value:JsonValue):JsonValue {
		return OwnershipJson.clone(value);
	}

	public static function digest(buffer:Buffer):String {
		return Sha256.make(buffer.hxToBytes()).toHex().toLowerCase();
	}

	public static inline function digestValue(value:JsonValue):String {
		return OwnershipJson.digestValue(value);
	}

	public static function generationDigest(files:Array<JsonValue>):String {
		final material = ArrayValue([
			for (file in files)
				object([
					"contentSha256" => text(ProjectContract.string(file, "contentSha256", "manifest file")),
					"path" => text(ProjectContract.string(file, "path", "manifest file")),
					"sizeBytes" => number(ProjectContract.integer(file, "sizeBytes", "manifest file"))
				])
		]);
		return digestValue(material);
	}

	public static function object(fields:Map<String, ProjectJsonField>):JsonValue {
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

	public static inline function boolean(value:Bool):JsonValue {
		return BoolValue(value);
	}

	public static inline function nullableText(value:Null<String>):JsonValue {
		return value == null ? NullValue : StringValue(value);
	}

	public static inline function closed(value:JsonValue):JsonValue {
		return value;
	}

	public static function withDigest(value:JsonValue, field:String):JsonValue {
		final without = withoutField(value, field, false);
		return setField(without, field, text(digestValue(without)));
	}

	public static function setField(value:JsonValue, name:String, child:JsonValue):JsonValue {
		return switch value {
			case ObjectValue(fields):
				final result:Array<JsonField> = [for (field in fields) if (field.name != name) field];
				result.push({name: name, value: child});
				ObjectValue(result);
			case _:
				fail("project JSON document must be an object", "contract-shape");
		};
	}

	public static function withoutField(value:JsonValue, name:String, required:Bool = true):JsonValue {
		return switch value {
			case ObjectValue(fields):
				final result:Array<JsonField> = [for (field in fields) if (field.name != name) field];
				if (required && result.length != fields.length - 1) {
					fail("project JSON document must contain exactly one " + name + " field", "contract-shape");
				}
				ObjectValue(result);
			case _:
				fail("project JSON document must be an object", "contract-shape");
		};
	}

	public static inline function nfc(value:String):String {
		return OwnershipJson.nfc(value);
	}

	public static inline function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	public static function fail<T>(message:String, code:String = "malformed-json"):T {
		throw new OwnershipFailure(message, code);
	}

	static function decodeUtf8(buffer:Buffer, label:String):String {
		final value = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(value, "utf8")) != 0) {
			fail(label + " is not valid UTF-8", "invalid-utf8");
		}
		return value;
	}
}

/** Finite ergonomic inputs for project JSON builders; arbitrary runtime values are impossible. **/
abstract ProjectJsonField(JsonValue) {
	public inline function json():JsonValue {
		return this;
	}

	@:from public static inline function fromJson(value:JsonValue):ProjectJsonField {
		return new ProjectJsonField(value);
	}

	@:from public static inline function fromString(value:String):ProjectJsonField {
		return new ProjectJsonField(StringValue(value));
	}

	@:from public static inline function fromInt(value:Int):ProjectJsonField {
		return new ProjectJsonField(NumberValue(Std.string(value)));
	}

	@:from public static inline function fromBool(value:Bool):ProjectJsonField {
		return new ProjectJsonField(BoolValue(value));
	}

	@:from public static function fromStrings(values:Array<String>):ProjectJsonField {
		return new ProjectJsonField(ArrayValue([for (value in values) StringValue(value)]));
	}

	@:from public static inline function fromJsonValues(values:Array<JsonValue>):ProjectJsonField {
		return new ProjectJsonField(ArrayValue(values));
	}

	inline function new(value:JsonValue) {
		this = value;
	}
}
