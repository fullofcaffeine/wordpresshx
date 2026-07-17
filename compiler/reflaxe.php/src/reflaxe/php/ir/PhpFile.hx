package reflaxe.php.ir;

/** A complete native PHP file with deterministic declarations and explicit top-level statements. **/
class PhpFile {
	public final path:String;
	public final namespace:Null<PhpQualifiedName>;
	public final strictTypes:Bool;

	final declarationValues:Array<PhpDeclaration>;
	final statementValues:Array<PhpStmt>;

	public var declarations(get, never):Array<PhpDeclaration>;
	public var statements(get, never):Array<PhpStmt>;

	public function new(path:String, ?namespace:PhpQualifiedName, strictTypes:Bool = true, ?declarations:Array<PhpDeclaration>, ?statements:Array<PhpStmt>) {
		this.path = validatePath(path);
		if (namespace != null && namespace.absolute) {
			throw "PHP namespace declarations must use a relative qualified name";
		}
		this.namespace = namespace;
		this.strictTypes = strictTypes;
		final declaredValues = declarations == null ? [] : declarations.copy();
		final topLevelStatements = statements == null ? [] : statements.copy();
		for (declaration in declaredValues) {
			if (declaration == null) {
				throw "PHP file declarations cannot contain null";
			}
		}
		for (statement in topLevelStatements) {
			if (statement == null) {
				throw "PHP file statements cannot contain null";
			}
		}
		this.declarationValues = declaredValues;
		this.statementValues = topLevelStatements;
	}

	function get_declarations():Array<PhpDeclaration> {
		return declarationValues.copy();
	}

	function get_statements():Array<PhpStmt> {
		return statementValues.copy();
	}

	static function validatePath(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw "PHP file requires a relative .php path";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/")
			|| normalized.indexOf(":") != -1
			|| ~/^[A-Za-z]:\//.match(normalized)
			|| !StringTools.endsWith(normalized, ".php")) {
			throw "PHP file requires a relative .php path: " + value;
		}
		for (part in normalized.split("/")) {
			if (part.length == 0 || part == "." || part == "..") {
				throw "PHP file path contains an unsafe segment: " + value;
			}
		}
		return normalized;
	}
}
