package wordpresshx.cli.project;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpClosureCapture;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
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
import wordpress.hx.compiler.php.profile.WordPressPhpPrinter;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterPlan;
import wordpress.hx.compiler.php.profile.WordPressPublicExport;
import wordpress.hx.compiler.php.profile.WordPressRestRouteRegistration;
import wordpress.hx.compiler.php.profile.Wp70PublicAdapterProfile;

/** Native public adapter and fail-closed loader for one private title filter. */
class PluginPrivatePhpProfile {
	static inline final POLYFILL_CONSTANT = "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256";

	public static function emit(plan:PluginPlan, runtime:PluginPrivateRuntime):Array<PluginEmittedFile> {
		final callback = plan.privateTitleFilter;
		if (callback == null) {
			throw new wordpresshx.cli.CliFailure("WPHX5200", "private PHP profile requires one compiler-resolved callback", 6, "private-php-emission");
		}
		final header = new PluginHeader(plan.name, plan.description, plan.version, "7.0", "7.4", plan.author, plan.license, plan.slug);
		final bootstrap = new PluginBootstrapPlan(plan.slug, header, PhpQualifiedName.relative(plan.namespace), pluginSource(plan));
		final callbackSource = PhpSourceRange.at(callback.sourcePath, callback.startLine, callback.startColumn, callback.endLine, callback.endColumn);
		final methods:Array<PhpMethod> = [
			new PhpMethod(PhpPublic, true, false, id("filterTitle"), [
				PhpParameter.named(id("title"), PhpStringType),
				PhpParameter.named(id("postId"), PhpIntType)
			], callbackSource, PhpStringType, [
				PhpReturn(PhpCastString(PhpStaticCall("\\" + runtime.privateClass, callback.methodName, [PhpVar("title"), PhpVar("postId")])))
			])
		];
		final properties:Array<PhpProperty> = [];
		final hooks:Array<WordPressHookRegistration> = [new WordPressHookRegistration(Filter, "the_title", id("filterTitle"), 10, 2)];
		final restRoutes:Array<WordPressRestRouteRegistration> = [];
		final blocks:Array<WordPressBlockRegistration> = [];
		final exports:Array<WordPressPublicExport> = [];
		final adapter = new WordPressPublicAdapterPlan(bootstrap, id("PrivateBridge"), callbackSource, properties, methods, hooks, restRoutes, blocks, exports);
		final artifact = new Wp70PublicAdapterProfile().emitPlugin(adapter);
		final loader = loaderSource(plan, runtime);
		final root = rootSource(bootstrap);
		return [
			for (file in artifact.files)
				new PluginEmittedFile(PublicNative, file.role, file.path,
					file.path == bootstrap.rootPath ? root : file.path == bootstrap.autoloadPath ? loader : file.source)
		];
	}

