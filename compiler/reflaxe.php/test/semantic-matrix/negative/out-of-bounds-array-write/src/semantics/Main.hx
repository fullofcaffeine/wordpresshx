package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		values[3] = 5;
		if (values.length == 4 && values[3] == 5) {
			Sys.println("out-of-bounds-array-write:stock-pass");
		} else {
			Sys.println("out-of-bounds-array-write:stock-fail");
		}
	}
}
