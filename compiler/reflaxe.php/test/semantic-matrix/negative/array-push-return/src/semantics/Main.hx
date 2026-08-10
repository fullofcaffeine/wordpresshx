package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		final pushedCount = values.push(5);
		if (pushedCount == 4) {
			Sys.println("array-push-return:stock-pass");
		} else {
			Sys.println("array-push-return:stock-fail");
		}
	}
}
