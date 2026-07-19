package wordpress.hx.build.semantic;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.SemanticCollector;
#end

/** Typed, compile-time-only local development services. */
class Dev {
	public static macro function wordpress(?options:ExprOf<WordPressDevelopmentOptions>):ExprOf<DevelopmentServiceDeclaration> {
		return SemanticCollector.collectWordPressService(options);
	}

	/** Explicit process escape hatch for services without a dedicated adapter. */
	public static macro function service(options:ExprOf<DevelopmentServiceOptions>):ExprOf<DevelopmentServiceDeclaration> {
		return SemanticCollector.collectExternalService(options);
	}
}
