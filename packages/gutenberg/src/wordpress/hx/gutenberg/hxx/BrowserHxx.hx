package wordpress.hx.gutenberg.hxx;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import wordpress.hx.gutenberg.hxx._internal.BrowserHxxLowerer;
#end

/** Compile-time browser HXX entry installed by the Gutenberg build profile. */
class BrowserHxx {
	public static macro function lower(markup:Expr):Expr {
		return BrowserHxxLowerer.lower(markup);
	}

	#if macro
	public static function enable():Void {
		if (!Context.defined("wordpress_hx_browser_hxx")) {
			return;
		}
		Compiler.addGlobalMetadata("", "@:build(wordpress.hx.gutenberg.hxx.BrowserHxx.build())", true, true, false);
	}

	public static macro function build():Array<Field> {
		final fields = Context.getBuildFields();
		if (!Context.defined("wordpress_hx_browser_hxx")) {
			return fields;
		}
		for (field in fields) {
			rewriteField(field);
		}
		return fields;
	}

	private static function rewriteField(field:Field):Void {
		switch field.kind {
			case FFun(fn) if (fn.expr != null):
				fn.expr = rewriteExpression(fn.expr);
			case FVar(type, value) if (value != null):
				field.kind = FVar(type, rewriteExpression(value));
			case FProp(getter, setter, type, value) if (value != null):
				field.kind = FProp(getter, setter, type, rewriteExpression(value));
			default:
		}
	}

	private static function rewriteExpression(expression:Expr):Expr {
		return switch expression.expr {
			case EMeta(metadata, _) if (metadata.name == ":markup" || metadata.name == "markup"):
				final call = macro wordpress.hx.gutenberg.hxx.BrowserHxx.lower($expression);
				call.pos = expression.pos;
				call;
			default:
				ExprTools.map(expression, rewriteExpression);
		};
	}
	#end
}
