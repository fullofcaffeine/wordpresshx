package semantics;

class Calculator {
	public static function add(left:Int, right:Int):Int {
		return left + right;
	}

	public static function decorate(prefix:String, value:String):String {
		return prefix + value;
	}
}
