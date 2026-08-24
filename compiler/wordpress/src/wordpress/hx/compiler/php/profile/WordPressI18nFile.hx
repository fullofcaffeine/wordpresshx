package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;

/** One role-bound generated SDK-055 file. */
class WordPressI18nFile {
	public final path:String;
	public final role:String;
	public final classification:String;
	public final sha256:String;
	public final byteLength:Int;

	final contentValue:Bytes;

	public var content(get, never):Bytes;

	public function new(path:String, role:String, content:Bytes) {
		if (content == null || content.length == 0) {
			throw "SDK-055 artifact file requires bytes";
		}
		switch (role) {
			case "plugin-root", "server-messages", "browser-bundle", "asset-metadata", "pot", "mo", "jed", "extraction-surrogate":
			case _:
				throw "unknown SDK-055 artifact role: " + role;
		}
		this.path = relativePath(path);
		this.role = role;
		this.classification = "public-native";
		this.contentValue = content.sub(0, content.length);
		this.sha256 = Sha256.make(contentValue).toHex();
		this.byteLength = contentValue.length;
	}

	public function text():String {
		if (role == "mo") {
			throw "binary MO files do not have a text view";
		}
		return contentValue.toString();
	}

	function get_content():Bytes {
		return contentValue.sub(0, contentValue.length);
	}

	static function relativePath(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw "SDK-055 artifact requires a relative path";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1) {
			throw "SDK-055 artifact path must be relative: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "SDK-055 artifact path has an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
