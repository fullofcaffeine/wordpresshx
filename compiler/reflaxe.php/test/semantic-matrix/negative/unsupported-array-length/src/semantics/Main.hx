package semantics;

class Main {
	public static function main():Void {
		final valueCount = ["x"].length;
		if (valueCount == 1) {
			Sys.println("unsupported-array-length:stock-pass");
		} else {
			Sys.println("unsupported-array-length:stock-fail");
		}
	}
}
