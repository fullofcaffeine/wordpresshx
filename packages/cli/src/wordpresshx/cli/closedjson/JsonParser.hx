package wordpresshx.cli.closedjson;

import haxe.Exception;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Deterministic parser that never exposes an open runtime object. */
class JsonParser {
	final source:String;
	var offset:Int;

	public static function parse(source:String):JsonValue {
		return new JsonParser(source).parseDocument();
	}

	function new(source:String) {
		this.source = source;
		offset = 0;
	}

	function parseDocument():JsonValue {
		skipWhitespace();
		final value = parseValue();
		skipWhitespace();
		if (offset != source.length) {
			invalid("unexpected trailing content");
		}
		return value;
	}

	function parseValue():JsonValue {
		if (offset >= source.length) {
			invalid("expected a JSON value");
		}
		return switch source.charCodeAt(offset) {
			case 0x7b: parseObject();
			case 0x5b: parseArray();
			case 0x22: StringValue(parseString());
			case 0x74:
				requireLiteral("true");
				BoolValue(true);
			case 0x66:
				requireLiteral("false");
				BoolValue(false);
			case 0x6e:
				requireLiteral("null");
				NullValue;
			case code if (code == 0x2d || isDigit(code)): NumberValue(parseNumber());
			case _: invalid("expected a JSON value");
		};
	}

	function parseObject():JsonValue {
		offset++;
		skipWhitespace();
		final fields:Array<JsonField> = [];
		final names:Map<String, Bool> = [];
		if (consume(0x7d)) {
			return ObjectValue(fields);
		}
		while (true) {
			if (!consume(0x22)) {
				invalid("object field name must be a string");
			}
			final name = parseStringBody();
			if (names.exists(name)) {
				invalid("duplicate object field " + name);
			}
			names.set(name, true);
			skipWhitespace();
			if (!consume(0x3a)) {
				invalid("expected : after object field name");
			}
			skipWhitespace();
			fields.push({name: name, value: parseValue()});
			skipWhitespace();
			if (consume(0x7d)) {
				return ObjectValue(fields);
			}
			if (!consume(0x2c)) {
				invalid("expected , or } in object");
			}
			skipWhitespace();
		}
		return invalid("unterminated object");
	}

	function parseArray():JsonValue {
		offset++;
		skipWhitespace();
		final values:Array<JsonValue> = [];
		if (consume(0x5d)) {
			return ArrayValue(values);
		}
		while (true) {
			values.push(parseValue());
			skipWhitespace();
			if (consume(0x5d)) {
				return ArrayValue(values);
			}
			if (!consume(0x2c)) {
				invalid("expected , or ] in array");
			}
			skipWhitespace();
		}
		return invalid("unterminated array");
	}

	function parseString():String {
		offset++;
		return parseStringBody();
	}

	function parseStringBody():String {
		final result = new StringBuf();
		while (offset < source.length) {
			final code = source.charCodeAt(offset++);
			if (code == 0x22) {
				return result.toString();
			}
			if (code < 0x20) {
				invalid("unescaped control character in string");
			}
			if (code != 0x5c) {
				result.addChar(code);
				continue;
			}
			if (offset >= source.length) {
				invalid("unterminated string escape");
			}
			final escape = source.charCodeAt(offset++);
			switch escape {
				case 0x22, 0x2f, 0x5c:
					result.addChar(escape);
				case 0x62:
					result.addChar(0x08);
				case 0x66:
					result.addChar(0x0c);
				case 0x6e:
					result.addChar(0x0a);
				case 0x72:
					result.addChar(0x0d);
				case 0x74:
					result.addChar(0x09);
				case 0x75:
					addUnicodeEscape(result);
				case _:
					invalid("invalid string escape");
			}
		}
		return invalid("unterminated string");
	}

	function addUnicodeEscape(result:StringBuf):Void {
		final first = parseHexQuad();
		if (first >= 0xd800 && first <= 0xdbff) {
			if (offset + 2 > source.length || source.charCodeAt(offset) != 0x5c || source.charCodeAt(offset + 1) != 0x75) {
				invalid("high surrogate must be followed by a low surrogate");
			}
			offset += 2;
			final second = parseHexQuad();
			if (second < 0xdc00 || second > 0xdfff) {
				invalid("high surrogate must be followed by a low surrogate");
			}
			result.addChar(0x10000 + ((first - 0xd800) << 10) + second - 0xdc00);
			return;
		}
		if (first >= 0xdc00 && first <= 0xdfff) {
			invalid("unexpected low surrogate");
		}
		result.addChar(first);
	}

	function parseHexQuad():Int {
		if (offset + 4 > source.length) {
			invalid("incomplete Unicode escape");
		}
		var value = 0;
		for (_ in 0...4) {
			final digit = hexDigit(source.charCodeAt(offset++));
			if (digit < 0) {
				invalid("invalid Unicode escape");
			}
			value = (value << 4) | digit;
		}
		return value;
	}

	function parseNumber():String {
		final start = offset;
		consume(0x2d);
		if (offset >= source.length) {
			invalid("incomplete number");
		}
		if (consume(0x30)) {
			if (offset < source.length && isDigit(source.charCodeAt(offset))) {
				invalid("number contains a leading zero");
			}
		} else {
			requireDigits("number requires an integer part");
		}
		if (consume(0x2e)) {
			requireDigits("number requires digits after the decimal point");
		}
		if (offset < source.length && (source.charCodeAt(offset) == 0x65 || source.charCodeAt(offset) == 0x45)) {
			offset++;
			if (offset < source.length && (source.charCodeAt(offset) == 0x2b || source.charCodeAt(offset) == 0x2d)) {
				offset++;
			}
			requireDigits("number requires exponent digits");
		}
		return source.substr(start, offset - start);
	}

	function requireDigits(message:String):Void {
		final start = offset;
		while (offset < source.length && isDigit(source.charCodeAt(offset))) {
			offset++;
		}
		if (offset == start) {
			invalid(message);
		}
	}

	function requireLiteral(literal:String):Void {
		if (source.substr(offset, literal.length) != literal) {
			invalid("invalid literal");
		}
		offset += literal.length;
	}

	function skipWhitespace():Void {
		while (offset < source.length) {
			switch source.charCodeAt(offset) {
				case 0x20, 0x09, 0x0a, 0x0d:
					offset++;
				case _:
					return;
			}
		}
	}

	function consume(code:Int):Bool {
		if (offset < source.length && source.charCodeAt(offset) == code) {
			offset++;
			return true;
		}
		return false;
	}

	static function isDigit(code:Int):Bool {
		return code >= 0x30 && code <= 0x39;
	}

	static function hexDigit(code:Int):Int {
		if (code >= 0x30 && code <= 0x39) {
			return code - 0x30;
		}
		if (code >= 0x41 && code <= 0x46) {
			return code - 0x41 + 10;
		}
		if (code >= 0x61 && code <= 0x66) {
			return code - 0x61 + 10;
		}
		return -1;
	}

	function invalid<T>(message:String):T {
		throw new JsonParseError(message, offset);
	}
}

class JsonParseError extends Exception {
	public final offset:Int;

	public function new(message:String, offset:Int) {
		this.offset = offset;
		super(message + " at byte " + offset);
	}
}
