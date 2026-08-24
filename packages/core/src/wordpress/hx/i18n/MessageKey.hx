package wordpress.hx.i18n;

/** Stable application identity for one translatable message. */
abstract MessageKey(String) {
	static final VALID = ~/^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)+$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):MessageKey {
		if (value == null || !VALID.match(value)) {
			throw "message key must be a stable lowercase identity: " + value;
		}
		return new MessageKey(value);
	}

	public inline function toString():String {
		return this;
	}
}
