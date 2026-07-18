package reflaxe.php.ir;

/** One-based line and zero-based UTF-8 byte column for an exact file offset. **/
class PhpSourcePosition {
	public final line:Int;
	public final columnUtf8:Int;

	public function new(line:Int, columnUtf8:Int) {
		if (line <= 0 || columnUtf8 < 0) {
			throw "PHP source position is invalid";
		}
		this.line = line;
		this.columnUtf8 = columnUtf8;
	}
}
