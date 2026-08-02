package semantics;

class Greeter {
	final prefix:String = "default:";

	public function new(value:String) {}

	public function render(value:String):String {
		return this.prefix + value;
	}
}

class Main {
	public static function main():Void {
		final greeter = new Greeter("ignored");
		Sys.println(greeter.render("rejected"));
	}
}
