package semantics;

class Main {
	public static function decorate(value:String):String {
		return value;
	}

	public static function main():Void {
		final label = decorate(null);
		Sys.println(label);
	}
}
