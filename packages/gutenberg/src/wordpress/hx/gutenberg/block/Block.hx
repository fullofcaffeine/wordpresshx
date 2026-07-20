package wordpress.hx.gutenberg.block;

#if macro
import haxe.macro.Expr;
import wordpress.hx.gutenberg.block._internal.BlockBuilder;
#end

/**
 * Compile-time entry point for native Gutenberg block metadata.
 *
 * The first argument to `define` is the Haxe class that owns the attribute
 * shape. The compiler derives its `block.json` attributes and validates every
 * default before any native artifact is published.
 */
class Block {
	/** Installs the exact-profile block collector for the current compilation. */
	public static macro function install():Expr {
		return BlockBuilder.install();
	}

	/** Declares one static or dynamic block from a closed Haxe object literal. */
	public static macro function define(attributeShape:Expr, options:Expr):Expr {
		return BlockBuilder.define(attributeShape, options);
	}
}
