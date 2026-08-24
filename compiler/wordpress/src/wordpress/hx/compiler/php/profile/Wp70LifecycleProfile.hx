package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;

/** Native standard-plugin and mu-plugin lifecycle emitter for wp70-release. */
class Wp70LifecycleProfile {
	final printer:WordPressPhpPrinter;

	public function new() {
		printer = new WordPressPhpPrinter();
	}

	public function emitPlugin(plan:WordPressPluginLifecyclePlan):WordPressLifecycleArtifact {
		if (plan == null || plan.plugin.profileId != "wp70-release") {
			throw "Wp70LifecycleProfile requires an exact wp70-release lifecycle plan";
		}
		final root = new PhpFile(plan.rootPath, null, false, [], rootStatements(plan));
		final autoload = new PhpFile(plan.autoloadPath, null, true, [], [includeRelative("/Bootstrap.php"), includeRelative("/Lifecycle.php")]);
		final bootstrap = new PhpClass(PhpClassKindClass, id("Bootstrap"), plan.plugin.source, null, [],
			[new PhpProperty(PhpPrivate, true, id("booted"), PhpBool(false), PhpBoolType)], [
				new PhpMethod(PhpPublic, true, false, id("boot"), [], plan.plugin.source, PhpVoidType, [
					PhpIf(PhpStaticProperty("self", "booted"), [PhpReturnVoid]),
					PhpAssign(PhpStaticProperty("self", "booted"), PhpBool(true))
				]),
				new PhpMethod(PhpPublic, true, false, id("isBooted"), [], plan.plugin.source, PhpBoolType, [PhpReturn(PhpStaticProperty("self", "booted"))])
			]);
		final lifecycle = new PhpClass(PhpClassKindClass, id("Lifecycle"), plan.plugin.source, null, [], [], lifecycleMethods(plan));
		final files = [
			new WordPressLifecycleFile("plugin-root", printer.printPluginRoot(plan.plugin.header, root)),
			new WordPressLifecycleFile("autoload", printer.print(autoload)),
			new WordPressLifecycleFile("bootstrap",
				printer.print(new PhpFile(plan.bootstrapPath, plan.plugin.namespace, true, [PhpClassDeclaration(bootstrap)]))),
			new WordPressLifecycleFile("lifecycle",
				printer.print(new PhpFile(plan.lifecyclePath, plan.plugin.namespace, true, [PhpClassDeclaration(lifecycle)])))
		];
		if (plan.uninstallPath != null) {
			files.push(new WordPressLifecycleFile("uninstall", printer.print(new PhpFile(plan.uninstallPath, null, true, [], [
				PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString("WP_UNINSTALL_PLUGIN")])), [PhpReturnVoid]),
				PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/includes/autoload.php"))),
				PhpExprStmt(PhpStaticCall(plan.absoluteLifecycleClass, "uninstall", []))
			]))));
		}
		return new WordPressLifecycleArtifact(plan, files);
	}

	static function rootStatements(plan:WordPressPluginLifecyclePlan):Array<PhpStmt> {
		final autoloadSuffix = plan.installKind == StandardPlugin ? "/includes/autoload.php" : "/" + plan.plugin.slug + "/includes/autoload.php";
		final statements:Array<PhpStmt> = [
			PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString("ABSPATH")])), [PhpReturnVoid]),
			PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString(autoloadSuffix)))
		];
		if (plan.installKind == StandardPlugin) {
			statements.push(PhpExprStmt(PhpFunctionCall("\\register_activation_hook", [
				PhpMagicConst("__FILE__"),
				classCallable(plan.absoluteLifecycleClass, "activate")
			])));
			statements.push(PhpExprStmt(PhpFunctionCall("\\register_deactivation_hook", [
				PhpMagicConst("__FILE__"),
				classCallable(plan.absoluteLifecycleClass, "deactivate")
			])));
		}
		statements.push(PhpExprStmt(PhpFunctionCall("\\add_action", [
			PhpString("plugins_loaded"),
			classCallable(plan.absoluteLifecycleClass, "maybeUpgrade"),
			PhpInt(10),
			PhpInt(0)
		])));
		statements.push(PhpExprStmt(PhpStaticCall(plan.plugin.absoluteBootstrapClass, "boot", [])));
		return statements;
	}

	static function lifecycleMethods(plan:WordPressPluginLifecyclePlan):Array<PhpMethod> {
		final upgradeBody:Array<PhpStmt> = [
			PhpLocal("schemaVersion", PhpCastInt(PhpFunctionCall("\\get_option", [PhpString(plan.schemaOption), PhpInt(0)]))),
			PhpIf(PhpBinop(">", PhpVar("schemaVersion"), PhpInt(plan.targetSchemaVersion)), [
				PhpThrow(PhpNew("\\RuntimeException", [PhpString("Stored plugin schema is newer than this package supports")]))
			])
		];
		for (step in plan.upgradeSteps) {
			final body = step.statements;
			body.push(PhpExprStmt(PhpFunctionCall("\\update_option", [PhpString(plan.schemaOption), PhpInt(step.toVersion), PhpBool(false)])));
			body.push(PhpAssign(PhpVar("schemaVersion"), PhpInt(step.toVersion)));
			upgradeBody.push(PhpIf(PhpBinop("<", PhpVar("schemaVersion"), PhpInt(step.toVersion)), body));
		}
		final uninstallBody:Array<PhpStmt> = [];
		switch (plan.uninstallPolicy) {
			case RetainPluginData:
			case DeleteDeclaredPluginData:
				for (option in plan.uninstallOptions) {
					uninstallBody.push(PhpExprStmt(PhpFunctionCall("\\delete_option", [PhpString(option)])));
				}
		}
		return [
			new PhpMethod(PhpPublic, true, false, id("activate"), [], plan.plugin.source, PhpVoidType,
				[PhpExprStmt(PhpStaticCall("self", "maybeUpgrade", []))]),
			new PhpMethod(PhpPublic, true, false, id("deactivate"), [], plan.plugin.source, PhpVoidType, []),
			new PhpMethod(PhpPublic, true, false, id("maybeUpgrade"), [], plan.plugin.source, PhpVoidType, upgradeBody),
			new PhpMethod(PhpPublic, true, false, id("uninstall"), [], plan.plugin.source, PhpVoidType, uninstallBody)
		];
	}

	static function includeRelative(path:String):PhpStmt {
		return PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString(path)));
	}

	static function classCallable(className:String, method:String):PhpExpr {
		return PhpCallableArray(PhpClassConst(className, "class"), id(method));
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}
}
