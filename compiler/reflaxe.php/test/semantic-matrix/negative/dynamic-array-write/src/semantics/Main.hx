package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		final index = 1;
		values[index] = 5;
		if (values[1] == 5) {
			Sys.println("dynamic-array-write:stock-pass");
		} else {
			Sys.println("dynamic-array-write:stock-fail");
		}
	}
}
