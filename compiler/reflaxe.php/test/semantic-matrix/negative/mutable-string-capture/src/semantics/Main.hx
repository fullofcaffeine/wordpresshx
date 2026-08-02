package semantics;

class Main {
	public static function main():Void {
		var prefix = "before:";
		final render = function(value:String):String {
			return prefix + value;
		};
		prefix = "after:";
		Sys.println(render("mutable-capture"));
	}
}
