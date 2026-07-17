package wordpress.hx.core.profile;

typedef CompileTimeCapabilityManifest = {
	final capabilityId:String;
	final catalogDigest:String;
	final availableIn:Array<String>;
}

class CompileTimeCapability {
	public final capabilityId:CapabilityId;
	public final catalogDigest:CatalogDigest;

	private final profileIds:Array<ProfileId>;

	public function new(capabilityId:CapabilityId, catalogDigest:CatalogDigest, availableIn:Array<ProfileId>) {
		if (availableIn.length == 0) {
			throw new ProfileContractError('compile-time capability ${capabilityId.toString()} has no exact profile availability');
		}
		this.capabilityId = capabilityId;
		this.catalogDigest = catalogDigest;
		this.profileIds = availableIn.copy();
	}

	public function isAvailableIn(profileId:ProfileId):Bool {
		return Lambda.exists(profileIds, candidate -> candidate.toString() == profileId.toString());
	}

	public function require(profileId:ProfileId, sourceLocation:String):Void {
		if (!isAvailableIn(profileId)) {
			throw new ProfileContractError('WPX1204: ${capabilityId.toString()} is not available in profile ${profileId.toString()}. Required by ${sourceLocation}.');
		}
	}

	public function toManifestValue():CompileTimeCapabilityManifest {
		return {
			capabilityId: capabilityId.toString(),
			catalogDigest: catalogDigest.toString(),
			availableIn: profileIds.map(profile -> profile.toString())
		};
	}
}
