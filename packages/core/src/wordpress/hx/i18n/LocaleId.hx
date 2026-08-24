package wordpress.hx.i18n;

/** WordPress locale identity used by emitted translation artifacts. */
abstract LocaleId(String) {
	static final VALID = ~/^[a-z]{2,3}(?:_[A-Z]{2})?$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):LocaleId {
		if (value == null || !VALID.match(value)) {
			throw "locale must use WordPress language or language_REGION syntax: " + value;
		}
		return new LocaleId(value);
	}

	public inline function toString():String {
		return this;
	}
}
