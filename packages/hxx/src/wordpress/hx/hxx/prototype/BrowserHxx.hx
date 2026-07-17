package wordpress.hx.hxx.prototype;

#if macro
import haxe.macro.Expr;
import wordpress.hx.hxx._internal.HxxParserAdapter;
#end

/** Compile-time-only browser entry point used by the SDK-080 evidence corpus. */
class BrowserHxx {
	public static macro function render(markup:Expr):Expr {
		return HxxParserAdapter.lowerBrowser(markup);
	}
}
