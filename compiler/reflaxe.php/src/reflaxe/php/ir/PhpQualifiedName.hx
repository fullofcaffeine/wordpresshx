package reflaxe.php.ir;

/** A validated relative or root-qualified PHP name. **/
class PhpQualifiedName {
	public final absolute:Bool;

	final segments:Array<PhpIdentifier>;

	private function new(absolute:Bool, segments:Array<PhpIdentifier>) {
		if (segments == null || segments.length == 0) {
			throw "PHP qualified name requires at least one segment";
		}
		this.absolute = absolute;
		this.segments = segments.copy();
	}

	public static function parse(value:String):PhpQualifiedName {
		if (value == null || value.length == 0) {
			throw "Empty PHP qualified name";
		}
		final absolute = StringTools.startsWith(value, "\\");
		final body = absolute ? value.substr(1) : value;
		if (body.length == 0) {
			throw "Empty PHP qualified name";
		}
		final parts = body.split("\\");
		if (parts.indexOf("") != -1) {
			throw "Invalid PHP qualified name: " + value;
		}
		return new PhpQualifiedName(absolute, parts.map(PhpIdentifier.named));
	}

	public static function relative(value:String):PhpQualifiedName {
		final parsed = parse(value);
		if (parsed.absolute) {
			throw "Expected relative PHP name: " + value;
		}
		return parsed;
	}

	public function toString():String {
		return (absolute ? "\\" : "") + segments.map(segment -> segment.value).join("\\");
	}
}
