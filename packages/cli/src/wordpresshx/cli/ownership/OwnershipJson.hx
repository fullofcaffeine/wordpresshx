package wordpresshx.cli.ownership;

import haxe.Json;
import haxe.crypto.Sha256;
import js.Syntax;
import js.node.Buffer;

/** Strict canonical JSON used by ownership manifests, journals, and locks. **/
class OwnershipJson {
	public static function parseCanonical(buffer:Buffer, label:String):Dynamic {
		final source = decodeUtf8(buffer, label);
		final parser = new StrictOwnershipJsonParser(source, label);
		final value = parser.parse();
		final expected = Buffer.from(encode(value) + "\n", "utf8");
		if (Buffer.compareBuffers(buffer, expected) != 0) {
			fail(label + " must use wordpress-hx.canonical-json.v1 plus exactly one final LF", "non-canonical-json");
		}
		return value;
	}

	public static function encode(value:Dynamic):String {
		return encodeValue(value, "$");
	}

	public static function encodeDocument(value:Dynamic):Buffer {
		return Buffer.from(encode(value) + "\n", "utf8");
	}

	public static function clone(value:Dynamic):Dynamic {
		return new StrictOwnershipJsonParser(encode(value), "canonical clone").parse();
	}

	public static function digest(buffer:Buffer):String {
		return Sha256.make(buffer.hxToBytes()).toHex().toLowerCase();
	}

	public static function digestValue(value:Dynamic):String {
		return digest(Buffer.from(encode(value), "utf8"));
	}

	public static function contentState(?buffer:Buffer):Dynamic {
		if (buffer == null) {
			return object(["state" => "absent"]);
		}
		return object(["state" => "file", "sha256" => digest(buffer), "sizeBytes" => buffer.length]);
	}

	public static function object(fields:Map<String, Dynamic>):Dynamic {
		final value:Dynamic = Syntax.code("Object.create(null)");
		for (field => child in fields) {
			Reflect.setField(value, field, child);
		}
		return value;
	}

	public static function nfc(value:String):String {
		return Syntax.code("{0}.normalize('NFC')", value);
	}

	public static function isSafeInteger(value:Dynamic):Bool {
		return Syntax.code("Number.isSafeInteger({0})", value);
	}

	public static function hasOwn(value:Dynamic, field:String):Bool {
		return Syntax.code("Object.prototype.hasOwnProperty.call({0}, {1})", value, field);
	}

	public static function fail(message:String, code:String = "ownership-json"):Dynamic {
		throw new OwnershipFailure(message, code);
	}

	static function decodeUtf8(buffer:Buffer, label:String):String {
		final value = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(value, "utf8")) != 0) {
			fail(label + " is not valid UTF-8", "invalid-utf8");
		}
		return value;
	}

	static function encodeValue(value:Dynamic, location:String):String {
		if (value == null) {
			return "null";
		}
		if (Std.isOfType(value, String)) {
			final text:String = cast value;
			validateUnicode(text, location);
			if (nfc(text) != text) {
				fail(location + " contains a non-NFC string", "non-nfc-json");
			}
			return Json.stringify(text);
		}
		if (Std.isOfType(value, Bool)) {
			return value ? "true" : "false";
		}
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) {
			if (!isSafeInteger(value)) {
				fail(location + " contains a floating-point or unsafe JSON number", "non-integer-json");
			}
			return Syntax.code("String({0})", value);
		}
		if (Std.isOfType(value, Array)) {
			final items:Array<Dynamic> = cast value;
			final encoded = [
				for (index in 0...items.length)
					encodeValue(items[index], location + "[" + index + "]")
			];
			return "[" + encoded.join(",") + "]";
		}
		if (!Reflect.isObject(value)) {
			fail(location + " contains an unsupported JSON value", "unsupported-json-value");
		}
		final fields = Reflect.fields(value);
		fields.sort(Reflect.compare);
		final encoded = [];
		for (field in fields) {
			validateUnicode(field, location + " key");
			if (nfc(field) != field) {
				fail(location + " contains a non-NFC object key", "non-nfc-json");
			}
			encoded.push(Json.stringify(field) + ":" + encodeValue(Reflect.field(value, field), location + "." + field));
		}
		return "{" + encoded.join(",") + "}";
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
}

private class StrictOwnershipJsonParser {
	final source:String;
	final label:String;
	var offset:Int = 0;

	public function new(source:String, label:String) {
		this.source = source;
		this.label = label;
	}

	public function parse():Dynamic {
		skipWhitespace();
		final value = parseValue("$");
		skipWhitespace();
		if (offset != source.length) {
			fail("contains trailing JSON content");
		}
		return value;
	}

