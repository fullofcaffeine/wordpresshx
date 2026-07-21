package wordpresshx.cli.project;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliInvocation;
import wordpresshx.cli.CliJson;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;

/** Stable bounded commands plus the long-running development entry. **/
class ProjectCommands {
	public static function run(invocation:CliInvocation):Int {
		final events = new CliEventStream(invocation.command, invocation.json);
		var profile = "unresolved";
		try {
			events.emit("command-started", "command", "started", CliJson.object([]));
			final start = invocation.projectPath == null ? NodeGlobals.process().cwd() : invocation.projectPath;
			events.stageStarted("configuration", CliJson.object([]));
			final bootstrap = ProjectLoader.discover(start);
			profile = ProjectContract.string(ProjectContract.fieldObject(bootstrap.config, "profile", "project configuration"), "id", "project profile");
			events.stageCompleted("configuration", CliJson.object([]));
			events.stageStarted("profile-resolution", CliJson.object([]));
			final context = ProjectLoader.resolve(bootstrap, invocation.profile);
			profile = context.profileId();
			events.stageCompleted("profile-resolution", CliJson.object(["fingerprint" => CliJson.text(context.fingerprint())]));

			if (invocation.command == "dev") {
				DevEngine.start(context, invocation, events);
				return 0;
			}

			final exitCode = switch (invocation.command) {
				case "build": runBuild(context, invocation, events, false);
				case "check": runBuild(context, invocation, events, true);
				case "inspect":
					OwnershipPreflight.inspect(context);
					Inspector.run(context, invocation.positionals, invocation.json);
					0;
				case "clean": runClean(context, events);
				case "doctor": runDoctor(context, invocation.json);
				case _:
					throw new CliFailure("WPHX0001", "unsupported command", 2, "command");
			};
			events.emit("command-completed", "command", exitCode == 0 ? "passed" : "failed", CliJson.object([
				"exitCode" => CliJson.number(exitCode),
				"reason" => CliJson.text(exitCode == 0 ? invocation.command + " completed" : invocation.command + " reported mismatches")
			]));
			return exitCode;
		} catch (failure:CliFailure) {
			events.failure(failure, profile);
			return failure.exitCode;
		}
	}

	static function runBuild(context:ProjectContext, invocation:CliInvocation, events:CliEventStream, check:Bool):Int {
		final dryRun = invocation.dryRun;
		final mode = dryRun ? "dry-run" : "initial";
		final buildId = (dryRun ? "dry-run/" : check ? "check/" : "build/") + context.fingerprint().substr(0, 16);
		ProjectBuild.run(context, events, mode, buildId, CompilerRunner.typeProject, !check && !dryRun, dryRun, 1);
		return 0;
	}

	static function runClean(context:ProjectContext, events:CliEventStream):Int {
		events.stageStarted("ownership-publish", CliJson.object([]));
		final outcome = BuildPublisher.clean(context);
		events.stageCompleted("ownership-publish", CliJson.object(["reason" => CliJson.text(outcome)]));
		return 0;
	}

	static function runDoctor(context:ProjectContext, json:Bool):Int {
		final result = Doctor.inspect(context);
		if (json) {
			NodeGlobals.process().stdout.write(OwnershipJson.encode(result.report) + "\n");
		} else {
			NodeGlobals.process().stdout.write("Doctor: " + result.status + "\n");
			for (check in result.checks) {
				final marker = check.status == "passed" ? "✓" : "✗";
				NodeGlobals.process().stdout.write("  " + marker + " " + check.id + ": " + check.actual + "\n");
				if (marker == "✗") {
					NodeGlobals.process().stdout.write("    fix: " + check.remediation + "\n");
				}
			}
		}
		return result.passed ? 0 : 7;
	}
}
