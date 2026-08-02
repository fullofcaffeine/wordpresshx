package semantics;

class Main {
	public static function add(left:Int, right:Int = 2):Int {
		return left + right;
	}

	public static function main():Void {
		final answer = add(40);
		if (answer == 42) {
			Sys.println("optional-parameter:unexpected");
		} else {
			Sys.println("optional-parameter:fail");
		}
	}
}
