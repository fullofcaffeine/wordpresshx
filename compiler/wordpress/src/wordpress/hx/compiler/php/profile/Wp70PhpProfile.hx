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

/** Minimal native public PHP emitter for the exact wp70-release profile. **/
class Wp70PhpProfile {
	final printer:WordPressPhpPrinter;

	public function new() {
		printer = new WordPressPhpPrinter();
	}

	public function emitPlugin(plan:PluginBootstrapPlan):WordPressPluginArtifact {
		if (plan == null || plan.profileId != "wp70-release") {
			throw "Wp70PhpProfile requires an exact wp70-release bootstrap plan";
		}

		final root = new PhpFile(plan.rootPath, null, false, [], [
			PhpIf(PhpNot(PhpFunctionCall("defined", [PhpString("ABSPATH")])), [PhpReturnVoid]),
			PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/" + plan.autoloadPath))),
			PhpExprStmt(PhpStaticCall(plan.absoluteBootstrapClass, "boot", []))
		]);
		final autoload = new PhpFile(plan.autoloadPath, null, true, [], [
			PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/Bootstrap.php")))
		]);

		final bootstrap = new PhpClass(PhpClassKindClass, id("Bootstrap"), plan.source, null, [],
			[new PhpProperty(PhpPrivate, true, id("booted"), PhpBool(false), PhpBoolType)], [
				new PhpMethod(PhpPublic, true, false, id("boot"), [], plan.source, PhpVoidType, [
					PhpIf(PhpStaticProperty("self", "booted"), [PhpReturnVoid]),
					PhpAssign(PhpStaticProperty("self", "booted"), PhpBool(true))
				]),
				new PhpMethod(PhpPublic, true, false, id("isBooted"), [], plan.source, PhpBoolType, [PhpReturn(PhpStaticProperty("self", "booted"))])
			]);
		final bootstrapFile = new PhpFile(plan.bootstrapPath, plan.namespace, true, [PhpClassDeclaration(bootstrap)]);

		return new WordPressPluginArtifact(plan, [
			new WordPressPluginFile("plugin-root", printer.printPluginRoot(plan.header, root)),
			new WordPressPluginFile("autoload", printer.print(autoload)),
			new WordPressPluginFile("bootstrap", printer.print(bootstrapFile))
		]);
	}

	static function id(value:String):PhpIdentifier {
		return PhpIdentifier.named(value);
	}
}
