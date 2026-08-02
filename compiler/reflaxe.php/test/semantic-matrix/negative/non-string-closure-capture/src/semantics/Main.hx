package semantics;

class Main {
	public static function main():Void {
		final count = 1;
		final render = function(value:String):String {
			return count == 1 ? value : value;
		};
		Sys.println(render("non-string-capture"));
	}
}
