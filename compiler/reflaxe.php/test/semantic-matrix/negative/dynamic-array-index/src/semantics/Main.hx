package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		final index = 1;
		final selected = values[index];
		if (selected == 1) {
			Sys.println("dynamic-array-index:stock-pass");
		} else {
			Sys.println("dynamic-array-index:stock-fail");
		}
	}
}
