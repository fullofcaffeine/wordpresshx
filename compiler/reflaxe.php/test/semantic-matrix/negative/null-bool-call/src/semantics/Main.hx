package semantics;

class Main {
	public static function negate(value:Bool):Bool {
		return !value;
	}

	public static function main():Void {
		final result = negate(null);
		if (result) {
			Sys.println("null-bool:true");
		} else {
			Sys.println("null-bool:false");
		}
	}
}
