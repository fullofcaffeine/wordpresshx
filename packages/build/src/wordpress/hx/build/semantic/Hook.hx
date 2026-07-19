package wordpress.hx.build.semantic;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.SemanticCollector;
#end

/** Typed WordPress action and filter declarations. */
class Hook {
	public static macro function action<Callback>(options:ExprOf<HookOptions<Callback>>):ExprOf<HookDeclaration> {
		return SemanticCollector.collectHook("action", options);
	}

	public static macro function filter<Callback>(options:ExprOf<HookOptions<Callback>>):ExprOf<HookDeclaration> {
		return SemanticCollector.collectHook("filter", options);
	}
}
