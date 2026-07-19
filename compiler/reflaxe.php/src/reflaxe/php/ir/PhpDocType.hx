package reflaxe.php.ir;

/** Closed PHPDoc type syntax for PHP 7.4 signatures that need richer analysis types. */
class PhpDocType {
	final kind:PhpDocTypeKind;

	private function new(kind:PhpDocTypeKind) {
		this.kind = kind;
	}

	public static function mixed():PhpDocType {
		return new PhpDocType(PhpDocMixed);
	}

	public static function integer():PhpDocType {
		return new PhpDocType(PhpDocInt);
	}

	public static function string():PhpDocType {
		return new PhpDocType(PhpDocString);
	}

	public static function named(name:PhpQualifiedName):PhpDocType {
		if (name == null) {
			throw "PHPDoc named type requires a qualified name";
		}
		return new PhpDocType(PhpDocNamed(name));
	}

	public static function array(key:PhpDocType, value:PhpDocType):PhpDocType {
		if (key == null || value == null) {
			throw "PHPDoc array type requires key and value types";
		}
		switch key.kind {
			case PhpDocInt | PhpDocString:
			case _:
				throw "PHPDoc array keys must be int or string";
		}
		return new PhpDocType(PhpDocArray(key, value));
	}

	public static function union(types:Array<PhpDocType>):PhpDocType {
		if (types == null || types.length < 2) {
			throw "PHPDoc union requires at least two types";
		}
		final values = types.copy();
		values.sort((left, right) -> compareText(left.render(), right.render()));
		var previous:Null<String> = null;
		for (value in values) {
			if (value == null) {
				throw "PHPDoc union cannot contain null";
			}
			switch value.kind {
				case PhpDocUnion(_):
					throw "Nested PHPDoc unions are not admitted";
				case _:
			}
			final rendered = value.render();
			if (rendered == previous) {
				throw "PHPDoc union types must be unique";
			}
			previous = rendered;
		}
		return new PhpDocType(PhpDocUnion(values));
	}

	public function render():String {
		return switch kind {
			case PhpDocMixed: "mixed";
			case PhpDocInt: "int";
			case PhpDocString: "string";
			case PhpDocNamed(name): name.toString();
			case PhpDocArray(key, value): "array<" + key.render() + ", " + value.render() + ">";
			case PhpDocUnion(types): types.map(type -> type.render()).join("|");
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

private enum PhpDocTypeKind {
	PhpDocMixed;
	PhpDocInt;
	PhpDocString;
	PhpDocNamed(name:PhpQualifiedName);
	PhpDocArray(key:PhpDocType, value:PhpDocType);
	PhpDocUnion(types:Array<PhpDocType>);
}
