package semantics;

class Main {
	public static function main():Void {
		final answer = Calculator.add(40, 2);
		if (answer == 42) {
			Sys.println("numeric-control-flow:pass");
		} else {
			Sys.println("numeric-control-flow:fail");
		}
	}
}
