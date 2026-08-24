package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpStmt;

/** One contiguous, checkpointed WordPress plugin schema migration. */
class WordPressPluginUpgradeStep {
	public final fromVersion:Int;
	public final toVersion:Int;

	final statementValues:Array<PhpStmt>;

	public var statements(get, never):Array<PhpStmt>;

	public function new(fromVersion:Int, toVersion:Int, statements:Array<PhpStmt>) {
		if (fromVersion < 0 || toVersion != fromVersion + 1) {
			throw "WordPress upgrade steps must advance by one non-negative schema version";
		}
		if (statements == null) {
			throw "WordPress upgrade step requires a closed statement inventory";
		}
		for (statement in statements) {
			if (statement == null) {
				throw "WordPress upgrade step statements cannot contain null";
			}
		}
		this.fromVersion = fromVersion;
		this.toVersion = toVersion;
		this.statementValues = statements.copy();
	}

	function get_statements():Array<PhpStmt> {
		return statementValues.copy();
	}
}
