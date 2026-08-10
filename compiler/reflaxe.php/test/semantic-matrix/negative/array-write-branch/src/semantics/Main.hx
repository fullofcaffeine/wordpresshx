package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		if (values.length == 3) {
			values[1] = 5;
		} else {
			Sys.println("array-write-branch:stock-fail");
		}
		if (values[1] == 5) {
			Sys.println("array-write-branch:stock-pass");
		} else {
			Sys.println("array-write-branch:stock-fail");
		}
	}
}
