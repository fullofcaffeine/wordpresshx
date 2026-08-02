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

		final values = [3, 1, 4];
		final selected = values[1] + values[2];
		if (selected == 5) {
			Sys.println("int-array-read:pass");
		} else {
			Sys.println("int-array-read:fail");
		}

		final label = Calculator.decorate("Haxe ", "→ PHP 🚀");
		Sys.println(label);
		if (label == "Haxe → PHP 🚀") {
			Sys.println("unicode-string:pass");
		} else {
			Sys.println("unicode-string:fail");
		}
	}
}
