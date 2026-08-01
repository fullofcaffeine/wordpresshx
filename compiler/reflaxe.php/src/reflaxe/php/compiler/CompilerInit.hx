package reflaxe.php.compiler;

#if macro
import haxe.macro.Compiler as MacroCompiler;
import haxe.macro.Context;
import reflaxe.BaseCompiler.BaseCompilerFileOutputType;
import reflaxe.ReflectCompiler;
#end

/** Registers the generic PHP compiler only for an explicit reflaxe_php build. **/
class CompilerInit {
	#if macro
	static var initialized:Bool = false;

	public static function Start():Void {
		if (!Context.defined("reflaxe_php_output") || initialized) {
			return;
		}
		initialized = true;
		MacroCompiler.define("reflaxe_php");
		final config = new PhpCompilerConfig();
		Context.onAfterTyping(PhpTypedAstValidator.validateModules);
		ReflectCompiler.AddCompiler(new PhpCompiler(config), {
			outputDirDefineName: "reflaxe_php_output",
			fileOutputType: Manual,
			fileOutputExtension: ".php",
			targetCodeInjectionName: "__reflaxe_php__",
			expressionPreprocessors: [],
			ignoreBodilessFunctions: false,
			ignoreExterns: true,
			trackUsedTypes: true
		});
	}
	#else
	public static function Start():Void {}
	#end
}
