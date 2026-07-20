package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;

class SchemaRuleRef {
	public final ruleId:RuleId;
	public final revision:Int;
	public final parity:RuleParity;

	public function new(ruleId:RuleId, revision:Int, parity:RuleParity) {
		if (revision < 1) {
			throw new ContractError("rule revision must be positive");
		}
		this.ruleId = ruleId;
		this.revision = revision;
		this.parity = parity;
	}
}
