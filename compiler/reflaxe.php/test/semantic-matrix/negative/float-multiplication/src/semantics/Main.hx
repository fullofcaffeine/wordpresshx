package semantics;

class Main {
	public static function main():Void {
		final product = 2.5 * 4.0;
		if (product == 10.0) {
			Sys.println("float-multiplication:stock-pass");
		} else {
			Sys.println("float-multiplication:stock-fail");
		}
	}
}
