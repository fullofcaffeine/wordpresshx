package wordpress.hx.i18n;

/** Validated WordPress gettext text domain. */
abstract TextDomain(String) {
	static final VALID = ~/^[a-z0-9]+(?:-[a-z0-9]+)*$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):TextDomain {
		if (value == null || !VALID.match(value)) {
			throw "text domain must be a lowercase WordPress slug: " + value;
		}
		return new TextDomain(value);
	}

	public inline function toString():String {
		return this;
	}
}
