package semantics;

class BaseGreeter {
	public function new(prefix:String) {
		Sys.println(prefix);
	}
}

class Main extends BaseGreeter {
	public function new(prefix:String) {
		super(prefix);
	}

	public static function main():Void {
		final greeter = new Main("inherited-instance-layout");
	}
}
