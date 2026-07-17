package reflaxe.php.print;

import reflaxe.php.ir.PhpSourceRange;

/** One declaration's stable identity and exact generated line range. **/
class PhpRenderedDeclaration {
	public final stableName:String;
	public final source:PhpSourceRange;
	public final generatedStartLine:Int;
	public final generatedEndLine:Int;

	public function new(stableName:String, source:PhpSourceRange, generatedStartLine:Int, generatedEndLine:Int) {
		if (stableName == null || stableName.length == 0 || source == null || generatedStartLine <= 0 || generatedEndLine < generatedStartLine) {
			throw "Rendered PHP declaration range is invalid";
		}
		this.stableName = stableName;
		this.source = source;
		this.generatedStartLine = generatedStartLine;
		this.generatedEndLine = generatedEndLine;
	}
}
