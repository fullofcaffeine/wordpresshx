package wordpresshx.cli.scaffold;

/** User-facing project creation commands backed by a complete typed plan. */
class ScaffoldCommands {
	public static function run(arguments:Array<String>):Int {
		final request = ScaffoldArguments.parse(arguments);
		final plan = ScaffoldRenderer.plan(request, NodeGlobals.process().cwd());
		ScaffoldPublisher.preflight(plan);
		if (!request.dryRun) {
			ScaffoldPublisher.publish(plan);
		}
		if (request.json) {
			NodeGlobals.process().stdout.write(ScaffoldJson.document(plan.json(request.dryRun, !request.dryRun), false));
		} else {
			writeHuman(plan, request.dryRun);
		}
		return 0;
	}

	static function writeHuman(plan:ScaffoldPlan, dryRun:Bool):Void {
		final output = NodeGlobals.process().stdout;
		output.write("wphx " + plan.operation() + " " + plan.projectId + " [" + plan.profile + "]\n");
		for (file in plan.files) {
			output.write("  " + file.actionLabel() + " " + file.ownership.label() + " mode=" + file.mode + " sha256=" + file.sha256() + " bytes="
				+ file.sizeBytes() + " " + file.relativePath + "\n");
		}
		for (limitation in plan.limitations()) {
			output.write("  limitation " + limitation + "\n");
		}
		output.write(dryRun ? "planned only; no files written\n" : "published complete scaffold\n");
	}
}
