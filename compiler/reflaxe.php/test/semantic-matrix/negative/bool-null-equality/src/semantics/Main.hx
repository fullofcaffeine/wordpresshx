package semantics;

class Main {
	static function equalsNull(value:Bool):Bool {
		return value == null;
	}

	static function main():Void {
		Sys.println(equalsNull(false) ? "bool-null-equality:stock-true" : "bool-null-equality:stock-false");
	}
}
