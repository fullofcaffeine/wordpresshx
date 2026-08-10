package semantics;

class Main {
	public static function main():Void {
		final values = [3, 1, 4];
		if (values.length == 3) {
			values.push(5);
		} else {
			Sys.println("array-push-branch:stock-fail");
		}
		if (values.length == 4) {
			Sys.println("array-push-branch:stock-pass");
		} else {
			Sys.println("array-push-branch:stock-fail");
		}
	}
}
