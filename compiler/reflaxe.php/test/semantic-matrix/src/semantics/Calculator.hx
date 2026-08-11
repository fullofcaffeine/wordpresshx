package semantics;

class Calculator {
	public static function add(left:Int, right:Int):Int {
		return left + right;
	}

	public static function decorate(prefix:String, value:String):String {
		return prefix + value;
	}

	public static function isMissing(value:Null<String>):Bool {
		return value == null;
	}

	public static function isPresent(value:Null<String>):Bool {
		return value != null;
	}

	public static function roundTrip(value:Null<String>):Null<String> {
		return value;
	}

	public static function negate(value:Bool):Bool {
		return !value;
	}

	public static function probe(value:Bool):Bool {
		Sys.println("bool-probe");
		return value;
	}

	public static function subtract(left:Int, right:Int):Int {
		return left - right;
	}

	public static function multiply(left:Int, right:Int):Int {
		return left * right;
	}
}
