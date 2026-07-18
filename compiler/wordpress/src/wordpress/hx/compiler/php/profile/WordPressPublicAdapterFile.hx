package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import reflaxe.php.print.PhpRenderedFile;

/** One native PHP file in the closed SDK-023 adapter artifact. **/
class WordPressPublicAdapterFile {
	public final role:String;
	public final classification:String;
	public final rendered:PhpRenderedFile;
	public final sha256:String;
	public final byteLength:Int;

	public var path(get, never):String;
	public var source(get, never):String;

	public function new(role:String, rendered:PhpRenderedFile) {
		if (rendered == null) {
			throw "WordPress public adapter file requires rendered PHP";
		}
		switch (role) {
			case "plugin-root", "autoload", "bootstrap", "adapter-class", "registrations":
			case _:
				throw "Unknown WordPress public adapter file role: " + role;
		}
		this.role = role;
		this.classification = "public-native";
		this.rendered = rendered;
		final bytes = Bytes.ofString(rendered.source);
		this.sha256 = Sha256.make(bytes).toHex();
		this.byteLength = bytes.length;
	}

	function get_path():String {
		return rendered.path;
	}

	function get_source():String {
		return rendered.source;
	}
}
