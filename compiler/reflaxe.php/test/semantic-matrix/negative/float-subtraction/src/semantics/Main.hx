package semantics;

class Main {
	public static function main():Void {
		final difference = 4.5 - 1.5;
		if (difference == 3.0) {
			Sys.println("float-subtraction:stock-pass");
		} else {
			Sys.println("float-subtraction:stock-fail");
		}
	}
}
