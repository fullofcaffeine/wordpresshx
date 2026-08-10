package semantics;

class Main {
	public static function main():Void {
		final values = [1, 2];
		values.pop();
		final removed = values[1];
		if (removed == null) {
			Sys.println("array-pop-removed-index:stock-null");
		} else {
			Sys.println("array-pop-removed-index:stock-value");
		}
	}
}
