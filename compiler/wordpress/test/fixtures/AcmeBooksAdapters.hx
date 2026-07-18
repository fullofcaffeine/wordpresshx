package fixtures;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressBlockRegistration;
import wordpress.hx.compiler.php.profile.WordPressHookKind;
import wordpress.hx.compiler.php.profile.WordPressHookRegistration;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterPlan;
import wordpress.hx.compiler.php.profile.WordPressPublicExport;
import wordpress.hx.compiler.php.profile.WordPressRestMethod;
import wordpress.hx.compiler.php.profile.WordPressRestRouteRegistration;

/** Haxe-only application input for the SDK-023 native WordPress adapter fixture. **/
class AcmeBooksAdapters {
	public static function plan():WordPressPublicAdapterPlan {
		return new WordPressPublicAdapterPlan(plugin(), id("PublicAdapters"), source(), properties(), methods(), hooks(), restRoutes(), blocks(), exports());
	}

	public static function plugin():PluginBootstrapPlan {
		return new PluginBootstrapPlan("acme-books-adapters", header(), PhpQualifiedName.relative("Acme\\BooksAdapters"), source());
	}

	public static function header():PluginHeader {
		return new PluginHeader("Acme Books Adapters", "Typed SDK-023 native WordPress adapter fixture.", "0.0.0", "7.0", "7.4", "WordPressHx SDK fixture",
			"LicenseRef-WordPressHx-Review-Pending", "acme-books-adapters");
	}

	public static function source():PhpSourceRange {
		return PhpSourceRange.at("compiler/wordpress/test/fixtures/AcmeBooksAdapters.hx", 27, 2, 28, 2);
	}

	public static function properties():Array<PhpProperty> {
		return [new PhpProperty(PhpPrivate, true, id("initialized"), PhpBool(false))];
	}

	public static function methods():Array<PhpMethod> {
		final fixtureSource = source();
		return [
			new PhpMethod(PhpPublic, true, false, id("onInit"), [], fixtureSource, PhpVoidType,
				[PhpAssign(PhpStaticProperty("self", "initialized"), PhpBool(true))]),
			new PhpMethod(PhpPublic, true, false, id("isInitialized"), [], fixtureSource, PhpBoolType, [PhpReturn(PhpStaticProperty("self", "initialized"))]),
			new PhpMethod(PhpPublic, true, false, id("filterTitle"), [parameter("title", PhpStringType), parameter("postId", PhpIntType)], fixtureSource,
				PhpStringType, [PhpReturn(PhpStaticCall("self", "normalizeTitleImpl", [PhpVar("title")]))]),
			new PhpMethod(PhpPublic, true, false, id("restPermission"), [parameter("request", namedType("\\WP_REST_Request"))], fixtureSource, PhpBoolType,
				[PhpReturn(PhpFunctionCall("\\current_user_can", [PhpString("read")]))]),
			new PhpMethod(PhpPublic, true, false, id("restBook"), [parameter("request", namedType("\\WP_REST_Request"))], fixtureSource, null, [
				PhpLocal("id", PhpCastInt(PhpMethodCall(PhpVar("request"), "get_param", [PhpString("id")]))),
				PhpLocal("payload", PhpStaticCall("self", "bookPayload", [PhpVar("id")])),
				PhpIf(PhpFunctionCall("\\is_wp_error", [PhpVar("payload")]), [PhpReturn(PhpVar("payload"))]),
				PhpReturn(PhpNew("\\WP_REST_Response", [PhpVar("payload"), PhpInt(200)]))
			]),
			new PhpMethod(PhpPublic, true, false, id("renderSummary"), [
				parameter("attributes", PhpArrayType),
				parameter("content", PhpStringType),
				parameter("block", namedType("\\WP_Block"))
			], fixtureSource, PhpStringType, [
				PhpLocal("title", PhpNullCoalesce(PhpArrayRead(PhpVar("attributes"), PhpString("title")), PhpString("Books"))),
				PhpReturn(PhpFunctionCall("\\sprintf", [
					PhpString("<section class=\"acme-books-summary\">%s</section>"),
					PhpFunctionCall("\\esc_html", [PhpCastString(PhpVar("title"))])
				]))
			]),
			new PhpMethod(PhpPublic, true, false, id("appendLabel"), [
				PhpParameter.named(id("labels"), PhpArrayType, true),
				parameter("label", PhpStringType)
			],
				fixtureSource, PhpVoidType, [PhpAssign(PhpArrayAppend(PhpVar("labels")), PhpVar("label"))]),
			new PhpMethod(PhpPublic, true, false, id("normalizeTitle"), [parameter("title", PhpStringType)], fixtureSource, PhpStringType,
				[PhpReturn(PhpStaticCall("self", "normalizeTitleImpl", [PhpVar("title")]))]),
			new PhpMethod(PhpPrivate, true, false, id("normalizeTitleImpl"), [parameter("title", PhpStringType)], fixtureSource, PhpStringType, [
				PhpReturn(PhpFunctionCall("\\strtoupper", [PhpFunctionCall("\\trim", [PhpVar("title")])]))
			]),
			new PhpMethod(PhpPrivate, true, false, id("bookPayload"), [parameter("id", PhpIntType)], fixtureSource, null, [
				PhpIf(PhpBinop("<=", PhpVar("id"), PhpInt(0)), [
					PhpReturn(PhpNew("\\WP_Error", [
						PhpString("acme_books_invalid_id"),
						PhpString("Book ID must be positive."),
						PhpLongArray([entry("status", PhpInt(400))])
					]))
				]),
				PhpReturn(PhpLongArray([
					entry("id", PhpVar("id")),
					entry("title", PhpBinop(".", PhpString("Book "), PhpCastString(PhpVar("id"))))
				]))
			])
		];
	}

	public static function hooks():Array<WordPressHookRegistration> {
		return [
			new WordPressHookRegistration(Action, "init", id("onInit"), 9, 0),
			new WordPressHookRegistration(Filter, "the_title", id("filterTitle"), 12, 2)
		];
	}

	public static function restRoutes():Array<WordPressRestRouteRegistration> {
		return [
			new WordPressRestRouteRegistration("acme-books/v1", "/books/(?P<id>[\\d]+)", Readable, id("restBook"), id("restPermission"))
		];
	}

	public static function blocks():Array<WordPressBlockRegistration> {
		return [new WordPressBlockRegistration("acme-books/summary", id("renderSummary"))];
	}

	public static function exports():Array<WordPressPublicExport> {
		return [
			new WordPressPublicExport(id("appendLabel")),
			new WordPressPublicExport(id("isInitialized")),
			new WordPressPublicExport(id("normalizeTitle"))
		];
	}

	public static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}

	public static function namedType(value:String):PhpType {
		return PhpNamedType(PhpQualifiedName.parse(value));
	}

	public static function parameter(name:String, type:PhpType):PhpParameter {
		return PhpParameter.named(id(name), type);
	}

	static function entry(key:String, value:PhpExpr):PhpArrayEntry {
		return {key: PhpString(key), value: value};
	}
}
