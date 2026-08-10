package semantics;

class Main {
	public static function main():Void {
		final source = 3;
		final negated = -source;
		if (negated == -3) {
			Sys.println("runtime-int-negation:stock-pass");
		} else {
			Sys.println("runtime-int-negation:stock-fail");
		}
	}
}
