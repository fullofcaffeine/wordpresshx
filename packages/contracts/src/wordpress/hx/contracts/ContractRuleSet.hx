package wordpress.hx.contracts;

import wordpress.hx.contracts.schema.SchemaRuleRef;

interface ContractRuleSet {
	public function evaluate(rule:SchemaRuleRef, value:WireValue):RuleEvaluation;
}