	static function rootSource(plan:PluginBootstrapPlan):String {
		final statements:Array<PhpStmt> = [
			PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString("ABSPATH")])), [PhpReturnVoid]),
			PhpLocal("autoloadStatus", PhpRequire(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/" + plan.autoloadPath)), true)),
			PhpIf(PhpBinop("||", PhpBinop("!==", PhpVar("autoloadStatus"), PhpBool(true)),
				PhpNot(PhpFunctionCall("class_exists", [PhpString(plan.absoluteBootstrapClass), PhpBool(false)]))),
				[PhpReturnVoid]),
			PhpExprStmt(PhpStaticCall(plan.absoluteBootstrapClass, "boot", []))
		];
		return new WordPressPhpPrinter().printPluginRoot(plan.header, new PhpFile(plan.rootPath, null, false, [], statements)).source;
	}

	static function loaderSource(plan:PluginPlan, runtime:PluginPrivateRuntime):String {
		final polyfillFunctions:Array<PhpArrayEntry> = [
			for (name in ["mb_chr", "mb_ord", "mb_scrub", "str_starts_with"])
				{key: null, value: PhpString(name)}
		];
		final rejectOwned:Array<PhpStmt> = [
			PhpExprStmt(PhpFunctionCall("error_log", [
				PhpString("WPHX5201 WordPressHx private runtime rejected its global polyfill file.")
			])),
			PhpReturn(PhpBool(false))
		];
		final rejectMarker:Array<PhpStmt> = [
			PhpExprStmt(PhpFunctionCall("error_log", [
				PhpString("WPHX5201 WordPressHx private runtime rejected an incompatible global polyfill marker.")
			])),
			PhpReturn(PhpBool(false))
		];
		final statements:Array<PhpStmt> = [
			PhpLocal("polyfillSha256", PhpString(runtime.polyfillSha256)),
			PhpLocal("ownedPolyfill", PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/../private/wordpresshx/runtime/" + requiredPolyfillPath(runtime)))),
			PhpLocal("ownedPolyfillSha256",
				PhpTernary(PhpFunctionCall("is_file", [PhpVar("ownedPolyfill")]),
					PhpFunctionCall("hash_file", [PhpString("sha256"), PhpVar("ownedPolyfill")]), PhpBool(false))),
			PhpIf(PhpBinop("!==", PhpVar("ownedPolyfillSha256"), PhpVar("polyfillSha256")), rejectOwned),
			PhpIf(PhpFunctionCall("defined", [PhpString(POLYFILL_CONSTANT)]), [
				PhpLocal("activePolyfillSha256", PhpFunctionCall("constant", [PhpString(POLYFILL_CONSTANT)])),
				PhpIf(PhpBinop("!==", PhpVar("activePolyfillSha256"), PhpVar("polyfillSha256")), rejectMarker)
			]),
			PhpLocal("polyfillFunctions", PhpLongArray(polyfillFunctions)),
			PhpForeach(PhpVar("polyfillFunctions"), "polyfillFunction", [
				PhpIf(PhpNot(PhpFunctionCall("function_exists", [PhpVar("polyfillFunction")])), [PhpContinue]),
				PhpLocal("reflection", PhpNew("\\ReflectionFunction", [PhpVar("polyfillFunction")])),
				PhpIf(PhpMethodCall(PhpVar("reflection"), "isInternal", []), [PhpContinue]),
				PhpLocal("declaringFile", PhpMethodCall(PhpVar("reflection"), "getFileName", [])),
				PhpLocal("declaringSha256",
					PhpTernary(PhpBinop("&&", PhpFunctionCall("is_string", [PhpVar("declaringFile")]), PhpFunctionCall("is_file", [PhpVar("declaringFile")])),
						PhpFunctionCall("hash_file", [PhpString("sha256"), PhpVar("declaringFile")]), PhpBool(false))),
				PhpIf(PhpBinop("!==", PhpVar("declaringSha256"), PhpVar("polyfillSha256")), [
					PhpExprStmt(PhpFunctionCall("error_log", [
						PhpBinop(".", PhpString("WPHX5201 WordPressHx private runtime rejected incompatible global function "),
							PhpBinop(".", PhpVar("polyfillFunction"), PhpString(".")))
					])),
					PhpReturn(PhpBool(false))
				])
			]),
			PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString(POLYFILL_CONSTANT)])),
				[
					PhpExprStmt(PhpFunctionCall("define", [PhpString(POLYFILL_CONSTANT), PhpVar("polyfillSha256")]))
				]),
			PhpRequireOnce(PhpVar("ownedPolyfill")),
			PhpLocal("classMap", PhpRequire(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/../private/wordpresshx/classmap.php")), false)),
			PhpIf(PhpNot(PhpFunctionCall("is_array", [PhpVar("classMap")])), [
				PhpExprStmt(PhpFunctionCall("error_log", [PhpString("WPHX5202 WordPressHx private runtime rejected its class map.")])),
				PhpReturn(PhpBool(false))
			]),
			PhpLocal("autoloadRegistered", PhpFunctionCall("spl_autoload_register", [
				PhpClosure([PhpParameter.named(id("className"), PhpStringType)], [new PhpClosureCapture(id("classMap"))], [
					PhpIf(PhpFunctionCall("isset", [PhpArrayRead(PhpVar("classMap"), PhpVar("className"))]),
						[PhpRequireOnce(PhpArrayRead(PhpVar("classMap"), PhpVar("className")))])
				], true, PhpVoidType),
				PhpBool(true),
				PhpBool(false)
			])),
			PhpIf(PhpBinop("!==", PhpVar("autoloadRegistered"), PhpBool(true)), [
				PhpExprStmt(PhpFunctionCall("error_log",
					[
						PhpString("WPHX5202 WordPressHx private runtime could not register its class map.")
					])),
				PhpReturn(PhpBool(false))
			]),
			includePublic("/Bootstrap.php"),
			includePublic("/PrivateBridge.php"),
			includePublic("/register-adapters.php"),
			PhpReturn(PhpBool(true))
		];
		return new WordPressPhpPrinter().print(new PhpFile("includes/autoload.php", null, true, [], statements)).source;
	}

	static function requiredPolyfillPath(runtime:PluginPrivateRuntime):String {
		for (file in runtime.files) {
			if (file.lane == PrivateRuntime && StringTools.endsWith(file.relativePath, "/_polyfills.php")) {
				return file.relativePath.substr("private/wordpresshx/runtime/".length);
			}
		}
		throw new wordpresshx.cli.CliFailure("WPHX5200", "private PHP package lost its admitted polyfill path", 6, "private-php-emission");
	}

	static function includePublic(path:String):PhpStmt {
		return PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString(path)));
	}

	static function pluginSource(plan:PluginPlan):PhpSourceRange {
		return PhpSourceRange.at(plan.sourcePath, plan.startLine, plan.startColumn, plan.endLine, plan.endColumn);
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}
}
