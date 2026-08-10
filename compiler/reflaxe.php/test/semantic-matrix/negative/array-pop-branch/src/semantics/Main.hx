package semantics;

class Main {
	public static function main():Void {
		final values = [1, 2];
		if (values.length == 2) {
			values.pop();
			Sys.println("array-pop-branch:stock-pass");
		} else {
			Sys.println("array-pop-branch:stock-fail");
		}
	}
}
