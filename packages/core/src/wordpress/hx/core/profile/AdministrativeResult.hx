package wordpress.hx.core.profile;

enum abstract AdministrativeResult(String) to String {
	var NotTested = "not-tested";
	var Failed = "failed";
	var NotApplicable = "not-applicable";
	var Unsupported = "unsupported";
	var Withdrawn = "withdrawn";

	public static function parse(value:String):AdministrativeResult {
		return switch value {
			case "not-tested": NotTested;
			case "failed": Failed;
			case "not-applicable": NotApplicable;
			case "unsupported": Unsupported;
			case "withdrawn": Withdrawn;
			case _: throw new ProfileContractError('unknown administrative result: ${value}');
		}
	}
}
