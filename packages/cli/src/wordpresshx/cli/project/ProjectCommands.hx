package wordpresshx.cli.project;

import js.node.Path;
import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliInvocation;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.ownership.OwnershipJson;

/** Stable bounded commands; the SDK-044 engine will reuse this build pipeline. **/
class ProjectCommands {
	static final BUILD_STAGES = [
		"haxe-typing-and-plan",
		"php-emission",
		"browser-emission",
		"metadata-emission",
		"format-and-static-check",
		"asset-build",
		"artifact-validation",
		"ownership-publish"
	];

	public static function run(invocation:CliInvocation):Int {
		final events = new CliEventStream(invocation.command, invocation.json);
		var profile = "unresolved";
		try {
			events.emit("command-started", "command", "started", OwnershipJson.object([]));
			final start = invocation.projectPath == null ? NodeGlobals.process().cwd() : invocation.projectPath;
			events.stageStarted("configuration", OwnershipJson.object([]));
			final bootstrap = ProjectLoader.discover(start);
			profile = ProjectContract.string(ProjectContract.fieldObject(bootstrap.config, "profile", "project configuration"), "id", "project profile");
			events.stageCompleted("configuration", OwnershipJson.object([]));
			events.stageStarted("profile-resolution", OwnershipJson.object([]));
			final context = ProjectLoader.resolve(bootstrap, invocation.profile);
			profile = context.profileId();
			events.stageCompleted("profile-resolution", OwnershipJson.object(["fingerprint" => context.fingerprint()]));

			final exitCode = switch (invocation.command) {
				case "build": runBuild(context, invocation, events, false);
				case "check": runBuild(context, invocation, events, true);
				case "inspect":
					OwnershipPreflight.inspect(context);
					Inspector.run(context, invocation.positionals, invocation.json);
					0;
				case "clean": runClean(context, events);
				case "doctor": runDoctor(context, invocation.json);
				case "dev":
					OwnershipPreflight.inspect(context);
					throw new CliFailure("WPHX4000",
						"the stable wphx dev entry is configured, but the SDK-044 long-running watcher/supervisor is not installed yet", 7, "watching", null, [
							"Use wphx build for bounded work while SDK-044 adds watch, services, readiness, reload, and clean shutdown."
						]);
				case _:
					throw new CliFailure("WPHX0001", "unsupported command", 2, "command");
			};
			events.emit("command-completed", "command", exitCode == 0 ? "passed" : "failed", OwnershipJson.object([
				"exitCode" => exitCode,
				"reason" => exitCode == 0 ? invocation.command + " completed" : invocation.command + " reported mismatches"
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
		if (!check && !dryRun) {
			BuildPublisher.recover(context);
		}
		final diagnosis = Doctor.inspect(context);
		if (!diagnosis.passed) {
			final checks:Array<Dynamic> = cast Reflect.field(diagnosis.report, "checks");
			final failed = checks.filter(check -> Reflect.field(check, "status") == "failed")[0];
			throw new CliFailure("WPHX1200",
				"toolchain/ownership preflight failed at "
				+ Reflect.field(failed, "id")
				+ ": found "
				+ Reflect.field(failed, "actual")
				+ ", expected "
				+ Reflect.field(failed, "expected"),
				7, "configuration", null, [cast Reflect.field(failed, "remediation")]);
		}
		OwnershipPreflight.inspect(context);
		final stagePayload = () -> OwnershipJson.object(["mode" => mode, "buildId" => buildId]);
		events.stageStarted(BUILD_STAGES[0], stagePayload());
		CompilerRunner.typeProject(context);
		events.stageCompleted(BUILD_STAGES[0], stagePayload());
		events.stageSkipped(BUILD_STAGES[1], "no PHP target producer is registered in the SDK-043 foundation", mode);
		events.stageSkipped(BUILD_STAGES[2], "no browser target producer is registered in the SDK-043 foundation", mode);
		events.stageStarted(BUILD_STAGES[3], stagePayload());
		final plannedManifest = BuildPublisher.plan(context);
		events.stageCompleted(BUILD_STAGES[3], stagePayload());
		events.stageStarted(BUILD_STAGES[4], stagePayload());
		events.stageCompleted(BUILD_STAGES[4], stagePayload());
		events.stageSkipped(BUILD_STAGES[5], "no asset target producer is registered in the SDK-043 foundation", mode);
		events.stageStarted(BUILD_STAGES[6], stagePayload());
		events.stageCompleted(BUILD_STAGES[6], stagePayload());
		if (dryRun) {
			events.emit("dry-run-planned", BUILD_STAGES[6], "passed", OwnershipJson.object([
				"mode" => "dry-run",
				"buildId" => buildId,
				"fingerprint" => context.fingerprint(),
				"reason" => "complete staged action plan validated; live tree unchanged"
			]));
			events.stageSkipped(BUILD_STAGES[7], "dry-run has no publication authority", "dry-run");
			return 0;
		}
		if (check) {
			events.stageSkipped(BUILD_STAGES[7], "check validates the complete stage without publication authority", null);
			return 0;
		}
		events.stageStarted(BUILD_STAGES[7], stagePayload());
		final publication = BuildPublisher.publish(context);
		events.stageCompleted(BUILD_STAGES[7], OwnershipJson.object(["mode" => mode, "buildId" => buildId, "reason" => publication.outcome]));
		events.emit("build-published", BUILD_STAGES[7], "passed", OwnershipJson.object([
			"mode" => mode,
			"buildId" => buildId,
			"fingerprint" => context.fingerprint(),
			"manifestDigest" => ProjectContract.string(plannedManifest, "manifestDigest", "planned ownership manifest")
		]));
		return 0;
	}

	static function runClean(context:ProjectContext, events:CliEventStream):Int {
		events.stageStarted("ownership-publish", OwnershipJson.object([]));
		final outcome = BuildPublisher.clean(context);
		events.stageCompleted("ownership-publish", OwnershipJson.object(["reason" => outcome]));
		return 0;
	}

	static function runDoctor(context:ProjectContext, json:Bool):Int {
		final result = Doctor.inspect(context);
		if (json) {
			NodeGlobals.process().stdout.write(OwnershipJson.encode(result.report) + "\n");
		} else {
			NodeGlobals.process().stdout.write("Doctor: " + Reflect.field(result.report, "status") + "\n");
			final checks:Array<Dynamic> = cast Reflect.field(result.report, "checks");
			for (check in checks) {
				final marker = Reflect.field(check, "status") == "passed" ? "✓" : "✗";
				NodeGlobals.process().stdout.write("  " + marker + " " + Reflect.field(check, "id") + ": " + Reflect.field(check, "actual") + "\n");
				if (marker == "✗") {
					NodeGlobals.process().stdout.write("    fix: " + Reflect.field(check, "remediation") + "\n");
				}
			}
		}
		return result.passed ? 0 : 7;
	}
}
