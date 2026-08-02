package semantics;

class Main {
	public static function main():Void {
		final answer = Calculator.add(40, 2);
		if (answer == 42) {
			Sys.println("numeric-control-flow:pass");
		} else {
			Sys.println("numeric-control-flow:fail");
		}

		var total = 0;
		var current = 1;
		while (current <= 4) {
			total = total + current;
			current = current + 1;
		}
		if (total == 10) {
			Sys.println("mutable-loop:pass");
		} else {
			Sys.println("mutable-loop:fail");
		}
	}
}
