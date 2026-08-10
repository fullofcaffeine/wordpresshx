package semantics;

class Main {
	public static function main():Void {
		final product:Int = 1073741824 * 2;
		if (product == -2147483648) {
			Sys.println("overflow-int-multiplication:stock-pass");
		} else {
			Sys.println("overflow-int-multiplication:stock-fail");
		}
	}
}
