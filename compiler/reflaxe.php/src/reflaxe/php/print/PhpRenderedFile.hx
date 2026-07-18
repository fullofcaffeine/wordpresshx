package reflaxe.php.print;

/** Deterministic PHP bytes plus declaration and exact byte-level correlation. **/
class PhpRenderedFile {
	public final path:String;
	public final source:String;

	final declarations:Array<PhpRenderedDeclaration>;
	final mappings:Array<PhpRenderedMapping>;

	public var declarationCount(get, never):Int;
	public var mappingCount(get, never):Int;

	public function new(path:String, source:String, declarations:Array<PhpRenderedDeclaration>, ?mappings:Array<PhpRenderedMapping>) {
		if (path == null || source == null || declarations == null) {
			throw "Rendered PHP file fields cannot be null";
		}
		this.path = validatePath(path);
		this.source = source;
		this.declarations = declarations.copy();
		this.mappings = mappings == null ? [] : mappings.copy();
	}

	function get_declarationCount():Int {
		return declarations.length;
	}

	function get_mappingCount():Int {
		return mappings.length;
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

	public function mappingAt(index:Int):PhpRenderedMapping {
		if (index < 0 || index >= mappings.length) {
			throw "Rendered PHP mapping index out of bounds: " + index;
		}
		return mappings[index];
	}

	public function mappingIterator():Iterator<PhpRenderedMapping> {
		return mappings.iterator();
	}

	static function validatePath(value:String):String {
		if (value.length == 0 || value.indexOf("\x00") != -1) {
			throw "Rendered PHP file requires a relative .php path";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") != -1 || !StringTools.endsWith(normalized, ".php")) {
			throw "Rendered PHP file requires a relative .php path: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "Rendered PHP file path contains an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
