package wordpress.hx.gutenberg.data;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** Stable namespace used by WordPress' native data registry. */
@:ts.type("string")
abstract StoreKey(String) {
	private static final VALID = ~/^[a-z][a-z0-9-]*(?:\/[a-z][a-z0-9-]*)+$/;

	private inline function new(value:String) {
		this = value;
	}

	/** Validates a key discovered at runtime before it reaches WordPress. */
	public static function parse(value:String):StoreKey {
		if (!VALID.match(value)) {
			throw 'invalid WordPress data-store key: ${value}';
		}
		return new StoreKey(value);
	}

	/** Produces a branded key and rejects malformed literals during compilation. */
	public static macro function literal(value:ExprOf<String>):ExprOf<StoreKey> {
		final literal = switch value.expr {
			case EConst(CString(candidate, _)): candidate;
			case _: Context.error("WPX6400: data-store key must be a string literal; use StoreKey.parse for runtime input.", value.pos);
		};
		if (!VALID.match(literal)) {
			Context.error('WPX6401: invalid WordPress data-store key ${literal}.', value.pos);
		}
		return macro @:pos(value.pos) wordpress.hx.gutenberg.data.StoreKey.parse($v{literal});
	}

	public inline function toString():String {
		return this;
	}
}
