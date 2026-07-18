package wordpress.hx.build.semantic;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.SemanticCollector;
#end

/** Typed WordPress module declarations collected into the immutable plan. */
class Module {
	public static macro function plugin(options:ExprOf<ModuleOptions>):ExprOf<ModuleDeclaration> {
		return SemanticCollector.collectModule("plugin", options);
	}

	public static macro function mustUsePlugin(options:ExprOf<ModuleOptions>):ExprOf<ModuleDeclaration> {
		return SemanticCollector.collectModule("mu-plugin", options);
	}

	public static macro function theme(options:ExprOf<ModuleOptions>):ExprOf<ModuleDeclaration> {
		return SemanticCollector.collectModule("theme", options);
	}

	public static macro function block(options:ExprOf<ModuleOptions>):ExprOf<ModuleDeclaration> {
		return SemanticCollector.collectModule("block", options);
	}
}
