package wordpresshx.cli.generatedoutput;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonDocument;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.project.OwnershipPreflight;
import wordpresshx.cli.project.ProjectFiles;

/** Typed evidence extracted after the complete ADR-007 validator passes. */
class GeneratedOutputManifest {
	public final path:String;
	public final manifestDigest:String;
	public final sourceFingerprint:String;
	public final generatorId:String;
	public final toolchainDigest:String;
	public final profileId:String;
	public final catalogRevision:String;
	public final catalogSha256:String;
	public final generatedPaths:Array<String>;

	public static function inspect(project:GeneratedOutputProject, roots:Array<GeneratedOutputRoot>, completeOwnedTree:Bool):GeneratedOutputManifest {
		if (completeOwnedTree) {
			OwnershipPreflight.inspect(project.context);
		}
		final manifestPath = project.metadataRoot.path + "/_GeneratedFiles.json";
		try {
			final value = JsonDocument.parseCanonical(ProjectFiles.read(project.context.bootstrap.root, manifestPath, "ownership manifest",
				"generated-output-provenance"), manifestPath, "WPHX3416");
			final root = JsonReader.from(value, "ownership manifest", "WPHX3416");
			root.exact([
				"schema",
				"canonicalization",
				"transactionProtocol",
				"manifestDigestAlgorithm",
				"manifestDigest",
				"locations",
				"generator",
				"inputs",
				"outputRoots",
				"validators",
				"files"
			], "WPHX3416");
			expect(root.string("schema", "WPHX3416"), "wordpress-hx.generated-files.v1", "manifest schema");
			expect(root.string("canonicalization", "WPHX3416"), "wordpress-hx.canonical-json.v1", "manifest canonicalization");
			expect(root.string("transactionProtocol", "WPHX3416"), "wordpress-hx.ownership-transaction.v1", "transaction protocol");
			expect(root.string("manifestDigestAlgorithm", "WPHX3416"), "sha256-canonical-json-without-manifestDigest-v1", "manifest digest algorithm");
			final manifestDigest = root.string("manifestDigest", "WPHX3416");
			if (manifestDigest != CanonicalJson.digest(CanonicalJson.withoutField(value, "manifestDigest"))) {
				fail("manifest digest does not bind the canonical document", manifestPath);
			}
			validateLocations(root.object("locations", "WPHX3416"), manifestPath, project.metadataRoot.path);
			validateRoots(root.array("outputRoots", "WPHX3416"), roots);

			final lock = GeneratedOutputLockIdentity.read(project.context.lockBytes);
			final generator = root.object("generator", "WPHX3416");
			generator.exact([
				"sdkVersion",
				"cliVersion",
				"generatorId",
				"generatorSourceSha256",
				"toolchainSha256"
			], "WPHX3416");
			final generatorId = generator.string("generatorId", "WPHX3416");
			if (generatorId != "wordpress-hx.cli.build" && generatorId != "wordpress-hx.cli.plugin-build") {
				fail("manifest generator is outside the production build lane", manifestPath);
			}
			expect(generator.string("sdkVersion", "WPHX3416"), lock.sdkVersion, "SDK generator version");
			expect(generator.string("cliVersion", "WPHX3416"), lock.cliVersion, "CLI generator version");
			expect(generator.string("generatorSourceSha256", "WPHX3416"), lock.sdkLockEntrySha256, "generator source identity");
			expect(generator.string("toolchainSha256", "WPHX3416"), lock.lockDigest, "toolchain lock identity");

			final inputs = root.object("inputs", "WPHX3416");
			inputs.exact([
				"sourceTreeSha256",
				"semanticPlanSha256",
				"emissionResultSha256s",
				"generationSha256",
				"profile"
			], "WPHX3416");
			final sourceFingerprint = inputs.string("sourceTreeSha256", "WPHX3416");
			expect(sourceFingerprint, project.context.fingerprint(), "authored source fingerprint");
			final profile = inputs.object("profile", "WPHX3416");
			profile.exact(["profileId", "catalogRevision", "catalogSha256"], "WPHX3416");
			expect(profile.string("profileId", "WPHX3416"), lock.profileId, "profile ID");
			expect(profile.string("catalogRevision", "WPHX3416"), lock.catalogRevision, "profile catalog revision");
			expect(profile.string("catalogSha256", "WPHX3416"), lock.catalogSha256, "profile catalog digest");

			final paths = selectGeneratedPaths(root.array("files", "WPHX3416"), roots, project.context.bootstrap.root);
			paths.push(manifestPath);
			paths.sort(compareText);
			final tree = GeneratedOutputTree.scan(project.context.bootstrap.root, roots);
			tree.requireExactPaths(paths.copy());
			return new GeneratedOutputManifest(manifestPath, manifestDigest, sourceFingerprint, generatorId, lock.lockDigest, lock.profileId,
				lock.catalogRevision, lock.catalogSha256, paths);
		} catch (failure:CliFailure) {
			throw failure;
		} catch (failure:haxe.Exception) {
			throw new CliFailure("WPHX3416", failure.message, 5, "generated-output-provenance", manifestPath, [
				"Restore a complete build from the exact Haxe source, lock, profile, and generator."
			], failure);
		}
	}

