package wordpresshx.cli.project;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliJson;

/** Complete stages after Haxe has collected one typed plugin definition. */
class PluginProjectBuild {
	public static function finish(context:ProjectContext, plan:PluginPlan, events:CliEventStream, mode:String, buildId:String, publish:Bool, dryRun:Bool,
			generation:Int):Null<ProjectBuildResult> {
		final payload = () -> CliJson.object(["mode" => CliJson.text(mode), "buildId" => CliJson.text(buildId)]);
		events.stageStarted(ProjectBuild.STAGES[1], payload());
		final emission = PluginEmitter.emit(context, plan);
		events.stageCompleted(ProjectBuild.STAGES[1], CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"reason" => CliJson.text("structured public PHP bootstrap emitted from the typed plugin plan")
		]));
		events.stageSkipped(ProjectBuild.STAGES[2], "plugin bootstrap declares no browser target", mode);
		events.stageStarted(ProjectBuild.STAGES[3], payload());
		PluginBuildPublisher.plan(context, emission);
		events.stageCompleted(ProjectBuild.STAGES[3], payload());
		events.stageStarted(ProjectBuild.STAGES[4], payload());
		final quality = PluginPhpQuality.validate(context, emission);
		events.stageCompleted(ProjectBuild.STAGES[4], CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"reason" => CliJson.text("pinned lint, formatter, WPCS, compatibility, PHPStan, symbol, and autoload gates passed"),
			"policySha256" => CliJson.text(quality.policySha256),
			"reportSha256" => CliJson.text(quality.reportSha256)
		]));
		events.stageSkipped(ProjectBuild.STAGES[5], "plugin bootstrap declares no browser asset target", mode);
		events.stageStarted(ProjectBuild.STAGES[6], payload());
		assertInputsStable(context);
		events.stageCompleted(ProjectBuild.STAGES[6], payload());
		if (dryRun) {
			events.emit("dry-run-planned", ProjectBuild.STAGES[6], "passed", CliJson.object([
				"mode" => CliJson.text("dry-run"),
				"buildId" => CliJson.text(buildId),
				"fingerprint" => CliJson.text(context.fingerprint()),
				"reason" => CliJson.text("complete plugin generation validated in memory; live tree unchanged")
			]));
			events.stageSkipped(ProjectBuild.STAGES[7], "dry-run has no publication authority", "dry-run");
			return null;
		}
		if (!publish) {
			events.stageSkipped(ProjectBuild.STAGES[7], "check validates the complete plugin generation without publication authority", mode);
			return null;
		}
		events.stageStarted(ProjectBuild.STAGES[7], payload());
		final publication = PluginBuildPublisher.publish(context, emission, quality);
		events.stageCompleted(ProjectBuild.STAGES[7], CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"reason" => CliJson.text(publication.outcome)
		]));
		events.emit("build-published", ProjectBuild.STAGES[7], "passed", CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"fingerprint" => CliJson.text(context.fingerprint()),
			"generation" => CliJson.number(generation),
			"manifestDigest" => CliJson.text(publication.manifestDigest)
		]));
		return publication;
	}

	static function assertInputsStable(context:ProjectContext):Void {
		final latest = ProjectLoader.resolve(ProjectLoader.discover(context.bootstrap.root), context.profileId());
		if (latest.fingerprint() != context.fingerprint()) {
			throw new wordpresshx.cli.CliFailure("WPHX2200", "effective inputs changed while the plugin build was running", 5, "artifact-validation", null, [
				"Save the remaining edits; wphx dev will coalesce them into the next complete generation."
			]);
		}
	}
}
