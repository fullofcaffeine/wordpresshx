package wordpress.hx.core.profile;

enum abstract ApiClassification(String) to String {
	var Public = "public";
	var Experimental = "experimental";
	var Private = "private";
	var Unsafe = "unsafe";
	var Deprecated = "deprecated";

	public static function parse(value:String):ApiClassification {
		return switch value {
			case "public": Public;
			case "experimental": Experimental;
			case "private": Private;
			case "unsafe": Unsafe;
			case "deprecated": Deprecated;
			case _: throw new ProfileContractError('unknown API classification: ${value}');
		}
	}
}
