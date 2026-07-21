package wordpresshx.cli.project;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;

/** Project, input, build, and exact artifact-provenance inspection. **/
class Inspector {
	public static function run(context:ProjectContext, arguments:Array<String>, json:Bool):Void {
		final topic = arguments.length == 0 ? "project" : arguments[0];
		final document:JsonValue = switch (topic) {
			case "project" if (arguments.length == 0 || arguments.length == 1): project(context);
			case "inputs" if (arguments.length == 1): context.effectiveInputs;
			case "build" if (arguments.length == 1): build(context);
			case "provenance" if (arguments.length == 2): provenance(context, arguments[1]);
			case _:
				throw new CliFailure("WPHX0002", "inspect expects project, inputs, build, or provenance <generated-path>", 2, "command", null,
					["Use wphx inspect inputs or wphx inspect provenance <project-relative-path>."]);
		};
		if (json) {
			NodeGlobals.process().stdout.write(OwnershipJson.encode(document) + "\n");
			return;
		}
		renderHuman(topic, document);
	}

	static function project(context:ProjectContext):JsonValue {
		return OwnershipJson.object([
			"schema" => "wordpress-hx.inspect-project.v1",
			"projectId" => ProjectContract.string(context.bootstrap.config, "projectId", "project configuration"),
			"entryPoint" => ProjectContract.string(context.bootstrap.config, "entryPoint", "project configuration"),
			"profile" => context.profileId(),
			"fingerprint" => context.fingerprint(),
			"sourceRoots" => context.bootstrap.sourceRoots,
			"testRoots" => context.bootstrap.testRoots,
			"assetRoots" => context.bootstrap.assetRoots,
			"outputRoots" => [
				for (root in context.bootstrap.outputRoots)
					OwnershipJson.object(["id" => root.id, "path" => root.path])
			]
		]);
	}

	static function build(context:ProjectContext):JsonValue {
		final manifest = OwnershipPreflight.inspect(context);
		return OwnershipJson.object([
			"schema" => "wordpress-hx.inspect-build.v1",
			"fingerprint" => context.fingerprint(),
			"manifest" => manifest == null ? NullValue : manifest.json
		]);
	}

	static function provenance(context:ProjectContext, rawPath:String):JsonValue {
		final path = ProjectContract.relativePath(rawPath, "generated artifact path");
		final manifest = OwnershipPreflight.inspect(context);
		if (manifest == null) {
			throw new CliFailure("WPHX1040", "there is no published ownership manifest", 3, "ownership-publish", path,
				["Run wphx build before inspecting generated provenance."]);
		}
		for (file in manifest.files) {
			if (file.path == path) {
				return OwnershipJson.object([
					"schema" => "wordpress-hx.inspect-provenance.v1",
					"manifestDigest" => manifest.manifestDigest,
					"artifact" => file.json
				]);
			}
		}
		throw new CliFailure("WPHX1041", "path is not an exact current ownership entry", 3, "ownership-publish", path,
			["Use wphx inspect build to list current generated entries."]);
	}

	static function renderHuman(topic:String, document:JsonValue):Void {
		if (topic == "project") {
			NodeGlobals.process().stdout.write("Project " + ProjectContract.string(document, "projectId", "project inspection") + "\n");
			NodeGlobals.process().stdout.write("  entry: " + ProjectContract.string(document, "entryPoint", "project inspection") + "\n");
			NodeGlobals.process().stdout.write("  profile: " + ProjectContract.string(document, "profile", "project inspection") + "\n");
			NodeGlobals.process().stdout.write("  fingerprint: " + ProjectContract.string(document, "fingerprint", "project inspection") + "\n");
		} else if (topic == "inputs") {
			final files = ProjectContract.array(document, "files", "effective inputs");
			NodeGlobals.process()
				.stdout.write("Effective inputs "
					+ ProjectContract.string(document, "fingerprint", "effective inputs")
					+ " ("
					+ files.length
					+ " files)\n");
			for (file in files) {
				NodeGlobals.process()
					.stdout.write("  " + ProjectContract.string(file, "role", "effective input") + "  "
						+ ProjectContract.string(file, "path", "effective input") + "\n");
			}
		} else {
			NodeGlobals.process().stdout.write(OwnershipJson.encode(document) + "\n");
		}
	}
}
