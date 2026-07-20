package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;
import wordpress.hx.contracts.ContractRuleSet;

class SchemaDocument {
	public final schemaId:SchemaId;
	public final version:Int;
	public final root:SchemaNode;
	public final migrations:FrozenList<MigrationRef>;
	public final rules:ContractRuleSet;

	public function new(schemaId:SchemaId, version:Int, root:SchemaNode, migrations:Array<MigrationRef>, declarationRules:ContractRuleSet) {
		if (version < 1) {
			throw new ContractError("schema version must be positive");
		}
		this.schemaId = schemaId;
		this.version = version;
		this.root = root;
		this.migrations = migrations;
		this.rules = declarationRules;
		SchemaInvariant.validate(this);
	}
}
