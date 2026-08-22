package semantics;

class Main {
	public static function main():Void {
		final left:Null<String> = "10";
		final right:Null<String> = "2";
		if (left <= right) {
			Sys.println("nullable-string-less-or-equal:stock-pass");
		}
	}
}
