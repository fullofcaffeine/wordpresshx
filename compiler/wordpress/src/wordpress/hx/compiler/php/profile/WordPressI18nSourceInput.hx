package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;

/** Immutable authored input linked to generated translation artifacts. */
class WordPressI18nSourceInput {
	public final path:String;
	public final sha256:String;
	public final byteLength:Int;

	final contentValue:Bytes;

	public var content(get, never):Bytes;

	public function new(path:String, content:Bytes) {
		if (content == null) {
			throw "i18n source input requires bytes";
		}
		this.path = relativePath(path);
		this.contentValue = content.sub(0, content.length);
		this.sha256 = Sha256.make(contentValue).toHex();
		this.byteLength = contentValue.length;
	}

	function get_content():Bytes {
		return contentValue.sub(0, contentValue.length);
	}

	static function relativePath(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw "i18n source input requires a relative path";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1) {
			throw "i18n source input path must be relative: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "i18n source input path has an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
