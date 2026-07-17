package reflaxe.php.ir;

/** A validated PHP identifier without target punctuation. **/
class PhpIdentifier {
	static final PATTERN = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	public final value:String;

	private function new(value:String) {
		if (value == null || !PATTERN.match(value)) {
			throw "Invalid PHP identifier: " + value;
		}
		this.value = value;
	}

	public static function named(value:String):PhpIdentifier {
		return new PhpIdentifier(value);
	}

	public static function constructor():PhpIdentifier {
		return new PhpIdentifier("__construct");
	}

	public function toString():String {
		return value;
	}
}