	function parseValue(location:String):Dynamic {
		if (offset >= source.length) {
			fail("ends before a JSON value");
		}
		return switch (source.charAt(offset)) {
			case "{": parseObject(location);
			case "[": parseArray(location);
			case '"': parseString(location);
			case "t": parseKeyword("true", true);
			case "f": parseKeyword("false", false);
			case "n": parseKeyword("null", null);
			case "-": parseNumber(location);
			case digit if (digit >= "0" && digit <= "9"): parseNumber(location);
			case _: fail("contains an invalid JSON token at byte-like offset " + offset);
		}
	}

	function parseObject(location:String):Dynamic {
		offset++;
		final result:Dynamic = Syntax.code("Object.create(null)");
		skipWhitespace();
		if (take("}")) {
			return result;
		}
		while (true) {
			if (offset >= source.length || source.charAt(offset) != '"') {
				fail("contains an object key that is not a JSON string");
			}
			final rawKey:String = parseString(location + " key");
			final key = OwnershipJson.nfc(rawKey);
			if (OwnershipJson.hasOwn(result, key)) {
				fail("contains a duplicate object key after NFC normalization: " + key);
			}
			skipWhitespace();
			expect(":");
			skipWhitespace();
			Reflect.setField(result, key, parseValue(location + "." + key));
			skipWhitespace();
			if (take("}")) {
				return result;
			}
			expect(",");
			skipWhitespace();
		}
		return result;
	}

	function parseArray(location:String):Array<Dynamic> {
		offset++;
		final result:Array<Dynamic> = [];
		skipWhitespace();
		if (take("]")) {
			return result;
		}
		while (true) {
			result.push(parseValue(location + "[" + result.length + "]"));
			skipWhitespace();
			if (take("]")) {
				return result;
			}
			expect(",");
			skipWhitespace();
		}
		return result;
	}

	function parseString(location:String):String {
		final start = offset;
		offset++;
		while (offset < source.length) {
			final code = source.charCodeAt(offset);
			if (code == 0x22) {
				offset++;
				final value:Dynamic = Json.parse(source.substring(start, offset));
				if (!Std.isOfType(value, String)) {
					fail("contains an invalid JSON string");
				}
				final text:String = cast value;
				OwnershipJson.validateUnicode(text, location);
				return text;
			}
			if (code < 0x20) {
				fail("contains an unescaped JSON string control character");
			}
			if (code == 0x5c) {
				offset++;
				if (offset >= source.length) {
					fail("ends in a JSON string escape");
				}
				final escape = source.charAt(offset);
				if (escape == "u") {
					if (offset + 4 >= source.length) {
						fail("contains a truncated Unicode escape");
					}
					for (index in offset + 1...offset + 5) {
						final hex = source.charAt(index).toLowerCase();
						if (!((hex >= "0" && hex <= "9") || (hex >= "a" && hex <= "f"))) {
							fail("contains an invalid Unicode escape");
						}
					}
					offset += 5;
					continue;
				}
				if ('"\\/bfnrt'.indexOf(escape) < 0) {
					fail("contains an invalid JSON string escape");
				}
			}
			offset++;
		}
		return fail("contains an unterminated JSON string");
	}

	function parseNumber(location:String):Dynamic {
		final start = offset;
		if (take("-")) {}
		if (offset >= source.length) {
			fail("ends in a JSON number");
		}
		if (take("0")) {
			if (offset < source.length && isDigit(source.charAt(offset))) {
				fail("contains a JSON number with a leading zero");
			}
		} else {
			final first = source.charAt(offset);
			if (first < "1" || first > "9") {
				fail("contains an invalid JSON number");
			}
			offset++;
			while (offset < source.length && isDigit(source.charAt(offset))) {
				offset++;
			}
		}
		if (offset < source.length && (source.charAt(offset) == "." || source.charAt(offset).toLowerCase() == "e")) {
			fail(location + " uses a floating-point JSON number");
		}
		final value:Dynamic = Std.parseFloat(source.substring(start, offset));
		if (!OwnershipJson.isSafeInteger(value)) {
			fail(location + " uses an unsafe JSON integer");
		}
		return value;
	}

	function parseKeyword(token:String, value:Dynamic):Dynamic {
		if (source.substr(offset, token.length) != token) {
			fail("contains an invalid JSON keyword");
		}
		offset += token.length;
		return value;
	}

	function skipWhitespace():Void {
		while (offset < source.length && " \t\r\n".indexOf(source.charAt(offset)) >= 0) {
			offset++;
		}
	}

	function take(token:String):Bool {
		if (source.substr(offset, token.length) != token) {
			return false;
		}
		offset += token.length;
		return true;
	}

	function expect(token:String):Void {
		if (!take(token)) {
			fail("expected '" + token + "' at byte-like offset " + offset);
		}
	}

	inline function isDigit(value:String):Bool {
		return value >= "0" && value <= "9";
	}

	function fail(message:String):Dynamic {
		return OwnershipJson.fail(label + " " + message, "malformed-json");
	}
}
