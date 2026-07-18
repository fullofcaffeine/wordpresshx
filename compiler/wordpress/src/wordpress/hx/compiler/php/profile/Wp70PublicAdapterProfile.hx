package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
import wordpress.hx.compiler.php.profile.WordPressRestMethod.WordPressRestMethodTools;

/** Native hook/REST/block/export emitter for the exact wp70-release profile. **/
class Wp70PublicAdapterProfile {
	final printer:WordPressPhpPrinter;
	final bootstrap:Wp70PhpProfile;

	public function new() {
		printer = new WordPressPhpPrinter();
		bootstrap = new Wp70PhpProfile();
	}

	public function emitPlugin(plan:WordPressPublicAdapterPlan):WordPressPublicAdapterArtifact {
		if (plan == null || plan.plugin.profileId != "wp70-release") {
			throw "Wp70PublicAdapterProfile requires an exact wp70-release adapter plan";
		}
		final base = bootstrap.emitPlugin(plan.plugin);
		final methods = plan.methods;
		methods.push(registrationMethod("registerRestRoutes", restRegistrationBody(plan), plan));
		methods.push(registrationMethod("registerBlocks", blockRegistrationBody(plan), plan));
		final adapterClass = new PhpClass(PhpClassKindClass, plan.className, plan.source, null, [], plan.properties, methods, plan.semanticNodeId);
		final adapterFile = new PhpFile(plan.adapterPath, plan.plugin.namespace, true, [PhpClassDeclaration(adapterClass)]);
		final registrationFile = new PhpFile(plan.registrationPath, null, true, [], registrationStatements(plan));
		final autoloadFile = new PhpFile(plan.plugin.autoloadPath, null, true, [], [
			includeRelative("/Bootstrap.php"),
			includeRelative("/" + plan.className.value + ".php"),
			includeRelative("/register-adapters.php")
		]);

		return new WordPressPublicAdapterArtifact(plan, [
			new WordPressPublicAdapterFile("plugin-root", base.file(plan.plugin.rootPath).rendered),
			new WordPressPublicAdapterFile("bootstrap", base.file(plan.plugin.bootstrapPath).rendered),
			new WordPressPublicAdapterFile("autoload", printer.print(autoloadFile)),
			new WordPressPublicAdapterFile("adapter-class", printer.print(adapterFile)),
			new WordPressPublicAdapterFile("registrations", printer.print(registrationFile))
		]);
	}

	static function includeRelative(path:String):PhpStmt {
		return PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString(path)));
	}

	static function registrationMethod(name:String, body:Array<PhpStmt>, plan:WordPressPublicAdapterPlan):PhpMethod {
		final semanticNodeId = plan.semanticNodeId == null ? null : plan.semanticNodeId + ":synthesized:" + name.toLowerCase();
		return new PhpMethod(PhpPublic, true, false, id(name), [], plan.source, PhpVoidType, body, semanticNodeId);
	}

	static function restRegistrationBody(plan:WordPressPublicAdapterPlan):Array<PhpStmt> {
		final body:Array<PhpStmt> = [];
		for (route in plan.restRoutes) {
			body.push(PhpExprStmt(PhpFunctionCall("\\register_rest_route", [
				PhpString(route.namespace),
				PhpString(route.route),
				PhpLongArray([
					entry("methods", PhpClassConst("\\WP_REST_Server", WordPressRestMethodTools.constantName(route.method))),
					entry("callback", selfCallable(route.callback)),
					entry("permission_callback", selfCallable(route.permissionCallback))
				])
			])));
		}
		return body;
	}

	static function blockRegistrationBody(plan:WordPressPublicAdapterPlan):Array<PhpStmt> {
		final body:Array<PhpStmt> = [];
		for (block in plan.blocks) {
			body.push(PhpExprStmt(PhpFunctionCall("\\register_block_type", [
				PhpString(block.blockName),
				PhpLongArray([entry("render_callback", selfCallable(block.renderCallback))])
			])));
		}
		return body;
	}

	static function registrationStatements(plan:WordPressPublicAdapterPlan):Array<PhpStmt> {
		final statements:Array<PhpStmt> = [];
		for (hook in plan.hooks) {
			final registration = hook.kind == Action ? "\\add_action" : "\\add_filter";
			statements.push(PhpExprStmt(PhpFunctionCall(registration, [
				PhpString(hook.hookName),
				classCallable(plan.absoluteAdapterClass, hook.callback),
				PhpInt(hook.priority),
				PhpInt(hook.acceptedArgs)
			])));
		}
		if (plan.restRoutes.length > 0) {
			statements.push(PhpExprStmt(PhpFunctionCall("\\add_action", [
				PhpString("rest_api_init"),
				classCallable(plan.absoluteAdapterClass, id("registerRestRoutes")),
				PhpInt(10),
				PhpInt(0)
			])));
		}
		if (plan.blocks.length > 0) {
			statements.push(PhpExprStmt(PhpFunctionCall("\\add_action", [
				PhpString("init"),
				classCallable(plan.absoluteAdapterClass, id("registerBlocks")),
				PhpInt(10),
				PhpInt(0)
			])));
		}
		return statements;
	}

	static function selfCallable(method:PhpIdentifier):PhpExpr {
		return PhpCallableArray(PhpClassConst("self", "class"), method);
	}

	static function classCallable(className:String, method:PhpIdentifier):PhpExpr {
		return PhpCallableArray(PhpClassConst(className, "class"), method);
	}

	static function entry(key:String, value:PhpExpr):PhpArrayEntry {
		return {key: PhpString(key), value: value};
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}
}