	static function validateLocations(reader:JsonReader, manifestPath:String, metadataRoot:String):Void {
		reader.exact(["manifestPath", "transactionRoot", "lockPath", "journalPath"], "WPHX3416");
		expect(reader.string("manifestPath", "WPHX3416"), manifestPath, "manifest location");
		final transactionRoot = metadataRoot + "/.wphx-transactions";
		expect(reader.string("transactionRoot", "WPHX3416"), transactionRoot, "transaction root");
		expect(reader.string("lockPath", "WPHX3416"), transactionRoot + "/lock", "transaction lock path");
		expect(reader.string("journalPath", "WPHX3416"), transactionRoot + "/journal.json", "transaction journal path");
	}

	static function validateRoots(values:Array<JsonValue>, selected:Array<GeneratedOutputRoot>):Void {
		final actual = new Map<String, String>();
		for (index in 0...values.length) {
			final reader = JsonReader.from(values[index], "ownership manifest.outputRoots[" + index + "]", "WPHX3416");
			reader.exact(["rootId", "path", "ownershipMode"], "WPHX3416");
			expect(reader.string("ownershipMode", "WPHX3416"), "exact-file-manifest-coexists-with-unowned", "output-root ownership mode");
			actual.set(reader.string("rootId", "WPHX3416"), reader.string("path", "WPHX3416"));
		}
		for (root in selected) {
			if (actual.get(root.id) != root.path) {
				fail("selected policy root differs from the generated manifest", root.path);
			}
		}
	}

	static function selectGeneratedPaths(values:Array<JsonValue>, selected:Array<GeneratedOutputRoot>, projectRoot:String):Array<String> {
		final selectedIds = new Map<String, Bool>();
		for (root in selected) {
			selectedIds.set(root.id, true);
		}
		final paths:Array<String> = [];
		for (index in 0...values.length) {
			final reader = JsonReader.from(values[index], "ownership manifest.files[" + index + "]", "WPHX3416");
			reader.exact([
				"path",
				"rootId",
				"contentSha256",
				"sizeBytes",
				"kind",
				"ownerNodeId",
				"projectionIds",
				"sourceNodeIds",
				"sourceSpans",
				"validatorIds"
			], "WPHX3416");
			if (selectedIds.exists(reader.string("rootId", "WPHX3416"))) {
				final path = reader.string("path", "WPHX3416");
				final bytes = ProjectFiles.read(projectRoot, path, "committed generated file", "generated-output-provenance");
				if (bytes.length != reader.integer("sizeBytes", "WPHX3416")
					|| OwnershipJson.digest(bytes) != reader.string("contentSha256", "WPHX3416")) {
					fail("committed generated bytes differ from the exact manifest", path);
				}
				paths.push(path);
			}
		}
		return paths;
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			fail(label + " differs from the current authority", GeneratedOutputPolicy.PATH);
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function fail<T>(message:String, relative:String):T {
		throw new CliFailure("WPHX3416", message, 5, "generated-output-provenance", relative, [
			"Regenerate from committed Haxe and exact locks; generated files are evidence, never source authority."
		]);
	}

	function new(path:String, manifestDigest:String, sourceFingerprint:String, generatorId:String, toolchainDigest:String, profileId:String,
			catalogRevision:String, catalogSha256:String, generatedPaths:Array<String>) {
		this.path = path;
		this.manifestDigest = manifestDigest;
		this.sourceFingerprint = sourceFingerprint;
		this.generatorId = generatorId;
		this.toolchainDigest = toolchainDigest;
		this.profileId = profileId;
		this.catalogRevision = catalogRevision;
		this.catalogSha256 = catalogSha256;
		this.generatedPaths = generatedPaths;
	}
}
