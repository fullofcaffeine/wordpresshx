package fixtures.semanticcollector;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.CanonicalJson;
import wordpress.hx.build._internal.CanonicalJson.CanonicalJsonError;
import wordpress.hx.build._internal.JsonParser;
import wordpress.hx.build._internal.JsonParser.JsonParseError;

class JsonBoundaryTest {
	public static macro function run():Expr {
		assertEncoding('{"z":[true,null,-12],"a":"quote\\\" slash\\\\"}', '{"a":"quote\\\" slash\\\\","z":[true,null,-12]}');
		assertEncoding('{"escaped":"\\u0041"}', '{"escaped":"A"}');
		expectParseFailure('{"duplicate":1,"duplicate":2}');
		expectParseFailure('{"trailing":true,}');
		expectParseFailure('"\\uD800"');
		expectEncodingFailure("1.5");
		expectEncodingFailure("-0");
		expectEncodingFailure('"caf\\u00e9"');
		return macro null;
	}

	static function assertEncoding(source:String, expected:String):Void {
		final encoded = CanonicalJson.encode(JsonParser.parse(source));
		if (encoded != expected) {
			fail("canonical JSON mismatch: expected " + expected + ", found " + encoded);
		}
	}

	static function expectParseFailure(source:String):Void {
		try {
			JsonParser.parse(source);
		} catch (_:JsonParseError) {
			return;
		}
		fail("JSON parser accepted an invalid boundary value");
	}

	static function expectEncodingFailure(source:String):Void {
		try {
			CanonicalJson.encode(JsonParser.parse(source));
		} catch (_:CanonicalJsonError) {
			return;
		}
		fail("canonical encoder accepted an unsupported boundary value");
	}

	static function fail(message:String):Void {
		throw message;
	}
}
#end
