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

		final enabled = Calculator.negate(false);
		if (enabled) {
			Sys.println("bool-control:pass");
		} else {
			Sys.println("bool-control:fail");
		}

		final andSkipped = false && Calculator.probe(true);
		final orSkipped = true || Calculator.probe(false);
		final andEvaluated = true && Calculator.probe(false);
		final grouped = (true || Calculator.probe(false)) && false;
		if (!andSkipped && orSkipped && !andEvaluated && !grouped) {
			Sys.println("bool-short-circuit:pass");
		} else {
			Sys.println("bool-short-circuit:fail");
		}

		final greeter = new Greeter("instance-layout:");
		Sys.println(greeter.render("pass"));

		final prefix = "closure-capture:";
		final render = function(value:String):String {
			return prefix + value;
		};
		Sys.println(render("pass"));
	}
}
