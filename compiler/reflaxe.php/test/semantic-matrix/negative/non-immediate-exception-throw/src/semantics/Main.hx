package semantics;

class Main {
	public static function main():Void {
		try {
			Sys.println("before-exception");
			throw new haxe.Exception("expected-exception");
		} catch (error:haxe.Exception) {
			Sys.println(error.message);
		}
	}
}
