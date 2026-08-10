package semantics;

class Main {
	public static function main():Void {
		final values = [1, 2];
		final popped = values.pop();
		if (popped == 2) {
			Sys.println("array-pop-return:stock-pass");
		} else {
			Sys.println("array-pop-return:stock-fail");
		}
	}
}
