package semantics;

class Main {
	public static function identity(value:String):String {
		return value;
	}

	public static function main():Void {
		Sys.println(identity("unsupported"));
	}
}
