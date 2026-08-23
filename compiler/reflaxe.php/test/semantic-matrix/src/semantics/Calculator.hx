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

	public static function negateInt(value:Int):Int {
		return -value;
	}

	public static function remainderByFive(value:Int):Int {
		return value % 5;
	}

	public static function divideByTwo(value:Int):Int {
		return Std.int(value / 2);
	}

	public static function divideByNegativeOne(value:Int):Int {
		return Std.int(value / -1);
	}

	public static function sameBool(left:Bool, right:Bool):Bool {
		return left == right;
	}

	public static function differentBool(left:Bool, right:Bool):Bool {
		return left != right;
	}

	public static function differentInt(left:Int, right:Int):Bool {
		return left != right;
	}

	public static function differentString(left:String, right:String):Bool {
		return left != right;
	}

	public static function lessString(left:String, right:String):Bool {
		return left < right;
	}

	public static function lessOrEqualString(left:String, right:String):Bool {
		return left <= right;
	}

	public static function greaterString(left:String, right:String):Bool {
		return left > right;
	}

	public static function greaterOrEqualString(left:String, right:String):Bool {
		return left >= right;
	}
}
