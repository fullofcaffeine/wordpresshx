package wordpress.hx.build;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.SemanticCollector;
#end

/**
 * Installs the compile-time semantic-plan collector.
 *
 * Project tooling writes this call into its generated HXML. Application code
 * declares typed facts through `semantic.Module`, `semantic.Hook`, and
 * `semantic.BuildInput`; it never calls this bootstrap directly.
 */
class SemanticPlan {
	public static macro function install(configPath:String, planOutputPath:String, inputsOutputPath:String):Expr {
		return SemanticCollector.install(configPath, planOutputPath, inputsOutputPath);
	}
}
