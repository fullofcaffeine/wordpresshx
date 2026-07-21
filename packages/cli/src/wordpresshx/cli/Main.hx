package wordpresshx.cli;

/** Frozen SDK-025 trace-only entry retained as a compatibility alias. */
class Main {
	static function main():Void {
		final nodeProcess = NodeGlobals.process();
		try {
			TraceCommand.run(nodeProcess.argv.slice(2), "wphx-sdk");
		} catch (failure:TraceFailure) {
			nodeProcess.stderr.write("wphx-sdk: " + failure.message + "\n");
			nodeProcess.exit(failure.exitCode);
		} catch (_:haxe.Exception) {
			nodeProcess.stderr.write("wphx-sdk: unexpected trace failure\n");
			nodeProcess.exit(3);
		}
	}
}
