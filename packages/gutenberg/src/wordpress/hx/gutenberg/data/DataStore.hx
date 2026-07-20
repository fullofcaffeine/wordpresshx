package wordpress.hx.gutenberg.data;

#if macro
import haxe.macro.Expr;
#end

/** Compile-time entry point for defining a native WordPress data store. */
class DataStore {
	/**
	 * Defines a store after validating its key, closed action identity, and
	 * reducer state contract at the original Haxe source position.
	 */
	public static macro function define(key:ExprOf<StoreKey>, initialState:Expr, reducer:Expr):Expr {
		return wordpress.hx.gutenberg.data._internal.DataStoreBuilder.build(key, initialState, reducer);
	}
}
