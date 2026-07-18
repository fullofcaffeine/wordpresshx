package wordpresshx.cli;

class CliInvocation {
	public final command:String;
	public final projectPath:Null<String>;
	public final profile:Null<String>;
	public final json:Bool;
	public final dryRun:Bool;
	public final services:Null<String>;
	public final positionals:Array<String>;

	public function new(command:String, projectPath:Null<String>, profile:Null<String>, json:Bool, dryRun:Bool, services:Null<String>,
			positionals:Array<String>) {
		this.command = command;
		this.projectPath = projectPath;
		this.profile = profile;
		this.json = json;
		this.dryRun = dryRun;
		this.services = services;
		this.positionals = positionals;
	}
}
