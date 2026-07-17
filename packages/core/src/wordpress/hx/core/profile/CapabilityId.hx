package wordpress.hx.core.profile;

abstract CapabilityId(String) {
	private static final VALID = ~/^[a-z][A-Za-z0-9._@\/-]*[A-Za-z0-9]$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(value:String):CapabilityId {
		if (!VALID.match(value)) {
			throw new ProfileContractError('invalid capability ID: ${value}');
		}
		return new CapabilityId(value);
	}

	public inline function toString():String {
		return this;
	}
}
