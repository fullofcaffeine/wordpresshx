package wordpress.hx.core.profile;

enum abstract EvidenceStatus(String) to String {
	var Inventoried = "inventoried";
	var Typed = "typed";
	var Generated = "generated";
	var RuntimeTested = "runtime-tested";
	var ProductionSupported = "production-supported";

	public static function parse(value:String):EvidenceStatus {
		return switch value {
			case "inventoried": Inventoried;
			case "typed": Typed;
			case "generated": Generated;
			case "runtime-tested": RuntimeTested;
			case "production-supported": ProductionSupported;
			case _: throw new ProfileContractError('unknown evidence status: ${value}');
		}
	}

	public function rank():Int {
		return switch cast(this, String) {
			case "inventoried": 0;
			case "typed": 1;
			case "generated": 2;
			case "runtime-tested": 3;
			case "production-supported": 4;
			case value: throw new ProfileContractError('unknown evidence status: ${value}');
		}
	}

	public function canPromoteTo(target:EvidenceStatus):Bool {
		return target.rank() == rank() + 1;
	}
}
