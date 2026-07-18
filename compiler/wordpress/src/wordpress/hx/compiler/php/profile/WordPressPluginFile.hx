package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import reflaxe.php.print.PhpRenderedFile;

/** One classified generated file in the closed SDK-022 plugin artifact. **/
class WordPressPluginFile {
	public final role:String;
	public final classification:String;
	public final rendered:PhpRenderedFile;
	public final sha256:String;
	public final byteLength:Int;

	public var path(get, never):String;
	public var source(get, never):String;

	public function new(role:String, rendered:PhpRenderedFile) {
		if (rendered == null) {
			throw "WordPress plugin file requires rendered PHP";
		}
		switch (role) {
			case "plugin-root", "autoload", "bootstrap":
			case _:
				throw "Unknown WordPress plugin file role: " + role;
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
