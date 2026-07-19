package wordpresshx.cli.project.development;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.project.PluginEmitter;
import wordpresshx.cli.project.PluginPlan;
import wordpresshx.cli.project.ProjectContext;
import wordpresshx.cli.project.ProjectFiles;

/** Validated current native plugin generation available to a development provider. */
class DevelopmentPlugin {
	public final slug:String;
	public final relativeDirectory:String;
	public final entry:String;
	public final bootstrapClass:String;

	public static function from(context:ProjectContext, plan:PluginPlan):DevelopmentPlugin {
		var wordpressRoot:Null<String> = null;
		for (root in context.bootstrap.outputRoots) {
			if (root.id == "wordpress") {
				wordpressRoot = root.path;
			}
		}
		if (wordpressRoot == null) {
			return invalid("the typed plugin has no authenticated WordPress output root");
		}
		final relativeDirectory = wordpressRoot + "/" + plan.slug;
		ProjectFiles.requireDirectory(context.bootstrap.root, relativeDirectory, "generated development plugin", "service-start");
		final emission = PluginEmitter.emit(plan);
		final expectedFiles = [for (file in emission.files) relativeDirectory + "/" + file.relativePath];
		final actualFiles = ProjectFiles.discover(context.bootstrap.root, relativeDirectory, null, "generated development plugin");
		if (actualFiles.join("\n") != expectedFiles.join("\n")) {
			return invalid("the published plugin tree differs from the current typed emission");
		}
		for (index in 0...emission.files.length) {
			final actual = ProjectFiles.read(context.bootstrap.root, actualFiles[index], "generated development plugin file", "service-start");
			if (OwnershipJson.digest(actual) != OwnershipJson.digest(emission.files[index].bytes)) {
				return invalid("the published plugin bytes differ from the current typed emission");
			}
		}
		return new DevelopmentPlugin(plan.slug, relativeDirectory, plan.slug + "/" + plan.slug + ".php", plan.namespace + "\\Bootstrap");
	}

	function new(slug:String, relativeDirectory:String, entry:String, bootstrapClass:String) {
		this.slug = slug;
		this.relativeDirectory = relativeDirectory;
		this.entry = entry;
		this.bootstrapClass = bootstrapClass;
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX2332", "Could not derive a deployable development plugin: " + message, 7, "service-start", null, [
			"Run wphx build to restore the complete owned plugin generation, or use --services=none for compile/watch-only development."
		]);
	}
}
