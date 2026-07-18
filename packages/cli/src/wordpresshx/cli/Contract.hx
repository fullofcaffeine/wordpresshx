package wordpresshx.cli;

/** Dependency-free closed-contract accessors for trace index and map JSON. **/
class Contract {
	public static function object(value:Dynamic, label:String):Dynamic {
		if (value == null || !Reflect.isObject(value) || Std.isOfType(value, Array) || Std.isOfType(value, String)) {
			fail(label + " must be an object");
		}
		return value;
	}

	public static function fields(value:Dynamic, expected:Array<String>, label:String):Void {
		object(value, label);
		final actual = Reflect.fields(value);
		actual.sort(Reflect.compare);
		final wanted = expected.copy();
		wanted.sort(Reflect.compare);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail(label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "));
		}
	}

	public static function string(value:Dynamic, field:String, label:String):String {
		final result = Reflect.field(object(value, label), field);
		if (!Std.isOfType(result, String) || result.length == 0) {
			fail(label + "." + field + " must be a non-empty string");
		}
		return result;
	}

	public static function integer(value:Dynamic, field:String, label:String):Int {
		final result = Reflect.field(object(value, label), field);
		if (!Std.isOfType(result, Int)) {
			fail(label + "." + field + " must be an integer");
		}
		return result;
	}

	public static function boolean(value:Dynamic, field:String, label:String):Bool {
		final result = Reflect.field(object(value, label), field);
		if (!Std.isOfType(result, Bool)) {
			fail(label + "." + field + " must be a boolean");
		}
		return result;
	}

	public static function array(value:Dynamic, field:String, label:String):Array<Dynamic> {
		final result = Reflect.field(object(value, label), field);
		if (!Std.isOfType(result, Array)) {
			fail(label + "." + field + " must be an array");
		}
		return cast result;
	}

	public static function require(value:Bool, message:String, ambiguity:Bool = false):Void {
		if (!value) {
			fail(message, ambiguity ? 4 : 3);
		}
	}

	public static function fail(message:String, exitCode:Int = 3):Dynamic {
		throw new TraceFailure(message, exitCode);
	}
}
