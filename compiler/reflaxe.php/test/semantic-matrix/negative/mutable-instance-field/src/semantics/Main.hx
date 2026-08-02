package semantics;

class Greeter {
	var prefix:String;

	public function new(prefix:String) {
		this.prefix = prefix;
	}

	public function render(value:String):String {
		return this.prefix + value;
	}
}

class Main {
	public static function main():Void {
		final greeter = new Greeter("mutable:");
		Sys.println(greeter.render("rejected"));
	}
}
