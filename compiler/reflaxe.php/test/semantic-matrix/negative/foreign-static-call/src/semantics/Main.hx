package semantics;

class Main {
	public static function main():Void {
		final answer = Std.int(42.0);
		if (answer == 42) {
			Sys.println("foreign-call:unexpected");
		} else {
			Sys.println("foreign-call:fail");
		}
	}
}
