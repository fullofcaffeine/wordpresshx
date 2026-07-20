package wordpress.hx.gutenberg.editor;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Stable local name shared by a native PluginSidebar and its menu item. */
@:ts.type("string")
abstract SidebarName(String) {
	private static final VALID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;

	private inline function new(value:String) {
		this = value;
	}

	/** Validates a value discovered at runtime before it reaches WordPress. */
	public static function parse(value:String):SidebarName {
		if (!VALID.match(value)) {
			throw 'invalid editor sidebar name: ${value}';
		}
		return new SidebarName(value);
	}

	/** Produces a branded name and rejects malformed literals during compilation. */
	public static macro function literal(value:ExprOf<String>):ExprOf<SidebarName> {
		final literal = switch value.expr {
			case EConst(CString(candidate, _)): candidate;
			case _: Context.error("WPX6302: editor sidebar name must be a string literal; use SidebarName.parse for runtime input.", value.pos);
		};
		if (!VALID.match(literal)) {
			Context.error('WPX6303: invalid editor sidebar name ${literal}.', value.pos);
		}
		return macro @:pos(value.pos) wordpress.hx.gutenberg.editor.SidebarName.parse($v{literal});
	}

	public inline function toString():String {
		return this;
	}
}
