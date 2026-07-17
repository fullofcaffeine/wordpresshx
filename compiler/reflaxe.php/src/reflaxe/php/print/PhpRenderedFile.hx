package reflaxe.php.print;

/** Deterministic PHP bytes plus declaration-level source correlation. **/
class PhpRenderedFile {
	public final path:String;
	public final source:String;

	final declarations:Array<PhpRenderedDeclaration>;

	public var declarationCount(get, never):Int;

	public function new(path:String, source:String, declarations:Array<PhpRenderedDeclaration>) {
		if (path == null || source == null || declarations == null) {
			throw "Rendered PHP file fields cannot be null";
		}
		this.path = path;
		this.source = source;
		this.declarations = declarations.copy();
	}

	function get_declarationCount():Int {
		return declarations.length;
	}

	public function declarationAt(index:Int):PhpRenderedDeclaration {
		if (index < 0 || index >= declarations.length) {
			throw "Rendered PHP declaration index out of bounds: " + index;
		}
		return declarations[index];
	}

	public function iterator():Iterator<PhpRenderedDeclaration> {
		return declarations.iterator();
	}
}
