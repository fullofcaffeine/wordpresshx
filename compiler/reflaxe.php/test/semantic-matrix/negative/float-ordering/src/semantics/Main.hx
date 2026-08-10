package semantics;

class Main {
	public static function main():Void {
		if (1.5 < 2.0) {
			Sys.println("float-ordering:stock-pass");
		} else {
			Sys.println("float-ordering:stock-fail");
		}
	}
}
