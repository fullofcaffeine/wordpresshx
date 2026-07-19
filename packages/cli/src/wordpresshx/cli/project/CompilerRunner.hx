package wordpresshx.cli.project;

import js.node.ChildProcess;
import js.node.ChildProcess.ChildProcessSpawnSyncResult;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.scaffold.ScaffoldProjection;

/** Direct, bounded Haxe typing for build/check; SDK-044 alone owns --wait. **/
class CompilerRunner {
	public static function typeProject(context:ProjectContext):Void {
		ScaffoldProjection.validate(context);
		validateBootstrap(context);
		run(context, [".wphx/bootstrap/project.hxml"]);
	}

	public static function typeProjectWithServer(context:ProjectContext, port:Int):Void {
		ScaffoldProjection.validate(context);
		validateBootstrap(context);
		run(context, ["--connect", Std.string(port), ".wphx/bootstrap/project.hxml"]);
	}

	public static function probeServer(context:ProjectContext, port:Int):Bool {
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync("haxe", ["--connect", Std.string(port), "-version"], {
			cwd: context.bootstrap.root,
			encoding: "utf8",
			timeout: 1000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		return result.error == null && result.status == 0;
	}

	static function validateBootstrap(context:ProjectContext):Void {
		final hxmlPath = ".wphx/bootstrap/project.hxml";
		final hxml = ProjectFiles.read(context.bootstrap.root, hxmlPath, "Haxe bootstrap").toString("utf8");
		if (hxml.split("\n").map(StringTools.trim).indexOf("--no-output") < 0) {
			throw new CliFailure("WPHX2000", "foundation project.hxml must use --no-output; emitters write only to private stages", 6, "haxe-typing-and-plan",
				hxmlPath, [
					"Regenerate .wphx/bootstrap/project.hxml with the exact CLI instead of adding a live output flag."
				]);
		}
	}

	static function run(context:ProjectContext, arguments:Array<String>):Void {
		final hxmlPath = ".wphx/bootstrap/project.hxml";
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync("haxe", arguments, {
			cwd: context.bootstrap.root,
			encoding: "utf8",
			timeout: 120000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		if (result.error != null) {
			throw new CliFailure("WPHX2001", "could not start the exact Haxe compiler", 6, "haxe-typing-and-plan", hxmlPath,
				["Run wphx doctor and restore the project-local Haxe/Lix installation."]);
		}
		if (result.status != 0) {
			final raw = Std.string(result.stderr);
			final redacted = StringTools.replace(raw, context.bootstrap.root + "/", "");
			final message = StringTools.trim(redacted).length == 0 ? "Haxe typing failed" : StringTools.trim(redacted);
			throw new CliFailure("WPHX2002", message, 6, "haxe-typing-and-plan", hxmlPath, ["Fix the reported Haxe source error and rerun the command."]);
		}
	}

	public static function version(command:String):Null<String> {
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync(command, ["--version"], {
			encoding: "utf8",
			timeout: 10000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		if (result.error != null || result.status != 0) {
			return null;
		}
		final stdout = StringTools.trim(Std.string(result.stdout));
		return stdout.length == 0 ? StringTools.trim(Std.string(result.stderr)) : stdout;
	}
}
