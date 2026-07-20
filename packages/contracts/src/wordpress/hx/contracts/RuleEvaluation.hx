package wordpress.hx.contracts;

enum RuleEvaluation {
	RulePassed;
	RuleRejected(actual:String);
	RuleUnavailable;
}
