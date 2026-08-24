package wordpress.hx.i18n._internal;

/** Runtime validation retained behind compile-time message declarations. */
class MessageRuntime {
	public static function text(value:String, label:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") != -1) {
			throw label + " must be non-empty text without NUL bytes";
		}
		return value;
	}

	public static function context(value:String):String {
		return text(value, "message context");
	}

	public static function comment(value:String):String {
		final validated = text(value, "translator comment");
		if (validated.indexOf("\r") != -1 || validated.indexOf("\n") != -1 || validated.indexOf("*/") != -1) {
			throw "translator comment must be one safe line";
		}
		return validated;
	}

	public static function boundary(value:String):String {
		if (value == null || !~/^[a-z][a-z0-9]*(?:[._:-][a-z0-9]+)+$/.match(value)) {
			throw "external message boundary must be a stable identity: " + value;
		}
		return value;
	}

	public static function noPlaceholders(value:String, label:String):String {
		return validatePlaceholders(text(value, label), null, label);
	}

	public static function stringPlaceholder(value:String, label:String):String {
		return validatePlaceholders(text(value, label), "%1$s", label);
	}

	public static function countPlaceholder(value:String, label:String):String {
		return validatePlaceholders(text(value, label), "%1$d", label);
	}

	static function validatePlaceholders(value:String, expected:Null<String>, label:String):String {
		var found = 0;
		var index = 0;
		while (index < value.length) {
			if (value.charAt(index) != "%") {
				index++;
				continue;
			}
			if (value.substr(index, 2) == "%%") {
				index += 2;
				continue;
			}
			if (expected != null && value.substr(index, expected.length) == expected) {
				found++;
				index += expected.length;
				continue;
			}
			throw label + " contains an unsupported placeholder at character " + Std.string(index + 1);
		}
		if (expected == null && found != 0) {
			throw label + " must not contain placeholders";
		}
		if (expected != null && found == 0) {
			throw label + " must contain numbered placeholder " + expected;
		}
		return value;
	}
}
