package wordpresshx.cli.scaffold;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.project.ProjectBootstrap;
import wordpresshx.cli.project.ProjectContract;
import wordpresshx.cli.project.ProjectContext;
import wordpresshx.cli.project.ProjectFiles;

/** Derive CLI-owned pre-typing files from the authenticated project bootstrap. */
class ScaffoldProjection {
	public static function expectedHxml(bootstrap:ProjectBootstrap):String {
		final entryPoint = ProjectContract.string(bootstrap.config, "entryPoint", "project configuration");
		return hxml(entryPoint, bootstrap.sourceRoots, bootstrap.testRoots);
	}

	public static function hxml(entryPoint:String, sourceRoots:Array<String>, testRoots:Array<String>):String {
		final parts = entryPoint.split(".");
		parts.pop();
		final packageName = parts.join(".");
		final roots = sourceRoots.concat(testRoots);
		final lines = [for (root in roots) "-cp " + root];
		lines.push("--macro include('" + packageName + "')");
		lines.push("-D wordpress-hx");
		lines.push("--no-output");
		return lines.join("\n") + "\n";
	}

	public static function haxerc():String {
		return '{\n  "version": "4.3.7",\n  "resolveLibs": "scoped"\n}\n';
	}

	public static function validate(context:ProjectContext):Void {
		validateFile(context, ".wphx/bootstrap/project.hxml", expectedHxml(context.bootstrap), "Haxe bootstrap");
		validateFile(context, ".haxerc", haxerc(), "Haxe version projection");
	}

	static function validateFile(context:ProjectContext, relativePath:String, expected:String, label:String):Void {
		final actual = ProjectFiles.read(context.bootstrap.root, relativePath, label, "haxe-typing-and-plan").toString("utf8");
		if (actual != expected) {
			throw new CliFailure("WPHX3008", label + " differs from the Haxe-derived project projection", 5, "haxe-typing-and-plan", relativePath, [
				"Regenerate the scaffold projection with the exact CLI; do not hand-edit CLI-owned bootstrap files."
			]);
		}
	}
}
