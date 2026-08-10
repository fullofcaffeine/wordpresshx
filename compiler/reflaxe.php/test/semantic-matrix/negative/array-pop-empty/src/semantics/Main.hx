package semantics;

class Main {
	public static function main():Void {
		final values:Array<Int> = [];
		values.pop();
		if (values.length == 0) {
			Sys.println("array-pop-empty:stock-pass");
		} else {
			Sys.println("array-pop-empty:stock-fail");
		}
	}
}
