package wordpresshx.cli.project;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.ownership.OwnershipJson;

/** Complete stages after Haxe has collected one typed plugin definition. */
class PluginProjectBuild {
	public static function finish(context:ProjectContext, plan:PluginPlan, events:CliEventStream, mode:String, buildId:String, publish:Bool, dryRun:Bool,
			generation:Int):Null<ProjectBuildResult> {
		final payload = () -> OwnershipJson.object(["mode" => mode, "buildId" => buildId]);
		events.stageStarted(ProjectBuild.STAGES[1], payload());
		final emission = PluginEmitter.emit(plan);
		events.stageCompleted(ProjectBuild.STAGES[1], OwnershipJson.object([
			"mode" => mode,
			"buildId" => buildId,
			"reason" => "structured public PHP bootstrap emitted from the typed plugin plan"
		]));
		events.stageSkipped(ProjectBuild.STAGES[2], "plugin bootstrap declares no browser target", mode);
		events.stageStarted(ProjectBuild.STAGES[3], payload());
		PluginBuildPublisher.plan(context, emission);
		events.stageCompleted(ProjectBuild.STAGES[3], payload());
		events.stageStarted(ProjectBuild.STAGES[4], payload());
		events.stageCompleted(ProjectBuild.STAGES[4], OwnershipJson.object([
			"mode" => mode,
			"buildId" => buildId,
			"reason" => "closed PHP IR and target-shape validators passed; WPCS/static analysis remains SDK-026"
		]));
		events.stageSkipped(ProjectBuild.STAGES[5], "plugin bootstrap declares no browser asset target", mode);
		events.stageStarted(ProjectBuild.STAGES[6], payload());
		assertInputsStable(context);
		events.stageCompleted(ProjectBuild.STAGES[6], payload());
		if (dryRun) {
			events.emit("dry-run-planned", ProjectBuild.STAGES[6], "passed", OwnershipJson.object([
				"mode" => "dry-run",
				"buildId" => buildId,
				"fingerprint" => context.fingerprint(),
				"reason" => "complete plugin generation validated in memory; live tree unchanged"
			]));
			events.stageSkipped(ProjectBuild.STAGES[7], "dry-run has no publication authority", "dry-run");
			return null;
		}
		if (!publish) {
			events.stageSkipped(ProjectBuild.STAGES[7], "check validates the complete plugin generation without publication authority", mode);
			return null;
		}
		events.stageStarted(ProjectBuild.STAGES[7], payload());
		final publication = PluginBuildPublisher.publish(context, emission);
		events.stageCompleted(ProjectBuild.STAGES[7], OwnershipJson.object(["mode" => mode, "buildId" => buildId, "reason" => publication.outcome]));
		events.emit("build-published", ProjectBuild.STAGES[7], "passed", OwnershipJson.object([
			"mode" => mode,
			"buildId" => buildId,
			"fingerprint" => context.fingerprint(),
			"generation" => generation,
			"manifestDigest" => publication.manifestDigest
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
