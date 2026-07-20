package wordpress.hx.contracts;

import wordpress.hx.contracts.schema.SchemaRuleRef;

/** Fails every named validation rule closed. */
class NoContractRules implements ContractRuleSet {
	public function new() {}

	public function evaluate(rule:SchemaRuleRef, value:WireValue):RuleEvaluation {
		return RuleUnavailable;
	}
}
