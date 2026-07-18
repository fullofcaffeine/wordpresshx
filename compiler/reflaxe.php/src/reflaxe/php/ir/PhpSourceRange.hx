package reflaxe.php.ir;

/**
 * Source range with a legacy one-based view and optional authenticated bytes.
 *
 * `at` preserves the original declaration-range contract. `exact` adds the
 * authoritative half-open UTF-8 byte coordinates required by range maps.
**/
class PhpSourceRange {
	public final file:String;
	public final startLine:Int;
	public final startColumn:Int;
	public final endLine:Int;
	public final endColumn:Int;
	public final sourceFile:Null<PhpSourceFile>;
	public final startByte:Null<Int>;
	public final endByte:Null<Int>;
	public final startColumnUtf8:Null<Int>;
	public final endColumnUtf8:Null<Int>;
	public final isExact:Bool;

	private function new(file:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int, sourceFile:Null<PhpSourceFile>, startByte:Null<Int>,
			endByte:Null<Int>, startColumnUtf8:Null<Int>, endColumnUtf8:Null<Int>) {
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
		this.sourceFile = sourceFile;
		this.startByte = startByte;
		this.endByte = endByte;
		this.startColumnUtf8 = startColumnUtf8;
		this.endColumnUtf8 = endColumnUtf8;
		this.isExact = sourceFile != null;
	}

	public static function at(file:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int):PhpSourceRange {
		return new PhpSourceRange(file, startLine, startColumn, endLine, endColumn, null, null, null, null, null);
	}

	public static function exact(sourceFile:PhpSourceFile, startByte:Int, endByte:Int):PhpSourceRange {
		if (sourceFile == null || startByte < 0 || endByte <= startByte || endByte > sourceFile.byteLength) {
			throw "Exact PHP source range must be non-empty and in bounds";
		}
		final start = sourceFile.positionAt(startByte);
		final end = sourceFile.positionAt(endByte);
		return new PhpSourceRange(sourceFile.path, start.line, start.columnUtf8 + 1, end.line, end.columnUtf8 + 1, sourceFile, startByte, endByte,
			start.columnUtf8, end.columnUtf8);
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
