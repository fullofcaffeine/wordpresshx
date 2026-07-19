package wordpresshx.cli.scaffold;

enum ScaffoldMode {
	NewProject;
	ExistingProject;
}

class ScaffoldRequest {
	public final mode:ScaffoldMode;
	public final requestedProjectId:Null<String>;
	public final profile:String;
	public final projectPath:Null<String>;
	public final dryRun:Bool;
	public final json:Bool;

	public function new(mode:ScaffoldMode, requestedProjectId:Null<String>, profile:String, projectPath:Null<String>, dryRun:Bool, json:Bool) {
		this.mode = mode;
		this.requestedProjectId = requestedProjectId;
		this.profile = profile;
		this.projectPath = projectPath;
		this.dryRun = dryRun;
		this.json = json;
	}
}
