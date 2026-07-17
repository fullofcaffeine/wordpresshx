package wordpress.hx.hxx.prototype;

#if macro
import haxe.macro.Expr;
import wordpress.hx.hxx._internal.HxxParserAdapter;
#end

/** Compile-time-only server entry point used by the SDK-080 evidence corpus. */
class ServerHxx {
	public static macro function render(markup:Expr):Expr {
		return HxxParserAdapter.lowerServer(markup);
	}
}
