package semantics;

class Main {
	public static function main():Void {
		if (1.5 != 2.0) {
			Sys.println("float-inequality:stock-pass");
		} else {
			Sys.println("float-inequality:stock-fail");
		}
	}
}
