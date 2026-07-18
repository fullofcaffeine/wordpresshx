package wordpress.hx.gutenberg.react;

/** Minimal DOM target used by typed React events and refs. */
@:ts.type("HTMLButtonElement")
extern class HtmlButtonElement {
	public function focus():Void;
	public function setAttribute(name:String, value:String):Void;
}
