package wordpresshx.cli.generatedoutput;

enum GeneratedOutputOperation {
	Enable;
	Check;
}

/** Closed generated-output command request. */
class GeneratedOutputRequest {
	public final operation:GeneratedOutputOperation;
	public final rootIds:Array<String>;
	public final projectPath:Null<String>;
	public final dryRun:Bool;
	public final json:Bool;

	public function new(operation:GeneratedOutputOperation, rootIds:Array<String>, projectPath:Null<String>, dryRun:Bool, json:Bool) {
		this.operation = operation;
		this.rootIds = rootIds;
		this.projectPath = projectPath;
		this.dryRun = dryRun;
		this.json = json;
	}
}
