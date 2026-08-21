package semantics;

class Main {
	public static function different(left:String, right:String):Bool {
		return left != right;
	}

	public static function main():Void {
		if (different(null, "present")) {
			Sys.println("null-string-predicate:accepted");
		} else {
			Sys.println("null-string-predicate:rejected");
		}
	}
}
