package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;

abstract RuleId(String) {
	private function new(value:String) {
		this = value;
	}

	public static function parse(value:String):RuleId {
		if (!~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/.match(value)) {
			throw new ContractError("invalid rule ID: " + value);
		}
		return new RuleId(value);
	}

	public function asString():String {
		return this;
	}
}
