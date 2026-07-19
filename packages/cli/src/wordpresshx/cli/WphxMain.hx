package wordpresshx.cli;

import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.generatedoutput.GeneratedOutputCommands;
import wordpresshx.cli.project.ProjectCommands;
import wordpresshx.cli.scaffold.ScaffoldCommands;

/** Haxe-authored WordPressHx CLI entry point, emitted as Node ESM by Genes. **/
class WphxMain {
	static function main():Void {
		final nodeProcess = NodeGlobals.process();
		final arguments = nodeProcess.argv.slice(2);
		if (arguments.length == 1 && (arguments[0] == "--help" || arguments[0] == "help")) {
			help();
			return;
		}
		if (arguments.length == 1 && arguments[0] == "--version") {
			nodeProcess.stdout.write("0.0.0\n");
			return;
		}
		if (arguments.length > 0 && arguments[0] == "trace") {
			try {
				TraceCommand.run(arguments);
			} catch (failure:TraceFailure) {
				nodeProcess.stderr.write("wphx: " + failure.message + "\n");
				nodeProcess.exit(failure.exitCode);
			} catch (_:haxe.Exception) {
				nodeProcess.stderr.write("wphx: unexpected trace failure\n");
				nodeProcess.exit(70);
			}
			return;
		}
		try {
			if (arguments.length > 0 && arguments[0] == "generated-output") {
				final status = GeneratedOutputCommands.run(arguments);
				if (status != 0) {
					nodeProcess.exit(status);
				}
				return;
			}
			if (arguments.length > 0 && (arguments[0] == "new" || arguments[0] == "init")) {
				final status = ScaffoldCommands.run(arguments);
				if (status != 0) {
					nodeProcess.exit(status);
				}
				return;
			}
			final invocation = CliArguments.parse(arguments);
			final status = ProjectCommands.run(invocation);
			if (status != 0) {
				nodeProcess.exit(status);
			}
		} catch (failure:CliFailure) {
			standaloneFailure(failure, arguments.indexOf("--json") >= 0);
			nodeProcess.exit(failure.exitCode);
		} catch (_:haxe.Exception) {
			final diagnostic = new CliFailure("WPHX9000", "unexpected internal CLI failure", 70, "command", null, [
				"Rerun with the exact locked CLI; if reproducible, report the command without secrets."
			]);
			standaloneFailure(diagnostic, arguments.indexOf("--json") >= 0);
			nodeProcess.exit(70);
		}
	}

	static function standaloneFailure(failure:CliFailure, json:Bool):Void {
		if (json) {
			NodeGlobals.process().stderr.write(OwnershipJson.encode(OwnershipJson.object([
				"schema" => "wordpress-hx.cli-diagnostic.v1",
				"code" => failure.code,
				"exitCode" => failure.exitCode,
				"stage" => failure.stage,
				"message" => failure.message,
				"path" => failure.relativePath,
				"remediations" => failure.remediations
			])) + "\n");
			return;
		}
		NodeGlobals.process().stderr.write("wphx " + failure.code + " [" + failure.stage + "]: " + failure.message + "\n");
		for (remediation in failure.remediations) {
			NodeGlobals.process().stderr.write("  fix: " + remediation + "\n");
		}
	}

	static function help():Void {
		NodeGlobals.process()
			.stdout.write('WordPressHx CLI 0.0.0\n\n'
				+ 'Usage: wphx <command> [options]\n\n'
				+ '  new site <name>    Create a minimal Haxe-owned site project\n'
				+ '  new plugin <name>  Create a Haxe-owned native plugin project\n'
				+ '  init [name]        Initialize the current existing directory\n'
				+ '  build [--dry-run]  Type, validate, and atomically publish\n'
				+ '  check              Run the complete no-publication gate\n'
				+ '  inspect            Explain project, inputs, build, or provenance\n'
				+ '  clean              Remove only exact manifest-owned files\n'
				+ '  doctor             Diagnose exact pins without mutation\n'
				+ '  dev                One-command development loop (SDK-044 engine)\n'
				+ '  generated-output   Explicit per-root Git deployment policy\n'
				+ '  trace              Correlate PHP or browser stacks to Haxe\n\n'
				+ 'Options: --project <path> --profile <id> --json\n');
	}
}
