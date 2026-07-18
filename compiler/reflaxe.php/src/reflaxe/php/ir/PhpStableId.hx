package reflaxe.php.ir;

/** Shared validator for deterministic semantic and artifact identities. **/
class PhpStableId {
	static final PATTERN = ~/^[A-Za-z0-9][A-Za-z0-9._:\/@+\-]{0,255}$/;

	public static function validate(value:String, label:String):String {
		if (value == null || !PATTERN.match(value)) {
			throw "Invalid PHP " + label + ": " + value;
		}
		return value;
	}
}
