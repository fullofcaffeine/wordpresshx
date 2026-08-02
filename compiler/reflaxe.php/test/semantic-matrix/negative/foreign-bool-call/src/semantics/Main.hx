package semantics;

class Main {
	public static function main():Void {
		final result = StringTools.isSpace(" ", 0);
		if (result) {
			Sys.println("foreign-bool:true");
		} else {
			Sys.println("foreign-bool:false");
		}
	}
}
