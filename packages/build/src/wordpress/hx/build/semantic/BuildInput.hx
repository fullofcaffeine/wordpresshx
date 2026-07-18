package wordpress.hx.build.semantic;

#if macro
import haxe.macro.Expr;
import wordpress.hx.build._internal.SemanticCollector;
#end

/** Explicit, content-bound non-Haxe inputs consumed by plan collection. */
class BuildInput {
	public static macro function resource(options:ExprOf<ResourceOptions>):ExprOf<BuildInputDeclaration> {
		return SemanticCollector.collectResource(options);
	}

	public static macro function publicEnvironment(options:ExprOf<PublicEnvironmentOptions>):ExprOf<BuildInputDeclaration> {
		return SemanticCollector.collectEnvironment(options);
	}
}
