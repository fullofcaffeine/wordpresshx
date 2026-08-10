package semantics;

class Main {
	public static function main():Void {
		final negated = -(-2147483647 - 1);
		if (negated == -2147483648) {
			Sys.println("overflow-int-negation:stock-pass");
		} else {
			Sys.println("overflow-int-negation:stock-fail");
		}
	}
}
