package wordpress.hx.gutenberg.html;

/** Native HTML button kinds, preserved as a TypeScript literal union. */
@:ts.type("'button' | 'submit' | 'reset'")
enum abstract HtmlButtonType(String) to String {
	var Button = "button";
	var Submit = "submit";
	var Reset = "reset";
}
