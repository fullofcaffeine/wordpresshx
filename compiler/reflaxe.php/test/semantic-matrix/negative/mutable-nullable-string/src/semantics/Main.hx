package semantics;

class Main {
	public static function main():Void {
		var value:Null<String> = null;
		value = "present";
		if (value != null) {
			Sys.println("mutable-nullable-string:present");
		} else {
			Sys.println("mutable-nullable-string:missing");
		}
	}
}
