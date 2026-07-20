package wordpress.hx.gutenberg.editor;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** WordPress post-type slug used at the editor visibility boundary. */
@:ts.type("string")
abstract PostTypeName(String) {
	private static final VALID = ~/^[a-z][a-z0-9_]{0,19}$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):PostTypeName {
		if (!VALID.match(value)) {
			throw 'invalid post type name: ${value}';
		}
		return new PostTypeName(value);
	}

	public static macro function literal(value:ExprOf<String>):ExprOf<PostTypeName> {
		final literal = switch value.expr {
			case EConst(CString(candidate, _)): candidate;
			case _: Context.error("WPX6304: post type name must be a string literal; use PostTypeName.parse for runtime input.", value.pos);
		};
		if (!VALID.match(literal)) {
			Context.error('WPX6305: invalid post type name ${literal}.', value.pos);
		}
		return macro @:pos(value.pos) wordpress.hx.gutenberg.editor.PostTypeName.parse($v{literal});
	}

	public inline function toString():String {
		return this;
	}
}
