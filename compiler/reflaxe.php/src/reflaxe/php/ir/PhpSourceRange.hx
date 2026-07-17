package reflaxe.php.ir;

/** Immutable one-based Haxe source range with repository-relative file identity. **/
class PhpSourceRange {
	public final file:String;
	public final startLine:Int;
	public final startColumn:Int;
	public final endLine:Int;
	public final endColumn:Int;

	private function new(file:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int) {
		this.file = validateFile(file);
		if (startLine <= 0
			|| startColumn <= 0
			|| endLine <= 0
			|| endColumn <= 0
			|| endLine < startLine
			|| (endLine == startLine && endColumn < startColumn)) {
			throw "PHP source range must be one-based and forward";
		}
		this.startLine = startLine;
		this.startColumn = startColumn;
		this.endLine = endLine;
		this.endColumn = endColumn;
	}

	public static function at(file:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int):PhpSourceRange {
		return new PhpSourceRange(file, startLine, startColumn, endLine, endColumn);
	}

	static function validateFile(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw "PHP source range requires a relative file";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1 || ~/^[A-Za-z]:\//.match(normalized)) {
			throw "PHP source range file must be relative: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "PHP source range file contains an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
