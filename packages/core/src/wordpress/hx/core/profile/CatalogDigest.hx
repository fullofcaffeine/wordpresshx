package wordpress.hx.core.profile;

abstract CatalogDigest(String) {
	private static final VALID = ~/^[0-9a-f]{64}$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):CatalogDigest {
		if (!VALID.match(value)) {
			throw new ProfileContractError('invalid catalog SHA-256: ${value}');
		}
		return new CatalogDigest(value);
	}

	public inline function toString():String {
		return this;
	}
}
