package wordpress.hx.gutenberg.editor;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Stable public name passed to WordPress' native plugin registry. */
@:ts.type("string")
abstract PluginName(String) {
	private static final VALID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$/;

	private inline function new(value:String) {
		this = value;
	}

	/** Validates a value discovered at runtime before it reaches WordPress. */
	public static function parse(value:String):PluginName {
		if (!VALID.match(value)) {
			throw 'invalid editor plugin name: ${value}';
		}
		return new PluginName(value);
	}

	/** Produces a branded name and rejects malformed literals during compilation. */
	public static macro function literal(value:ExprOf<String>):ExprOf<PluginName> {
		final literal = switch value.expr {
			case EConst(CString(candidate, _)): candidate;
			case _: Context.error("WPX6300: editor plugin name must be a string literal; use PluginName.parse for runtime input.", value.pos);
		};
		if (!VALID.match(literal)) {
			Context.error('WPX6301: invalid editor plugin name ${literal}.', value.pos);
		}
		return macro @:pos(value.pos) wordpress.hx.gutenberg.editor.PluginName.parse($v{literal});
	}

	public inline function toString():String {
		return this;
	}
}
