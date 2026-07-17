package wordpress.hx.core.profile;

abstract ProfileId(String) {
	private static final VALID = ~/^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):ProfileId {
		if (!VALID.match(value)) {
			throw new ProfileContractError('invalid exact profile ID: ${value}');
		}
		return new ProfileId(value);
	}

	public inline function toString():String {
		return this;
	}
}
