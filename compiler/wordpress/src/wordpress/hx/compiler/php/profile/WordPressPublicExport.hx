package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;

/** A stable native PHP method intentionally callable outside WordPress/Haxe. **/
class WordPressPublicExport {
	public final method:PhpIdentifier;

	public function new(method:PhpIdentifier) {
		if (method == null) {
			throw "WordPress public export requires a method";
		}
		this.method = method;
	}
}
