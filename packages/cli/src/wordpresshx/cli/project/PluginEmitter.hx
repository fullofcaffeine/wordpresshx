package wordpresshx.cli.project;

import js.node.Buffer;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.Wp70PhpProfile;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Adapt the compile-time declaration to the existing structured PHP profile. */
class PluginEmitter {
	static final FORBIDDEN_OUTPUT = ["RawPhp", "PhpSegment", "HaxeBoot", "haxe.root"];

	public static function emit(context:ProjectContext, plan:PluginPlan):PluginEmission {
		final header = new PluginHeader(plan.name, plan.description, plan.version, "7.0", "7.4", plan.author, plan.license, plan.slug);
		final bootstrap = new PluginBootstrapPlan(plan.slug, header, PhpQualifiedName.relative(plan.namespace),
			PhpSourceRange.at(plan.sourcePath, plan.startLine, plan.startColumn, plan.endLine, plan.endColumn));
		final privateRuntime = plan.privateTitleFilter == null ? null : PluginPrivateRuntimeCompiler.compile(context, plan, plan.privateTitleFilter);
		final files = if (privateRuntime == null) {
			final artifact = new Wp70PhpProfile().emitPlugin(bootstrap);
				[
					for (file in artifact.files)
						new PluginEmittedFile(PublicNative, file.role, file.path, file.source)
				];
		} else {
			PluginPrivatePhpProfile.emit(plan, privateRuntime).concat(privateRuntime.files);
		};
		validate(files, plan, privateRuntime);
		final planBytes = Buffer.from(ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.plugin-plan.v2")),
			ScaffoldJson.field("kind", ScaffoldJson.text("plugin")),
			ScaffoldJson.field("slug", ScaffoldJson.text(plan.slug)),
			ScaffoldJson.field("profile", ScaffoldJson.text(plan.profile)),
			ScaffoldJson.field("name", ScaffoldJson.text(plan.name)),
			ScaffoldJson.field("description", ScaffoldJson.text(plan.description)),
			ScaffoldJson.field("version", ScaffoldJson.text(plan.version)),
			ScaffoldJson.field("author", ScaffoldJson.text(plan.author)),
			ScaffoldJson.field("license", ScaffoldJson.text(plan.license)),
			ScaffoldJson.field("namespace", ScaffoldJson.text(plan.namespace)),
			ScaffoldJson.field("privateTitleFilter", titleFilterValue(plan.privateTitleFilter)),
			ScaffoldJson.field("source", ScaffoldJson.object([
				ScaffoldJson.field("path", ScaffoldJson.text(plan.sourcePath)),
				ScaffoldJson.field("startLine", ScaffoldJson.number(plan.startLine)),
				ScaffoldJson.field("startColumn", ScaffoldJson.number(plan.startColumn)),
				ScaffoldJson.field("endLine", ScaffoldJson.number(plan.endLine)),
				ScaffoldJson.field("endColumn", ScaffoldJson.number(plan.endColumn))
			]))
		]), false), "utf8");
		final resultBytes = Buffer.from(ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.plugin-emission.v2")),
			ScaffoldJson.field("emitter", ScaffoldJson.text("wordpress-hx.wp70-public-php")),
			ScaffoldJson.field("profile", ScaffoldJson.text(plan.profile)),
			ScaffoldJson.field("plugin", ScaffoldJson.text(plan.slug)),
			ScaffoldJson.field("privateRuntime", privateRuntimeValue(privateRuntime)),
			ScaffoldJson.field("rawPhpSegments", ScaffoldJson.number(0)),
			ScaffoldJson.field("stockHaxePhpFiles", ScaffoldJson.number(countLane(files, PrivateRuntime))),
			ScaffoldJson.field("runtimeHxxDependency", ScaffoldJson.boolean(false)),
			ScaffoldJson.field("files", ScaffoldJson.array([
				for (file in files)
					ScaffoldJson.object([
						ScaffoldJson.field("lane", ScaffoldJson.text(file.lane.label())),
						ScaffoldJson.field("role", ScaffoldJson.text(file.role)),
						ScaffoldJson.field("path", ScaffoldJson.text(file.relativePath)),
						ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256)),
						ScaffoldJson.field("sizeBytes", ScaffoldJson.number(file.bytes.length))
					])
			]))
		]), false), "utf8");
		return new PluginEmission(plan, files, planBytes, resultBytes);
	}

	static function titleFilterValue(callback:Null<PluginPrivateTitleFilter>):JsonValue {
		if (callback == null) {
			return NullValue;
		}
		return ScaffoldJson.object([
			ScaffoldJson.field("className", ScaffoldJson.text(callback.className)),
			ScaffoldJson.field("methodName", ScaffoldJson.text(callback.methodName)),
			ScaffoldJson.field("source", ScaffoldJson.object([
				ScaffoldJson.field("path", ScaffoldJson.text(callback.sourcePath)),
				ScaffoldJson.field("startLine", ScaffoldJson.number(callback.startLine)),
				ScaffoldJson.field("startColumn", ScaffoldJson.number(callback.startColumn)),
				ScaffoldJson.field("endLine", ScaffoldJson.number(callback.endLine)),
				ScaffoldJson.field("endColumn", ScaffoldJson.number(callback.endColumn))
			]))
		]);
	}

	static function privateRuntimeValue(runtime:Null<PluginPrivateRuntime>):JsonValue {
		if (runtime == null) {
			return NullValue;
		}
		return ScaffoldJson.object([
			ScaffoldJson.field("classmapEntries", ScaffoldJson.number(runtime.classmapEntries)),
			ScaffoldJson.field("derivationSha256", ScaffoldJson.text(runtime.identity.derivationSha256)),
			ScaffoldJson.field("polyfillSha256", ScaffoldJson.text(runtime.polyfillSha256)),
			ScaffoldJson.field("prefix", ScaffoldJson.text(runtime.identity.prefix)),
			ScaffoldJson.field("privateClass", ScaffoldJson.text(runtime.privateClass)),
			ScaffoldJson.field("privatePhpBytes", ScaffoldJson.number(runtime.privatePhpBytes)),
			ScaffoldJson.field("privatePhpFileCount", ScaffoldJson.number(runtime.privatePhpFileCount)),
			ScaffoldJson.field("stockFrontPackaged", ScaffoldJson.boolean(false)),
			ScaffoldJson.field("stockFrontSha256", ScaffoldJson.text(runtime.stockFrontSha256))
		]);
	}

	static function validate(files:Array<PluginEmittedFile>, plan:PluginPlan, runtime:Null<PluginPrivateRuntime>):Void {
		final expected = runtime == null ? [plan.slug + ".php", "includes/Bootstrap.php", "includes/autoload.php"] : [
			plan.slug + ".php",
			"includes/Bootstrap.php",
			"includes/PrivateBridge.php",
			"includes/autoload.php",
			"includes/register-adapters.php"
		];
		final actual = [for (file in files) if (file.lane == PublicNative) file.relativePath];
		actual.sort(compareText);
		expected.sort(compareText);
		if (actual.join("\n") != expected.join("\n")) {
			invalid("structured public plugin file inventory differs");
		}
		final paths = new Map<String, Bool>();
		var packagePhpBytes = 0;
		for (file in files) {
			if (paths.exists(file.relativePath)) {
				invalid("generated plugin file path is duplicated: " + file.relativePath);
			}
			paths.set(file.relativePath, true);
			if (StringTools.endsWith(file.relativePath, ".php")) {
				packagePhpBytes += file.bytes.length;
				if (!StringTools.startsWith(file.bytes.toString("utf8"), "<?php\n")) {
					invalid("generated plugin file is not ordinary PHP: " + file.relativePath);
				}
			} else if (file.lane != PrivateManifest || !StringTools.startsWith(file.bytes.toString("utf8"), "{")) {
				invalid("generated plugin non-PHP file is outside the private manifest contract: " + file.relativePath);
			}
			if (file.lane == PublicNative) {
				for (marker in FORBIDDEN_OUTPUT) {
					if (file.bytes.toString("utf8").indexOf(marker) >= 0) {
						invalid("public plugin file leaked a forbidden runtime/compiler marker");
					}
				}
				validatePublicAbi(file);
			}
			for (forbidden in ["stock-front.php", "composer.json", "composer.lock", "/vendor/"]) {
				if (file.relativePath.indexOf(forbidden) >= 0) {
					invalid("generated plugin retained a forbidden private package path: " + forbidden);
				}
			}
		}
		if (packagePhpBytes > 409600) {
			invalid("generated server-only plugin exceeds the 400 KiB PHP/runtime ceiling");
		}
		if (runtime == null && files.length != 3) {
			invalid("plugin without private behavior must contain exactly three PHP files");
		}
		if (runtime != null
			&& (countLane(files, PrivateClassmap) != 1
				|| countLane(files, PrivateManifest) != 1
				|| countLane(files, PrivateRuntime) < 1)) {
			invalid("private plugin package omitted its runtime, class map, or inventory");
		}
	}

	static function validatePublicAbi(file:PluginEmittedFile):Void {
		for (line in file.bytes.toString("utf8").split("\n")) {
			final signature = line.indexOf("function ") >= 0
				|| StringTools.startsWith(StringTools.trim(line), "class ")
				|| StringTools.startsWith(StringTools.trim(line), "namespace ");
			if (signature && line.indexOf("wphx_internal") >= 0) {
				invalid("private compiler type crossed a public PHP signature");
			}
		}
	}

	static function countLane(files:Array<PluginEmittedFile>, lane:PluginArtifactLane):Int {
		var count = 0;
		for (file in files) {
			if (file.lane == lane) {
				count++;
			}
		}
		return count;
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
