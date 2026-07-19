package wordpresshx.cli.project;

import js.node.Buffer;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.Wp70PhpProfile;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Adapt the compile-time declaration to the existing structured PHP profile. */
class PluginEmitter {
	static final FORBIDDEN_OUTPUT = ["RawPhp", "PhpSegment", "HaxeBoot", "haxe.root"];

	public static function emit(plan:PluginPlan):PluginEmission {
		final header = new PluginHeader(plan.name, plan.description, plan.version, "7.0", "7.4", plan.author, plan.license, plan.slug);
		final bootstrap = new PluginBootstrapPlan(plan.slug, header, PhpQualifiedName.relative(plan.namespace),
			PhpSourceRange.at(plan.sourcePath, plan.startLine, plan.startColumn, plan.endLine, plan.endColumn));
		final artifact = new Wp70PhpProfile().emitPlugin(bootstrap);
		final files = [
			for (file in artifact.files)
				new PluginEmittedFile(file.role, file.path, file.source)
		];
		validate(files, plan.slug);
		final planBytes = Buffer.from(ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.plugin-plan.v1")),
			ScaffoldJson.field("kind", ScaffoldJson.text("plugin")),
			ScaffoldJson.field("slug", ScaffoldJson.text(plan.slug)),
			ScaffoldJson.field("profile", ScaffoldJson.text(plan.profile)),
			ScaffoldJson.field("name", ScaffoldJson.text(plan.name)),
			ScaffoldJson.field("description", ScaffoldJson.text(plan.description)),
			ScaffoldJson.field("version", ScaffoldJson.text(plan.version)),
			ScaffoldJson.field("author", ScaffoldJson.text(plan.author)),
			ScaffoldJson.field("license", ScaffoldJson.text(plan.license)),
			ScaffoldJson.field("namespace", ScaffoldJson.text(plan.namespace)),
			ScaffoldJson.field("source", ScaffoldJson.object([
				ScaffoldJson.field("path", ScaffoldJson.text(plan.sourcePath)),
				ScaffoldJson.field("startLine", ScaffoldJson.number(plan.startLine)),
				ScaffoldJson.field("startColumn", ScaffoldJson.number(plan.startColumn)),
				ScaffoldJson.field("endLine", ScaffoldJson.number(plan.endLine)),
				ScaffoldJson.field("endColumn", ScaffoldJson.number(plan.endColumn))
			]))
		]), false), "utf8");
		final resultBytes = Buffer.from(ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.plugin-emission.v1")),
			ScaffoldJson.field("emitter", ScaffoldJson.text("wordpress-hx.wp70-public-php")),
			ScaffoldJson.field("profile", ScaffoldJson.text(plan.profile)),
			ScaffoldJson.field("plugin", ScaffoldJson.text(plan.slug)),
			ScaffoldJson.field("rawPhpSegments", ScaffoldJson.number(0)),
			ScaffoldJson.field("stockHaxePhpFiles", ScaffoldJson.number(0)),
			ScaffoldJson.field("runtimeHxxDependency", ScaffoldJson.boolean(false)),
			ScaffoldJson.field("files", ScaffoldJson.array([
				for (file in files)
					ScaffoldJson.object([
						ScaffoldJson.field("role", ScaffoldJson.text(file.role)),
						ScaffoldJson.field("path", ScaffoldJson.text(file.relativePath)),
						ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256)),
						ScaffoldJson.field("sizeBytes", ScaffoldJson.number(file.bytes.length))
					])
			]))
		]), false), "utf8");
		return new PluginEmission(plan, files, planBytes, resultBytes);
	}

	static function validate(files:Array<PluginEmittedFile>, slug:String):Void {
		if (files.length != 3) {
			invalid("structured plugin bootstrap must contain exactly three PHP files");
		}
		final expected = [slug + ".php", "includes/Bootstrap.php", "includes/autoload.php"];
		final actual = [for (file in files) file.relativePath];
		actual.sort(compareText);
		expected.sort(compareText);
		if (actual.join("\n") != expected.join("\n")) {
			invalid("structured plugin bootstrap file inventory differs");
		}
		for (file in files) {
			if (!StringTools.startsWith(file.bytes.toString("utf8"), "<?php\n")) {
				invalid("generated plugin file is not ordinary PHP: " + file.relativePath);
			}
			for (marker in FORBIDDEN_OUTPUT) {
				if (file.bytes.toString("utf8").indexOf(marker) >= 0) {
					invalid("generated plugin file leaked a forbidden runtime/compiler marker");
				}
			}
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid(message:String):Void {
		throw new CliFailure("WPHX3304", message, 6, "php-emission", null, [
			"Report the typed plugin declaration and exact profile without publishing the partial artifact."
		]);
	}
}
