package wordpress.hx.i18n;

/** Authored source position captured by a message declaration macro. */
class MessageSource {
	public final file:String;
	public final line:Int;

	public function new(file:String, line:Int) {
		if (file == null || file.length == 0 || line <= 0 || file.indexOf("\x00") != -1) {
			throw "message source requires a relative file and one-based line";
		}
		final normalized = file.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1) {
			throw "message source file must be relative: " + file;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "message source file has an unsafe segment: " + file;
			}
		}
		this.file = normalized;
		this.line = line;
	}
}
