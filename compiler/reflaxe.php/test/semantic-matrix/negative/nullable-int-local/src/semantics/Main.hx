package semantics;

class Main {
	public static function main():Void {
		final value:Null<Int> = null;
		if (value == null) {
			Sys.println("nullable-int:missing");
		} else {
			Sys.println("nullable-int:present");
		}
	}
}
