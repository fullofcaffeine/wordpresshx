package wordpresshx.cli.project;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliJson;

/** One complete, input-stable build transaction shared by bounded and watch commands. **/
class ProjectBuild {
	public static final STAGES = [
		"haxe-typing-and-plan",
		"php-emission",
		"browser-emission",
		"metadata-emission",
		"format-and-static-check",
		"asset-build",
		"artifact-validation",
		"ownership-publish"
	];

	public static function run(context:ProjectContext, events:CliEventStream, mode:String, buildId:String, compile:ProjectContext->Void, publish:Bool,
			dryRun:Bool, generation:Int):Null<ProjectBuildResult> {
		if (publish) {
			BuildPublisher.recover(context);
		}
		final diagnosis = Doctor.inspect(context);
		if (!diagnosis.passed) {
			throw new CliFailure("WPHX1200", "toolchain/ownership preflight failed; run wphx doctor for the exact mismatch", 7, "configuration", null, [
				"Restore the exact project-local tools and authenticated owned files reported by wphx doctor."
			]);
		}
		OwnershipPreflight.inspect(context);
		final stagePayload = () -> CliJson.object(["mode" => CliJson.text(mode), "buildId" => CliJson.text(buildId)]);
		events.stageStarted(STAGES[0], stagePayload());
		compile(context);
		events.stageCompleted(STAGES[0], stagePayload());
		final pluginPlan = PluginCompilationRegistry.get(context.bootstrap.root);
		if (pluginPlan != null) {
			return PluginProjectBuild.finish(context, pluginPlan, events, mode, buildId, publish, dryRun, generation);
		}
		events.stageSkipped(STAGES[1], "no PHP target producer is registered in the current build graph", mode);
		events.stageSkipped(STAGES[2], "no browser target producer is registered in the current build graph", mode);
		events.stageStarted(STAGES[3], stagePayload());
		final plannedManifest = BuildPublisher.plan(context);
		events.stageCompleted(STAGES[3], stagePayload());
		events.stageStarted(STAGES[4], stagePayload());
		events.stageCompleted(STAGES[4], stagePayload());
		events.stageSkipped(STAGES[5], "no asset target producer is registered in the current build graph", mode);
		events.stageStarted(STAGES[6], stagePayload());
		assertInputsStable(context);
		events.stageCompleted(STAGES[6], stagePayload());
		if (dryRun) {
			events.emit("dry-run-planned", STAGES[6], "passed", CliJson.object([
				"mode" => CliJson.text("dry-run"),
				"buildId" => CliJson.text(buildId),
				"fingerprint" => CliJson.text(context.fingerprint()),
				"reason" => CliJson.text("complete staged action plan validated; live tree unchanged")
			]));
			events.stageSkipped(STAGES[7], "dry-run has no publication authority", "dry-run");
			return null;
		}
		if (!publish) {
			events.stageSkipped(STAGES[7], "check validates the complete stage without publication authority", mode);
			return null;
		}
		events.stageStarted(STAGES[7], stagePayload());
		final publication = BuildPublisher.publish(context);
		final manifestDigest = ProjectContract.string(publication.manifest, "manifestDigest", "published ownership manifest");
		events.stageCompleted(STAGES[7], CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"reason" => CliJson.text(publication.outcome)
		]));
		events.emit("build-published", STAGES[7], "passed", CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"fingerprint" => CliJson.text(context.fingerprint()),
			"generation" => CliJson.number(generation),
			"manifestDigest" => CliJson.text(manifestDigest)
		]));
		return {manifestDigest: manifestDigest, outcome: publication.outcome};
	}

	static function assertInputsStable(context:ProjectContext):Void {
		final latest = ProjectLoader.resolve(ProjectLoader.discover(context.bootstrap.root), context.profileId());
		if (latest.fingerprint() != context.fingerprint()) {
			throw new CliFailure("WPHX2200", "effective inputs changed while the build was running", 5, "artifact-validation", null, [
				"Save the remaining edits; wphx dev will coalesce them into the next complete generation."
			]);
		}
	}
}
