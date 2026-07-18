package wordpresshx.cli.project;

import haxe.Json;
import js.Syntax;
import js.node.Buffer;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Strict duplicate-aware JSON reader for human-formatted bootstrap documents. **/
class ProjectJson {
	public static function parseStrict(buffer:Buffer, label:String):Dynamic {
		final source = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(source, "utf8")) != 0) {
			fail(label + " is not valid UTF-8", "invalid-utf8");
		}
		final value = new StrictProjectJsonParser(source, label).parse();
		OwnershipJson.encode(value);
		return value;
	}

	public static function fail(message:String, code:String = "malformed-json"):Dynamic {
		throw new OwnershipFailure(message, code);
	}
}

private class StrictProjectJsonParser {
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
		};
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
		return ProjectJson.fail(label + " " + message);
	}
}
