package semantics;

class Greeter {
	final prefix:String;

	public function new(prefix:String) {
		this.prefix = prefix;
	}

	public function render(value:String):String {
		return this.prefix + value;
	}
}
