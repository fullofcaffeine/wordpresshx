package semantics;

class Main {
	public static function main():Void {
		final left:Null<String> = "2";
		final right:Null<String> = "10";
		if (left >= right) {
			Sys.println("nullable-string-greater-or-equal:stock-pass");
		}
	}
}
