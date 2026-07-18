package fixtures;

import haxe.io.Bytes;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceFile;
import reflaxe.php.ir.PhpSourceKind;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
import sys.io.File;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressBlockRegistration;
import wordpress.hx.compiler.php.profile.WordPressHookRegistration;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterPlan;
import wordpress.hx.compiler.php.profile.WordPressPublicExport;
import wordpress.hx.compiler.php.profile.WordPressRestRouteRegistration;

/** Exact-source SDK-025 fixture plan covering public, private, REST, and render failures. **/
class SourceCorrelationFixture {
	public static inline final SOURCE_PATH = "test/fixtures/SourceCorrelationCallbacks.hx";

	public static function plan():WordPressPublicAdapterPlan {
		final source = sourceFile();
		return new WordPressPublicAdapterPlan(plugin(), id("FailureCallbacks"), classRange(source), [], methods(source), [
			new WordPressHookRegistration(Action, "wordpresshx_fixture_fail", id("failHook"), 10, 0)
		], [
			new WordPressRestRouteRegistration("wordpresshx-fixture/v1", "/fail", Readable, id("failRest"), id("allowRest"))
		],
			[new WordPressBlockRegistration("wordpresshx-fixture/failure", id("failRender"))], [new WordPressPublicExport(id("failPrivate"))],
			"fixture:source-correlation:class");
	}

	public static function sourceFile():PhpSourceFile {
		return new PhpSourceFile("fixture:source-correlation", "project", "compiler/wordpress/" + SOURCE_PATH, PhpHaxeSource, File.getContent(SOURCE_PATH));
	}

	static function plugin():PluginBootstrapPlan {
		return new PluginBootstrapPlan("source-correlation",
			new PluginHeader("Source Correlation", "SDK-025 exact PHP trace fixture.", "0.0.0", "7.0", "7.4", "WordPressHx SDK fixture",
				"LicenseRef-WordPressHx-Review-Pending", "source-correlation"),
			PhpQualifiedName.relative("Fixture\\Correlation"), PhpSourceRange.at("test/fixtures/SourceCorrelationFixture.hx", 1, 1, 1, 2));
	}

	static function methods(source:PhpSourceFile):Array<PhpMethod> {
		return [
			new PhpMethod(PhpPublic, true, false, id("failHook"), [], methodRange(source, "failHook"), PhpVoidType,
				[mappedThrow(source, "hook failure", "hook")], "fixture:source-correlation:method:hook"),
			new PhpMethod(PhpPublic, true, false, id("allowRest"), [parameter("request", namedType("\\WP_REST_Request"))], methodRange(source, "allowRest"),
				PhpBoolType, [PhpReturn(PhpBool(true))], "fixture:source-correlation:method:rest-permission"),
			new PhpMethod(PhpPublic, true, false, id("failRest"), [parameter("request", namedType("\\WP_REST_Request"))], methodRange(source, "failRest"),
				null, [mappedThrow(source, "rest failure", "rest")], "fixture:source-correlation:method:rest"),
			new PhpMethod(PhpPublic, true, false, id("failRender"), [
				parameter("attributes", PhpArrayType),
				parameter("content", PhpStringType),
				parameter("block", namedType("\\WP_Block"))
			],
				methodRange(source, "failRender"), PhpStringType, [mappedThrow(source, "render failure", "render")],
				"fixture:source-correlation:method:render"),
			new PhpMethod(PhpPublic, true, false, id("failPrivate"), [], methodRange(source, "failPrivate"), PhpVoidType,
				[PhpExprStmt(PhpStaticCall("self", "privateFailure", []))], "fixture:source-correlation:method:private-entry"),
			new PhpMethod(PhpPrivate, true, false, id("privateFailure"), [], methodRange(source, "privateFailure"), PhpVoidType,
				[mappedThrow(source, "private failure", "private")], "fixture:source-correlation:method:private")
		];
	}

	static function mappedThrow(source:PhpSourceFile, message:String, identity:String):PhpStmt {
		return PhpMapped(PhpThrow(PhpNew("\\RuntimeException", [PhpString(message)])), exactNeedle(source, 'throw new haxe.Exception("' + message + '");'),
			"fixture:source-correlation:throw:" + identity, true);
	}

	static function classRange(source:PhpSourceFile):PhpSourceRange {
		final start = source.content.indexOf("class SourceCorrelationCallbacks");
		return exactCharacters(source, start, source.content.length);
	}

	static function methodRange(source:PhpSourceFile, name:String):PhpSourceRange {
		var start = source.content.indexOf("public static function " + name);
		if (start < 0) {
			start = source.content.indexOf("static function " + name);
		}
		final end = source.content.indexOf("\n\t}", start) + 3;
		if (start < 0 || end <= start + 2) {
			throw "Could not locate exact source method: " + name;
		}
		return exactCharacters(source, start, end);
	}

	static function exactNeedle(source:PhpSourceFile, needle:String):PhpSourceRange {
		final start = source.content.indexOf(needle);
		if (start < 0 || source.content.indexOf(needle, start + needle.length) >= 0) {
			throw "Exact source needle must occur once: " + needle;
		}
		return exactCharacters(source, start, start + needle.length);
	}

	static function exactCharacters(source:PhpSourceFile, start:Int, end:Int):PhpSourceRange {
		if (start < 0 || end <= start || end > source.content.length) {
			throw "Exact source character range is invalid";
		}
		return source.exactRange(Bytes.ofString(source.content.substr(0, start)).length, Bytes.ofString(source.content.substr(0, end)).length);
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}

	static function namedType(value:String):PhpType {
		return PhpNamedType(PhpQualifiedName.parse(value));
	}

	static function parameter(name:String, type:PhpType):PhpParameter {
		return PhpParameter.named(id(name), type);
	}
}
