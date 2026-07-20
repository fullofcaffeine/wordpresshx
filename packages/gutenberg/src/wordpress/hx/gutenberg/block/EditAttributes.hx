package wordpress.hx.gutenberg.block;

#if macro
import haxe.macro.Expr;
#end

/** Typed, single-field updates for native Gutenberg edit props. */
class EditAttributes {
	/**
	 * Updates the field selected by a direct expression such as
	 * `attributes -> attributes.message`.
	 */
	public static macro function set(props:Expr, selector:Expr, value:Expr):Expr {
		return wordpress.hx.gutenberg.block._internal.EditAttributesBuilder.build(props, selector, value);
	}
}
