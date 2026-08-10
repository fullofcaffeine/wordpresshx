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

		try {
			throw new haxe.Exception("expected-exception");
		} catch (error:haxe.Exception) {
			final message = error.message;
			if (message == "expected-exception") {
				Sys.println("exception-catch:pass");
			} else {
				Sys.println("exception-catch:fail");
			}
		}

		final missing:Null<String> = null;
		final present:Null<String> = "present";
		if (Calculator.isMissing(missing) && Calculator.isPresent(present) && Calculator.isMissing(null) && Calculator.isPresent("direct")) {
			Sys.println("nullable-string:pass");
		} else {
			Sys.println("nullable-string:fail");
		}

		final returnedMissing:Null<String> = Calculator.roundTrip(missing);
		final returnedPresent:Null<String> = Calculator.roundTrip(present);
		if (Calculator.isMissing(returnedMissing) && Calculator.isPresent(returnedPresent)) {
			Sys.println("nullable-string-return:pass");
		} else {
			Sys.println("nullable-string-return:fail");
		}

		final unicodeLength = "A🚀".length;
		if (unicodeLength == 2) {
			Sys.println("unicode-string-length:pass");
		} else {
			Sys.println("unicode-string-length:fail");
		}

		final valueCount = values.length;
		if (valueCount == 3) {
			Sys.println("int-array-length:pass");
		} else {
			Sys.println("int-array-length:fail");
		}

		values.push(5);
		final pushedCount = values.length;
		final pushedValue = values[3];
		final pushedSummary = pushedCount + pushedValue;
		if (pushedSummary == 9) {
			Sys.println("int-array-push:pass");
		} else {
			Sys.println("int-array-push:fail");
		}
	}
}
