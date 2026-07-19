package wordpresshx.cli.project;

import js.node.Buffer;

/** Complete deterministic native bootstrap emission and its typed receipts. */
class PluginEmission {
	public final plan:PluginPlan;
	public final files:Array<PluginEmittedFile>;
	public final planBytes:Buffer;
	public final planSha256:String;
	public final resultBytes:Buffer;
	public final resultSha256:String;

	public function new(plan:PluginPlan, files:Array<PluginEmittedFile>, planBytes:Buffer, resultBytes:Buffer) {
		this.plan = plan;
		this.files = files.copy();
		this.files.sort((left, right) -> compareText(left.relativePath, right.relativePath));
		this.planBytes = planBytes;
		this.planSha256 = wordpresshx.cli.ownership.OwnershipJson.digest(planBytes);
		this.resultBytes = resultBytes;
		this.resultSha256 = wordpresshx.cli.ownership.OwnershipJson.digest(resultBytes);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
