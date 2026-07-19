package wordpresshx.cli.generatedoutput;

import js.node.ChildProcess;
import js.node.ChildProcess.ChildProcessSpawnSyncResult;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.NodeGlobals;

/** Re-enter the exact running CLI without a shell or ambient resolution. */
class GeneratedOutputProcess {
	public static function build(projectRoot:String, publish:Bool):Void {
		final nodeProcess = NodeGlobals.process();
		if (nodeProcess.argv.length < 2 || nodeProcess.argv[1].length == 0) {
			fail("running CLI entry point cannot be resolved");
		}
		final entry = Fs.realpathSync(Path.resolve(nodeProcess.cwd(), nodeProcess.argv[1]));
		final arguments = [entry, publish ? "build" : "check", "--project", projectRoot, "--json"];
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync(nodeProcess.execPath, arguments, {
			cwd: projectRoot,
			encoding: "utf8",
			timeout: 300000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		if (result.error != null || result.status != 0) {
			fail(publish ? "exact generated-output build failed" : "exact generated-output check failed");
		}
	}

	static function fail<T>(message:String):T {
		throw new CliFailure("WPHX3418", message, 6, "generated-output-regeneration", "wordpress-hx.json", [
			"Run the ordinary exact wphx check/build command, resolve its diagnostic, then retry."
		]);
	}
}
