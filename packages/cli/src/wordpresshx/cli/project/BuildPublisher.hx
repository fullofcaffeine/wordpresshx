package wordpresshx.cli.project;

import js.node.Buffer;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.ArtifactOwner;
import wordpresshx.cli.ownership.OwnershipContract;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.ownership.OwnershipResult;
import wordpresshx.cli.ownership.StageValidator;

typedef BuildPublication = {
	final outcome:String;
	final manifest:Dynamic;
}

/** Foundation metadata emitter plus the sole live-tree publication boundary. **/
class BuildPublisher {
	public static function recover(context:ProjectContext):String {
		final paths = OwnershipPaths.resolve(context.bootstrap);
		try {
			final owner = new ArtifactOwner(context.bootstrap.root, paths.layout);
			final result:OwnershipResult = owner.recover();
			return result;
		} catch (failure:OwnershipFailure) {
			throw new CliFailure("WPHX3000", failure.message, 5, "ownership-publish", failure.relativePath,
				["Run wphx doctor and diagnose the exact lock/journal bytes before retrying."]);
		}
	}

	public static function plan(context:ProjectContext):Dynamic {
		return prepare(context).manifest;
	}

	public static function publish(context:ProjectContext):BuildPublication {
		final generation = prepare(context);
		final paths = generation.paths;
		final manifest = generation.manifest;
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), "wordpresshx-sdk042-build-"));
		final stageRoot = Path.join(temporaryRoot, "stage");
		final manifestPath = Path.join(temporaryRoot, "next-manifest.json");
		var publication:Null<BuildPublication> = null;
		try {
			for (artifact in generation.artifacts) {
				write(stageRoot, artifact.path, artifact.bytes);
			}
			Fs.writeFileSync(manifestPath, OwnershipJson.encodeDocument(manifest));
			final validators:Array<StageValidator> = [
				{
					validatorId: "wphx.deterministic-archive",
					run: root -> ReproducibleBuild.validateStage(root, paths, context, generation.packagePayloads)
				},
				{
					validatorId: "wphx.effective-inputs",
					run: root -> validateStage(root, paths.metadataPath, context.fingerprint())
				}
			];
			final owner = new ArtifactOwner(context.bootstrap.root, paths.layout);
			final result:OwnershipResult = owner.publish(manifestPath, stageRoot, validators);
			publication = {outcome: result, manifest: manifest};
		} catch (failure:OwnershipFailure) {
			removeTemporary(temporaryRoot);
			throw new CliFailure("WPHX3001", failure.message, 5, "ownership-publish", failure.relativePath, [
				"Run wphx doctor, restore exact owned bytes, and retry without editing generated files."
			]);
		} catch (failure:Dynamic) {
			removeTemporary(temporaryRoot);
			throw failure;
		}
		removeTemporary(temporaryRoot);
		return publication;
	}

	public static function clean(context:ProjectContext):String {
		final paths = OwnershipPaths.resolve(context.bootstrap);
		try {
			final owner = new ArtifactOwner(context.bootstrap.root, paths.layout);
			final result:OwnershipResult = owner.clean();
			return result;
		} catch (failure:OwnershipFailure) {
			throw new CliFailure("WPHX3002", failure.message, 5, "ownership-publish", failure.relativePath,
				["Run wphx doctor and restore exact owned bytes before cleaning."]);
		}
	}

	static function prepare(context:ProjectContext):PreparedGeneration {
		final paths = OwnershipPaths.resolve(context.bootstrap);
		final effectiveBytes = OwnershipJson.encodeDocument(context.effectiveInputs);
		final packagePayloads:Array<ReproduciblePayload> = [{path: paths.metadataPath, bytes: effectiveBytes}];
		final reproducible = ReproducibleBuild.create(context, packagePayloads);
		final artifacts:Array<PreparedArtifact> = [
			{
				path: paths.metadataPath,
				rootId: paths.metadataRootId,
				bytes: effectiveBytes,
				kind: "build.effective-inputs.json",
				projectionIds: ["metadata/effective-inputs"],
				validatorIds: ["wphx.deterministic-archive", "wphx.effective-inputs"]
			},
			{
				path: paths.reproducibilityPath,
				rootId: paths.distributionRootId,
				bytes: reproducible.reportBytes,
				kind: "build.reproducibility-manifest.json",
				projectionIds: ["package/reproducibility-manifest"],
				validatorIds: ["wphx.deterministic-archive"]
			},
			{
				path: paths.archivePath,
				rootId: paths.distributionRootId,
				bytes: reproducible.archiveBytes,
				kind: "package.unsigned-zip",
				projectionIds: ["package/unsigned-zip"],
				validatorIds: ["wphx.deterministic-archive"]
			}
		];
		artifacts.sort((left, right) -> Reflect.compare(left.path, right.path));
		return {
			paths: paths,
			artifacts: artifacts,
			packagePayloads: packagePayloads,
			manifest: manifest(context, paths, artifacts)
		};
	}

	static function manifest(context:ProjectContext, paths:ProjectOwnershipPaths, artifacts:Array<PreparedArtifact>):Dynamic {
		final bootstrap = context.bootstrap;
		final configDigest = OwnershipJson.digest(bootstrap.configBytes);
		final sdkComponent = component(context.lock, "sdk.wordpress-hx");
		final sourceSpan = OwnershipJson.object([
			"path" => "wordpress-hx.json",
			"sourceSha256" => configDigest,
			"start" => OwnershipJson.object(["offset" => 0, "line" => 1, "column" => 0]),
			"end" => OwnershipJson.object(["offset" => 1, "line" => 1, "column" => 1]),
			"symbol" => "wordpress-hx.project"
		]);
		final projectNodeId = "project/" + ProjectContract.string(bootstrap.config, "projectId", "project configuration");
		final files:Array<Dynamic> = [];
		for (artifact in artifacts) {
			files.push(OwnershipJson.object([
				"path" => artifact.path,
				"rootId" => artifact.rootId,
				"contentSha256" => OwnershipJson.digest(artifact.bytes),
				"sizeBytes" => artifact.bytes.length,
				"kind" => artifact.kind,
				"ownerNodeId" => "project/" + ProjectContract.string(bootstrap.config, "projectId", "project configuration"),
				"projectionIds" => artifact.projectionIds,
				"sourceNodeIds" => [projectNodeId],
				"sourceSpans" => [sourceSpan],
				"validatorIds" => artifact.validatorIds
			]));
		}
		final outputRoots = OwnershipPaths.manifestRoots(bootstrap, paths);
		final profile = ProjectContract.fieldObject(context.lock, "profile", "project lock");
		final semanticSentinel = OwnershipJson.object([
			"reason" => "no target emitter registered in SDK-042 deterministic-build foundation",
			"schema" => "wordpress-hx.semantic-plan-state.v1",
			"state" => "not-produced"
		]);
		final emissionDigests:Array<String> = [];
		for (artifact in artifacts) {
			final digest = OwnershipJson.digest(artifact.bytes);
			if (emissionDigests.indexOf(digest) < 0) {
				emissionDigests.push(digest);
			}
		}
		emissionDigests.sort(Reflect.compare);
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
				"sdkVersion" => ProjectContract.string(ProjectContract.fieldObject(context.lock, "generatedBy", "project lock"), "sdkVersion",
					"project lock.generatedBy", "profile-resolution"),
				"cliVersion" => ProjectContract.string(ProjectContract.fieldObject(context.lock, "generatedBy", "project lock"), "cliVersion",
					"project lock.generatedBy", "profile-resolution"),
				"generatorId" => "wordpress-hx.cli.build",
				"generatorSourceSha256" => ProjectContract.string(sdkComponent, "lockEntrySha256", "SDK component", "profile-resolution"),
				"toolchainSha256" => ProjectContract.string(context.lock, "lockDigest", "project lock", "profile-resolution")
			]),
			"inputs" => OwnershipJson.object([
				"sourceTreeSha256" => context.fingerprint(),
				"semanticPlanSha256" => OwnershipJson.digestValue(semanticSentinel),
				"emissionResultSha256s" => emissionDigests,
				"generationSha256" => OwnershipContract.generationDigest(files),
				"profile" => OwnershipJson.object([
					"profileId" => ProjectContract.string(profile, "id", "project lock.profile", "profile-resolution"),
					"catalogRevision" => ProjectContract.string(profile, "catalogRevision", "project lock.profile", "profile-resolution"),
					"catalogSha256" => ProjectContract.string(profile, "catalogSha256", "project lock.profile", "profile-resolution")
				])
			]),
			"outputRoots" => outputRoots,
			"validators" => [
				OwnershipJson.object([
					"validatorId" => "wphx.deterministic-archive",
					"tool" => "@wordpress-hx/cli deterministic ZIP32 validator",
					"version" => "zip32-stored-v1",
					"toolSha256" => ProjectContract.string(sdkComponent, "lockEntrySha256", "SDK component", "profile-resolution"),
					"configSha256" => OwnershipJson.digestValue(bootstrap.config),
					"scope" => "complete-staged-tree",
					"outcome" => "passed"
				]),
				OwnershipJson.object([
					"validatorId" => "wphx.effective-inputs",
					"tool" => "@wordpress-hx/cli effective-input validator",
					"version" => "v1",
					"toolSha256" => ProjectContract.string(sdkComponent, "lockEntrySha256", "SDK component", "profile-resolution"),
					"configSha256" => OwnershipJson.digestValue(bootstrap.config),
					"scope" => "complete-staged-tree",
					"outcome" => "passed"
				])
			],
			"files" => files
		]);
		final result = OwnershipContract.withDigest(manifest, "manifestDigest");
		OwnershipContract.validateManifest(result);
		return result;
	}

	static function component(lock:Dynamic, id:String):Dynamic {
		for (value in ProjectContract.array(lock, "components", "project lock", "profile-resolution")) {
			if (ProjectContract.string(value, "id", "project lock component", "profile-resolution") == id) {
				return value;
			}
		}
		throw new CliFailure("WPHX1014", "project lock is missing component " + id, 3, "profile-resolution");
	}

	static function validateStage(root:String, relative:String, fingerprint:String):Void {
		final bytes = Fs.readFileSync(Path.resolve(root, relative));
		final value = OwnershipJson.parseCanonical(bytes, "staged effective inputs");
		if (ProjectContract.string(value, "schema", "effective inputs") != "wordpress-hx.effective-inputs.v1"
			|| ProjectContract.string(value, "fingerprint", "effective inputs") != fingerprint) {
			throw new OwnershipFailure("staged effective-input identity mismatch", "effective-input-validator", relative);
		}
		final material = OwnershipJson.clone(value);
		Reflect.deleteField(material, "fingerprint");
		if (OwnershipJson.digestValue(material) != fingerprint) {
			throw new OwnershipFailure("staged effective-input fingerprint mismatch", "effective-input-validator", relative);
		}
	}

	static function write(stageRoot:String, relative:String, bytes:Buffer):Void {
		final absolute = Path.resolve(stageRoot, relative);
		ensureDirectory(Path.dirname(absolute));
		Fs.writeFileSync(absolute, bytes, {flag: "wx", mode: 0x1a4});
	}

	static function ensureDirectory(absolute:String):Void {
		if (Fs.existsSync(absolute)) {
			return;
		}
		final parent = Path.dirname(absolute);
		if (parent != absolute) {
			ensureDirectory(parent);
		}
		Fs.mkdirSync(absolute, 0x1c0);
	}

	static function removeTemporary(root:String):Void {
		final prefix = Path.join(Os.tmpdir(), "wordpresshx-sdk042-build-");
		if (!StringTools.startsWith(root, prefix) || !Fs.existsSync(root)) {
			return;
		}
		removeTree(root);
	}

	static function removeTree(absolute:String):Void {
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(absolute);
			return;
		}
		if (!stats.isDirectory()) {
			throw new CliFailure("WPHX3003", "private build staging changed to a special file", 70, "ownership-publish");
		}
		final names = Fs.readdirSync(absolute);
		names.sort(Reflect.compare);
		for (name in names) {
			removeTree(Path.join(absolute, name));
		}
		Fs.rmdirSync(absolute);
	}
}
