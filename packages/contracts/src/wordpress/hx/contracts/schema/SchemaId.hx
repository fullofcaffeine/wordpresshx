package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;

abstract SchemaId(String) {
	private function new(value:String) {
		this = value;
	}

	public static function parse(value:String):SchemaId {
		if (!~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/.match(value)) {
			throw new ContractError("invalid schema ID: " + value);
		}
		return new SchemaId(value);
	}

	public function asString():String {
		return this;
	}
}
