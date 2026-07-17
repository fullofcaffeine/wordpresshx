package wordpress.hx.core.profile;

abstract CatalogRevision(String) {
	private static final VALID = ~/^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*\/catalog-v[1-9][0-9]*$/;

	private inline function new(value:String) {
		this = value;
	}

	public static function parse(profileId:ProfileId, value:String):CatalogRevision {
		if (!VALID.match(value) || !StringTools.startsWith(value, profileId.toString() + "/catalog-v")) {
			throw new ProfileContractError('catalog revision does not belong to ${profileId.toString()}: ${value}');
		}
		return new CatalogRevision(value);
	}

	public inline function toString():String {
		return this;
	}
}
