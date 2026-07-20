package wordpress.hx.gutenberg.block;

#if macro
import haxe.macro.Expr;
#end

/** Compile-time entry point for static Gutenberg browser behavior. */
class StaticBlock {
	/**
	 * Registers one static block after checking its attribute, edit, save, and
	 * ordered deprecation contracts.
	 */
	public static macro function register(attributeShape:Expr, options:Expr):Expr {
		return wordpress.hx.gutenberg.block._internal.StaticBlockBuilder.register(attributeShape, options);
	}

	/** Marker accepted only inside the literal `deprecations` array. */
	public static macro function deprecated(attributeShape:Expr, options:Expr):Expr {
		return macro @:pos(options.pos) null;

	}
}
