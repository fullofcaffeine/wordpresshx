package wordpresshx.cli.closedjson;

import js.node.Buffer;
import wordpresshx.cli.closedjson.CanonicalJson.CanonicalJsonError;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;

/** Canonical UTF-8 document boundary for typed JSON values. */
class JsonDocument {
	public static function parse(bytes:Buffer, label:String, code:String):JsonValue {
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			throw new JsonDocumentError(code, label + " must be valid UTF-8");
		}
		try {
			return JsonParser.parse(source);
		} catch (failure:JsonParseError) {
			throw new JsonDocumentError(code, label + " is invalid JSON: " + failure.message);
		}
	}

	public static function parseCanonical(bytes:Buffer, label:String, code:String):JsonValue {
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			throw new JsonDocumentError(code, label + " must be valid UTF-8");
		}
		if (!StringTools.endsWith(source, "\n")) {
			throw new JsonDocumentError(code, label + " must end with exactly one LF");
		}
		final body = source.substr(0, source.length - 1);
		try {
			final value = JsonParser.parse(body);
			if (CanonicalJson.encode(value) + "\n" != source) {
				throw new JsonDocumentError(code, label + " must use wordpress-hx.canonical-json.v1");
			}
			return value;
		} catch (failure:JsonParseError) {
			throw new JsonDocumentError(code, label + " is invalid JSON: " + failure.message);
		} catch (failure:CanonicalJsonError) {
			throw new JsonDocumentError(code, label + " is outside canonical JSON: " + failure.message);
		}
	}

	public static inline function encode(value:JsonValue):String {
		return CanonicalJson.encode(value) + "\n";
	}
}

class JsonDocumentError extends haxe.Exception {
	public final code:String;

	public function new(code:String, message:String) {
		this.code = code;
		super(message);
	}
}
