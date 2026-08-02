package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		final missing = values[9];
		if (missing == null) {
			Sys.println("out-of-bounds-array-index:stock-null");
		} else {
			Sys.println("out-of-bounds-array-index:stock-value");
		}
	}
}
