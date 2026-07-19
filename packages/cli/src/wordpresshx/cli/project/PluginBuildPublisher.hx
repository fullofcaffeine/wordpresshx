package wordpresshx.cli.project;

import haxe.Exception;
import js.lib.Error;
import js.node.Buffer;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.ownership.ArtifactOwner;
import wordpresshx.cli.ownership.OwnershipContract;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.ownership.OwnershipResult;
import wordpresshx.cli.ownership.StageValidator;

/** Publish one native plugin generation through the established owner protocol. */
class PluginBuildPublisher {
	static inline final TEMPORARY_PREFIX = "wordpresshx-plugin-build-";

	public static function plan(context:ProjectContext, emission:PluginEmission):Void {
		try {
			prepare(context, emission);
		} catch (failure:OwnershipFailure) {
			throw new CliFailure("WPHX3306", failure.message, 5, "metadata-emission", failure.relativePath,
				["The typed plugin generation was rejected before staging or publication."], failure);
		}
	}

	public static function publish(context:ProjectContext, emission:PluginEmission):ProjectBuildResult {
		final generation = prepare(context, emission);
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), TEMPORARY_PREFIX));
		final stageRoot = Path.join(temporaryRoot, "stage");
		final manifestPath = Path.join(temporaryRoot, "next-manifest.json");
		try {
			for (artifact in generation.artifacts) {
				write(stageRoot, artifact.path, artifact.bytes);
			}
			Fs.writeFileSync(manifestPath, OwnershipJson.encodeDocument(generation.manifest));
			final validators:Array<StageValidator> = [
				{
					validatorId: "wphx.deterministic-archive",
					run: root -> ReproducibleBuild.validateStage(root, generation.paths, context, generation.packagePayloads)
				},
				{
					validatorId: "wphx.effective-inputs",
					run: root -> validateExact(root, generation.paths.metadataPath, generation.effectiveBytes, "effective-input")
				},
				{
					validatorId: "wphx.plugin-public-php",
					run: root -> validatePluginStage(root, generation.pluginBase, emission)
				}
			];
			if (emission.plan.privateTitleFilter != null) {
				validators.push({
					validatorId: "wphx.plugin-private-php",
					run: root -> validatePluginStage(root, generation.pluginBase, emission)
				});
			}
			final owner = new ArtifactOwner(context.bootstrap.root, generation.paths.layout);
			final outcome:OwnershipResult = owner.publish(manifestPath, stageRoot, validators);
			PluginArtifactPermissions.enforce(context.bootstrap.root, generation.pluginBase, emission.files);
			final digest = manifestDigest(generation.manifest);
			removeTemporary(temporaryRoot);
			return {outcome: outcome, manifestDigest: digest};
		} catch (failure:OwnershipFailure) {
			removeTemporary(temporaryRoot);
			throw new CliFailure("WPHX3306", failure.message, 5, "ownership-publish", failure.relativePath, [
				"Restore exact owned bytes and rerun; no partial plugin generation was published."
			], failure);
		} catch (failure:Exception) {
			removeTemporary(temporaryRoot);
			throw failure;
		} catch (failure:Error) {
			removeTemporary(temporaryRoot);
			throw failure;
		}
	}

	static function prepare(context:ProjectContext, emission:PluginEmission) {
		final paths = OwnershipPaths.resolve(context.bootstrap);
		final wordpressRoot = requiredRoot(context, "wordpress");
		final metadataRoot = requiredRoot(context, paths.metadataRootId);
		final pluginBase = wordpressRoot.path + "/" + emission.plan.slug;
		final effectiveBytes = OwnershipJson.encodeDocument(context.effectiveInputs);
		final packagePayloads:Array<ReproduciblePayload> = [
			for (file in emission.files)
				{path: emission.plan.slug + "/" + file.relativePath, bytes: file.bytes}
		];
		final reproducible = ReproducibleBuild.create(context, packagePayloads);
		final commonValidators = ["wphx.deterministic-archive", "wphx.plugin-public-php"];
		if (emission.plan.privateTitleFilter != null) {
			commonValidators.push("wphx.plugin-private-php");
		}
		commonValidators.sort(compareText);
		final artifacts:Array<PreparedArtifact> = [
			for (file in emission.files)
				{
					path: pluginBase + "/" + file.relativePath,
					rootId: wordpressRoot.id,
					bytes: file.bytes,
					kind: file.artifactKind(),
					projectionIds: [projectionId(file)],
					validatorIds: commonValidators
				}
		];
		artifacts.push({
			path: metadataRoot.path + "/.wphx/plugin-plan.json",
			rootId: metadataRoot.id,
			bytes: emission.planBytes,
			kind: "semantic.plugin-plan.json",
			projectionIds: ["plan/plugin"],
			validatorIds: ["wphx.plugin-public-php"]
		});
		artifacts.push({
			path: metadataRoot.path + "/.wphx/plugin-emission.json",
			rootId: metadataRoot.id,
			bytes: emission.resultBytes,
			kind: "semantic.plugin-emission.json",
			projectionIds: ["emission/plugin"],
			validatorIds: ["wphx.plugin-public-php"]
		});
		artifacts.push({
			path: paths.metadataPath,
			rootId: paths.metadataRootId,
			bytes: effectiveBytes,
			kind: "build.effective-inputs.json",
			projectionIds: ["metadata/effective-inputs"],
			validatorIds: ["wphx.deterministic-archive", "wphx.effective-inputs"]
		});
		artifacts.push({
			path: paths.reproducibilityPath,
			rootId: paths.distributionRootId,
			bytes: reproducible.reportBytes,
			kind: "build.reproducibility-manifest.json",
			projectionIds: ["package/reproducibility-manifest"],
			validatorIds: ["wphx.deterministic-archive"]
		});
		artifacts.push({
			path: paths.archivePath,
			rootId: paths.distributionRootId,
			bytes: reproducible.archiveBytes,
			kind: "package.unsigned-wordpress-plugin-zip",
			projectionIds: ["package/unsigned-plugin-zip"],
			validatorIds: ["wphx.deterministic-archive", "wphx.plugin-public-php"]
		});
		artifacts.sort((left, right) -> compareText(left.path, right.path));
		return {
			paths: paths,
			pluginBase: pluginBase,
			artifacts: artifacts,
			packagePayloads: packagePayloads,
			effectiveBytes: effectiveBytes,
			manifest: manifest(context, emission, paths, artifacts)
		};
	}

	static function manifest(context:ProjectContext, emission:PluginEmission, paths:ProjectOwnershipPaths, artifacts:Array<PreparedArtifact>) {
		final lock = PluginLockReader.read(context);
		final sourceBytes = ProjectFiles.read(context.bootstrap.root, emission.plan.sourcePath, "plugin declaration", "artifact-validation");
		final sourceSpan = OwnershipJson.object([
			"path" => emission.plan.sourcePath,
			"sourceSha256" => OwnershipJson.digest(sourceBytes),
			"start" => OwnershipJson.object(["offset" => 0, "line" => 1, "column" => 0]),
			"end" => endPosition(sourceBytes),
			"symbol" => "Site.definition"
		]);
		final ownerNodeId = "plugin/" + emission.plan.slug;
		final files = [
			for (artifact in artifacts)
				OwnershipJson.object([
					"path" => artifact.path,
					"rootId" => artifact.rootId,
					"contentSha256" => OwnershipJson.digest(artifact.bytes),
					"sizeBytes" => artifact.bytes.length,
					"kind" => artifact.kind,
					"ownerNodeId" => ownerNodeId,
					"projectionIds" => artifact.projectionIds,
					"sourceNodeIds" => [ownerNodeId],
					"sourceSpans" => [sourceSpan],
					"validatorIds" => artifact.validatorIds
				])
		];
		final validators = [
			validator("wphx.deterministic-archive", "@wordpress-hx/cli deterministic ZIP32 validator", "zip32-stored-v1", lock, context,
				"complete-staged-tree"),
			validator("wphx.effective-inputs", "@wordpress-hx/cli effective-input validator", "v1", lock, context, "complete-staged-tree")
		];
		if (emission.plan.privateTitleFilter != null) {
			validators.push(validator("wphx.plugin-private-php", "WordPressHx dependency-closed private PHP packager", "sdk-024-v1", lock, context,
				"complete-staged-tree"));
		}
		validators.push(validator("wphx.plugin-public-php", "WordPressHx structured public-PHP profile", "sdk-022-v1", lock, context, "complete-staged-tree"));
		final manifest = OwnershipJson.object([
			"schema" => OwnershipContract.MANIFEST_SCHEMA,
			"canonicalization" => OwnershipContract.CANONICALIZATION,
			"transactionProtocol" => OwnershipContract.TRANSACTION_PROTOCOL,
			"manifestDigestAlgorithm" => OwnershipContract.MANIFEST_DIGEST_ALGORITHM,
			"manifestDigest" => StringTools.lpad("", "0", 64),
			"locations" => OwnershipJson.object([
				"manifestPath" => paths.layout.manifestPath,
				"transactionRoot" => paths.layout.transactionRoot,
				"lockPath" => paths.layout.transactionRoot + "/lock",
				"journalPath" => paths.layout.transactionRoot + "/journal.json"
			]),
			"generator" => OwnershipJson.object([
				"sdkVersion" => lock.sdkVersion,
				"cliVersion" => lock.cliVersion,
				"generatorId" => "wordpress-hx.cli.plugin-build",
				"generatorSourceSha256" => lock.sdkLockEntrySha256,
				"toolchainSha256" => lock.lockDigest
			]),
			"inputs" => OwnershipJson.object([
				"sourceTreeSha256" => context.fingerprint(),
				"semanticPlanSha256" => emission.planSha256,
				"emissionResultSha256s" => [emission.resultSha256],
				"generationSha256" => OwnershipContract.generationDigest(files),
				"profile" => OwnershipJson.object([
					"profileId" => emission.plan.profile,
					"catalogRevision" => lock.catalogRevision,
					"catalogSha256" => lock.catalogSha256
				])
			]),
			"outputRoots" => OwnershipPaths.manifestRoots(context.bootstrap, paths),
			"validators" => validators,
			"files" => files
		]);
		final result = OwnershipContract.withDigest(manifest, "manifestDigest");
		OwnershipContract.validateManifest(result);
		return result;
	}

	static function validator(id:String, tool:String, version:String, lock:PluginLockIdentity, context:ProjectContext, scope:String) {
		return OwnershipJson.object([
			"validatorId" => id,
			"tool" => tool,
			"version" => version,
			"toolSha256" => lock.sdkLockEntrySha256,
			"configSha256" => OwnershipJson.digest(context.bootstrap.configBytes),
			"scope" => scope,
			"outcome" => "passed"
		]);
	}

	static function projectionId(file:PluginEmittedFile):String {
		return file.lane == PublicNative ? "php/plugin/" + file.role : "php/plugin/private/" + wordpresshx.cli.Content.digest(file.relativePath).substr(0, 24);
	}

	static function requiredRoot(context:ProjectContext, id:String):ProjectOutputRoot {
		for (root in context.bootstrap.outputRoots) {
			if (root.id == id) {
				return root;
			}
		}
		throw new CliFailure("WPHX3307", "plugin build requires the declared output root " + id, 3, "configuration", "wordpress-hx.json");
	}

	static function endPosition(bytes:Buffer) {
		var line = 1;
		var column = 0;
		for (index in 0...bytes.length) {
			if (bytes[index] == 0x0a) {
				line++;
				column = 0;
			} else {
				column++;
			}
		}
		return OwnershipJson.object(["offset" => bytes.length, "line" => line, "column" => column]);
	}

	static function manifestDigest(manifest):String {
		final value = JsonParser.parse(OwnershipJson.encode(manifest));
		return JsonReader.from(value, "plugin ownership manifest", "WPHX3308").string("manifestDigest", "WPHX3308");
	}

	static function validatePluginStage(root:String, pluginBase:String, emission:PluginEmission):Void {
		for (file in emission.files) {
			validateExact(root, pluginBase + "/" + file.relativePath, file.bytes, "plugin artifact");
		}
	}

	static function validateExact(root:String, relative:String, expected:Buffer, label:String):Void {
		final absolute = Path.resolve(root, relative);
		if (!Fs.existsSync(absolute)) {
			throw new OwnershipFailure(label + " is missing from the complete stage", "plugin-stage-validator", relative);
		}
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			throw new OwnershipFailure(label + " is not a regular staged file", "plugin-stage-validator", relative);
		}
		final actual = Fs.readFileSync(absolute);
		if (actual.length != expected.length || OwnershipJson.digest(actual) != OwnershipJson.digest(expected)) {
			throw new OwnershipFailure(label + " bytes differ from the in-memory emission", "plugin-stage-validator", relative);
		}
	}

	static function write(stageRoot:String, relative:String, bytes:Buffer):Void {
		final absolute = Path.resolve(stageRoot, relative);
		ensureDirectory(Path.dirname(absolute));
		Fs.writeFileSync(absolute, bytes, {flag: "wx", mode: 0x1a4});
	}

	static function ensureDirectory(path:String):Void {
		if (Fs.existsSync(path)) {
			return;
		}
		final parent = Path.dirname(path);
		if (parent != path) {
			ensureDirectory(parent);
		}
		Fs.mkdirSync(path, 0x1c0);
	}

	static function removeTemporary(root:String):Void {
		final prefix = Path.join(Os.tmpdir(), TEMPORARY_PREFIX);
		if (!StringTools.startsWith(root, prefix) || !Fs.existsSync(root)) {
			return;
		}
		removeTree(root);
	}

	static function removeTree(path:String):Void {
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(path);
			return;
		}
		if (!stats.isDirectory()) {
			throw new CliFailure("WPHX3309", "private plugin stage changed to a special file", 70, "ownership-publish");
		}
		final names = Fs.readdirSync(path);
		names.sort(compareText);
		for (name in names) {
			removeTree(Path.join(path, name));
		}
		Fs.rmdirSync(path);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
