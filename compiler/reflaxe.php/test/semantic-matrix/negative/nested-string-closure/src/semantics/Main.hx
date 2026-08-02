package semantics;

class Main {
	public static function main():Void {
		final prefix = "nested:";
		final render = function(value:String):String {
			final inner = function(suffix:String):String {
				return prefix + suffix;
			};
			return inner(value);
		};
		Sys.println(render("closure"));
	}
}
