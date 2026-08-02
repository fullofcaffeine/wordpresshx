package semantics;

class Main {
	public static function main():Void {
		final error = "outer-error:";
		try {
			throw new haxe.Exception("caught");
		} catch (error:haxe.Exception) {
			Sys.println(error.message);
		}
		Sys.println(error + "pass");
	}
}
