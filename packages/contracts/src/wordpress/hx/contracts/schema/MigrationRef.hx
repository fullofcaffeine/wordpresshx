package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;

class MigrationRef {
	public final fromVersion:Int;
	public final toVersion:Int;
	public final ruleId:RuleId;
	public final revision:Int;

	public function new(fromVersion:Int, toVersion:Int, ruleId:RuleId, revision:Int) {
		if (fromVersion < 1 || toVersion != fromVersion + 1 || revision < 1) {
			throw new ContractError("migration must be one positive adjacent version step with a positive rule revision");
		}
		this.fromVersion = fromVersion;
		this.toVersion = toVersion;
		this.ruleId = ruleId;
		this.revision = revision;
	}
}
