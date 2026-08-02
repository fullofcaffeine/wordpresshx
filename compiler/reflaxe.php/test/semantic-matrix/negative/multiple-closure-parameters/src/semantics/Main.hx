package semantics;

class Main {
	public static function main():Void {
		final prefix = "multiple:";
		final render = function(first:String, second:String):String {
			return prefix + first + second;
		};
		Sys.println(render("closure-", "parameters"));
	}
}
