package wordpresshx.cli.project;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Discover and authenticate the small bootstrap before any compiler runs. **/
class ProjectLoader {
	static final REQUIRED_COMPONENTS = [
		"compiler.genes",
		"compiler.haxe",
		"compiler.reflaxe-php",
		"runtime.node",
		"sdk.wordpress-hx",
		"tool.lix",
		"tool.npm",
		"tool.wordpress-scripts"
	];

	public static function discover(start:String):ProjectBootstrap {
		final root = discoverRoot(start);
		final configBytes = ProjectFiles.read(root, "wordpress-hx.json", "project bootstrap");
		final config = parseStrict(configBytes, "wordpress-hx.json", "configuration");
		return validateConfig(root, config, configBytes);
	}

	public static function resolve(bootstrap:ProjectBootstrap, ?profileOverride:String):ProjectContext {
		final lockBytes = ProjectFiles.read(bootstrap.root, bootstrap.lockPath, "project lock", "profile-resolution");
		final lock = parseCanonical(lockBytes, bootstrap.lockPath, "profile-resolution");
		validateLock(bootstrap, lock);
		final configuredProfile = ProjectContract.string(ProjectContract.fieldObject(bootstrap.config, "profile", "project configuration"), "id",
			"project profile");
		if (profileOverride != null && profileOverride != configuredProfile) {
			throw new CliFailure("WPHX1101", "requested profile " + profileOverride + " differs from the locked project profile " + configuredProfile, 4,
				"profile-resolution", "wordpress-hx.json", [
					"Run the explicit profile/lock workflow before building with a different profile."
				]);
		}
		final effective = EffectiveInputs.build(bootstrap, lock, lockBytes);
		return new ProjectContext(bootstrap, lock, lockBytes, effective);
	}

	static function discoverRoot(start:String):String {
		var candidate = Path.resolve(start);
		if (Fs.existsSync(candidate) && Fs.lstatSync(candidate).isFile()) {
			if (Path.basename(candidate) != "wordpress-hx.json") {
				throw new CliFailure("WPHX1001", "--project must name a project directory or wordpress-hx.json", 2, "configuration", null,
					["Pass --project <directory> or run the command inside a WordPressHx project."]);
			}
			candidate = Path.dirname(candidate);
		}
		while (true) {
			final configPath = Path.join(candidate, "wordpress-hx.json");
			if (Fs.existsSync(configPath)) {
				final rootStats = Fs.lstatSync(candidate);
				final configStats = Fs.lstatSync(configPath);
				if (rootStats.isSymbolicLink() || !rootStats.isDirectory() || configStats.isSymbolicLink() || !configStats.isFile()) {
					throw new CliFailure("WPHX1008", "project root and wordpress-hx.json must be real directory/file entries", 3, "configuration",
						"wordpress-hx.json", ["Replace the symbolic link or special file with a regular project-local entry."]);
				}
				return Fs.realpathSync(candidate);
			}
			final parent = Path.dirname(candidate);
			if (parent == candidate) {
				break;
			}
			candidate = parent;
		}
		throw new CliFailure("WPHX1001", "no wordpress-hx.json was found from the selected directory upward", 2, "configuration", null,
			["Run the command inside a WordPressHx project or pass --project <directory>."]);
	}

	static function validateConfig(root:String, config:Dynamic, configBytes:Buffer):ProjectBootstrap {
		ProjectContract.exactFields(config, [
			"schema",
			"projectId",
			"entryPoint",
			"profile",
			"paths",
			"toolchain",
			"environment"
		], "project configuration");
		ProjectContract.expect(ProjectContract.string(config, "schema", "project configuration"), "wordpress-hx.project.v1", "project configuration.schema");
		final projectId = ProjectContract.stableId(ProjectContract.string(config, "projectId", "project configuration"), "project configuration.projectId");
		final entryPoint = ProjectContract.string(config, "entryPoint", "project configuration");
		if (!ProjectContract.HAXE_TYPE.match(entryPoint)) {
			ProjectContract.fail("WPHX1003", "project configuration.entryPoint is not a fully qualified Haxe type", 3, "configuration", "wordpress-hx.json");
		}

		final profile = ProjectContract.fieldObject(config, "profile", "project configuration");
		ProjectContract.exactFields(profile, ["id"], "project configuration.profile");
		ProjectContract.stableId(ProjectContract.string(profile, "id", "project profile"), "project profile.id");

		final paths = ProjectContract.fieldObject(config, "paths", "project configuration");
		ProjectContract.exactFields(paths, [
			"sourceRoots",
			"testRoots",
			"assetRoots",
			"outputRoots",
			"distributionRoot",
			"stateRoot"
		], "project configuration.paths");
		final sourceRoots = ProjectContract.sortedUniqueStrings(ProjectContract.array(paths, "sourceRoots", "project paths"), "source roots",
			ProjectContract.relativePath);
		if (sourceRoots.length == 0) {
			ProjectContract.fail("WPHX1003", "at least one source root is required", 3, "configuration");
		}
		final testRoots = ProjectContract.sortedUniqueStrings(ProjectContract.array(paths, "testRoots", "project paths"), "test roots",
			ProjectContract.relativePath);
		final assetRoots = ProjectContract.sortedUniqueStrings(ProjectContract.array(paths, "assetRoots", "project paths"), "asset roots",
			ProjectContract.relativePath);
		final outputValues = ProjectContract.array(paths, "outputRoots", "project paths");
		if (outputValues.length == 0) {
			ProjectContract.fail("WPHX1003", "at least one output root is required", 3, "configuration");
		}
		final outputRoots:Array<ProjectOutputRoot> = [];
		var previousOutputId:Null<String> = null;
		var previousOutputPath:Null<String> = null;
		for (index in 0...outputValues.length) {
			final output = ProjectContract.object(outputValues[index], "output root");
			ProjectContract.exactFields(output, ["id", "path"], "project output root");
			final id = ProjectContract.stableId(ProjectContract.string(output, "id", "project output root"), "project output root.id");
			final path = ProjectContract.relativePath(ProjectContract.string(output, "path", "project output root"), "project output root.path");
			if (previousOutputId != null && Reflect.compare(previousOutputId, id) >= 0) {
				ProjectContract.fail("WPHX1006", "output roots must be sorted by unique ID", 3, "configuration");
			}
			if (previousOutputPath != null && Reflect.compare(previousOutputPath, path) >= 0) {
				ProjectContract.fail("WPHX1006", "output-root paths must be a sorted unique set", 3, "configuration");
			}
			previousOutputId = id;
			previousOutputPath = path;
			outputRoots.push({id: id, path: path});
		}
		for (left in 0...outputRoots.length) {
			for (right in left + 1...outputRoots.length) {
				if (ProjectContract.nested(outputRoots[left].path, outputRoots[right].path)
					|| ProjectContract.nested(outputRoots[right].path, outputRoots[left].path)) {
					ProjectContract.fail("WPHX1009", "output roots may not nest", 3, "configuration");
				}
			}
		}
		final distributionRoot = ProjectContract.relativePath(ProjectContract.string(paths, "distributionRoot", "project paths"), "distribution root");
		final stateRoot = ProjectContract.relativePath(ProjectContract.string(paths, "stateRoot", "project paths"), "state root");
		validateRootSeparation(sourceRoots.concat(testRoots).concat(assetRoots),
			[for (output in outputRoots) output.path].concat([distributionRoot, stateRoot]));
		if (distributionRoot == stateRoot
			|| ProjectContract.nested(distributionRoot, stateRoot)
			|| ProjectContract.nested(stateRoot, distributionRoot)) {
			ProjectContract.fail("WPHX1009", "distribution and state roots must be disjoint", 3, "configuration");
		}

		final toolchain = ProjectContract.fieldObject(config, "toolchain", "project configuration");
		ProjectContract.exactFields(toolchain, ["lock", "packageManager"], "project configuration.toolchain");
		final lockPath = ProjectContract.relativePath(ProjectContract.string(toolchain, "lock", "project toolchain"), "project lock path");
		if (!ProjectContract.nested(stateRoot, lockPath)) {
			ProjectContract.fail("WPHX1009", "project lock must live below the state root", 3, "configuration", lockPath);
		}
		final packageManager = ProjectContract.fieldObject(toolchain, "packageManager", "project toolchain");
		ProjectContract.exactFields(packageManager, ["kind", "manifest", "lockfile"], "project package manager");
		ProjectContract.expect(ProjectContract.string(packageManager, "kind", "project package manager"), "npm", "project package manager.kind");
		final packageManifestPath = ProjectContract.relativePath(ProjectContract.string(packageManager, "manifest", "project package manager"),
			"package manifest path");
		final packageLockPath = ProjectContract.relativePath(ProjectContract.string(packageManager, "lockfile", "project package manager"),
			"package lock path");
		if (packageManifestPath == packageLockPath) {
			ProjectContract.fail("WPHX1009", "package manifest and lockfile paths must differ", 3, "configuration");
		}

		validateEnvironment(config);
		for (path in sourceRoots.concat(testRoots).concat(assetRoots)) {
			ProjectFiles.requireDirectory(root, path, "configured authored root");
		}
		final entryRelative = entryPoint.split(".").join("/") + ".hx";
		var entryFound = false;
		for (sourceRoot in sourceRoots) {
			if (ProjectFiles.existsRegular(root, sourceRoot + "/" + entryRelative)) {
				entryFound = true;
			}
		}
		if (!entryFound) {
			throw new CliFailure("WPHX1010", "entry point source does not exist: " + entryPoint, 3, "configuration", null,
				["Create " + entryRelative + " below a declared source root or fix entryPoint."]);
		}
		validatePackageFiles(root, packageManifestPath, packageLockPath);
		return new ProjectBootstrap(root, config, configBytes, outputRoots, sourceRoots, testRoots, assetRoots, stateRoot, distributionRoot, lockPath,
			packageManifestPath, packageLockPath);
	}

	static function validateRootSeparation(authored:Array<String>, generated:Array<String>):Void {
		for (left in authored) {
			for (right in generated) {
				if (left == right || ProjectContract.nested(left, right) || ProjectContract.nested(right, left)) {
					ProjectContract.fail("WPHX1009", "authored and generated/state roots must be disjoint", 3, "configuration");
				}
			}
		}
	}

	static function validateEnvironment(config:Dynamic):Void {
		final environment = ProjectContract.fieldObject(config, "environment", "project configuration");
		ProjectContract.exactFields(environment, ["build", "runtime"], "project environment");
		final build = ProjectContract.array(environment, "build", "project environment");
		final runtime = ProjectContract.array(environment, "runtime", "project environment");
		final names = new Map<String, Bool>();
		var previousBuild:Null<String> = null;
		for (index in 0...build.length) {
			final item = ProjectContract.object(build[index], "build environment declaration");
			final expected = Reflect.hasField(item, "default") ? ["name", "required", "classification", "default"] : ["name", "required", "classification"];
			ProjectContract.exactFields(item, expected, "build environment declaration");
			final name = environmentName(ProjectContract.string(item, "name", "build environment declaration"));
			if (previousBuild != null && Reflect.compare(previousBuild, name) >= 0) {
				ProjectContract.fail("WPHX1006", "build environment declarations must be sorted and unique", 3, "configuration");
			}
			previousBuild = name;
			names.set(name, true);
			ProjectContract.expect(ProjectContract.string(item, "classification", "build environment declaration"), "public-build",
				"build environment classification");
			if (ProjectContract.boolean(item, "required", "build environment declaration") && Reflect.hasField(item, "default")) {
				ProjectContract.fail("WPHX1003", "required build environment declarations cannot define a default", 3, "configuration");
			}
			if (Reflect.hasField(item, "default") && !Std.isOfType(Reflect.field(item, "default"), String)) {
				ProjectContract.fail("WPHX1003", "build environment default must be a string", 3, "configuration");
			}
		}
		var previousRuntime:Null<String> = null;
		for (index in 0...runtime.length) {
			final item = ProjectContract.object(runtime[index], "runtime environment declaration");
			ProjectContract.exactFields(item, ["name", "required", "classification", "services"], "runtime environment declaration");
			final name = environmentName(ProjectContract.string(item, "name", "runtime environment declaration"));
			if (previousRuntime != null && Reflect.compare(previousRuntime, name) >= 0) {
				ProjectContract.fail("WPHX1006", "runtime environment declarations must be sorted and unique", 3, "configuration");
			}
			if (names.exists(name)) {
				ProjectContract.fail("WPHX1006", "build and runtime environment names must be disjoint", 3, "configuration");
			}
			previousRuntime = name;
			final classification = ProjectContract.string(item, "classification", "runtime environment declaration");
			if (classification != "public-runtime" && classification != "secret-runtime") {
				ProjectContract.fail("WPHX1003", "runtime environment classification is outside the closed enum", 3, "configuration");
			}
			ProjectContract.boolean(item, "required", "runtime environment declaration");
			final services = ProjectContract.sortedUniqueStrings(ProjectContract.array(item, "services", "runtime environment declaration"),
				"runtime environment services", (value, label) -> ProjectContract.stableId(value, label));
			if (services.length == 0) {
				ProjectContract.fail("WPHX1003", "runtime environment services may not be empty", 3, "configuration");
			}
		}
	}

	static function environmentName(value:String):String {
		if (!ProjectContract.ENVIRONMENT_NAME.match(value)) {
			ProjectContract.fail("WPHX1003", "environment name must use uppercase ASCII with underscores", 3, "configuration");
		}
		return value;
	}

	static function validatePackageFiles(root:String, manifestPath:String, lockPath:String):Void {
		final manifest = parseStrict(ProjectFiles.read(root, manifestPath, "consumer npm manifest"), manifestPath, "configuration");
		final packageManager = ProjectContract.string(manifest, "packageManager", "consumer npm manifest");
		ProjectContract.expect(packageManager, "npm@10.9.2", "consumer npm packageManager");
		final dependencies = ProjectContract.fieldObject(manifest, "devDependencies", "consumer npm manifest");
		final cliVersion = ProjectContract.string(dependencies, "@wordpress-hx/cli", "consumer npm devDependencies");
		ProjectContract.exactVersion(cliVersion, "@wordpress-hx/cli version", "configuration");
		final scripts = ProjectContract.fieldObject(manifest, "scripts", "consumer npm manifest");
		ProjectContract.exactFields(scripts, ["build", "check", "dev", "test"], "consumer npm scripts");
		for (field => expected in [
			"build" => "wphx build",
			"check" => "wphx check",
			"dev" => "wphx dev",
			"test" => "wphx test"
		]) {
			ProjectContract.expect(ProjectContract.string(scripts, field, "consumer npm scripts"), expected, "consumer npm scripts." + field);
		}
		if (OwnershipJson.encode(manifest).indexOf("wphx-sdk") >= 0) {
			ProjectContract.fail("WPHX1004", "legacy wphx-sdk spelling leaked into the stable consumer manifest", 3, "configuration", manifestPath);
		}
		final lock = parseStrict(ProjectFiles.read(root, lockPath, "consumer npm lock"), lockPath, "configuration");
		if (ProjectContract.integer(lock, "lockfileVersion", "consumer npm lock") != 3) {
			ProjectContract.fail("WPHX1004", "consumer npm lock must use lockfileVersion 3", 3, "configuration", lockPath);
		}
	}

	static function validateLock(bootstrap:ProjectBootstrap, lock:Dynamic):Void {
		ProjectContract.exactFields(lock, [
			"schema",
			"canonicalization",
			"lockDigestAlgorithm",
			"lockDigest",
			"generatedBy",
			"project",
			"profile",
			"components",
			"packageGraph"
		], "project lock", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(lock, "schema", "project lock", "profile-resolution"), "wordpress-hx.project-lock.v1",
			"project lock.schema", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(lock, "canonicalization", "project lock", "profile-resolution"), "wordpress-hx.canonical-json.v1",
			"project lock.canonicalization", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(lock, "lockDigestAlgorithm", "project lock", "profile-resolution"),
			"sha256-canonical-json-without-lockDigest-v1", "project lock.lockDigestAlgorithm", "profile-resolution");
		final lockDigest = ProjectContract.sha256(ProjectContract.string(lock, "lockDigest", "project lock", "profile-resolution"), "project lock digest");
		final lockMaterial = OwnershipJson.clone(lock);
		Reflect.deleteField(lockMaterial, "lockDigest");
		if (lockDigest != OwnershipJson.digestValue(lockMaterial)) {
			throw new CliFailure("WPHX1011", "project lock self-digest mismatch", 3, "profile-resolution", bootstrap.lockPath,
				["Run the explicit lock command and review the resulting lock diff."]);
		}
		final generatedBy = ProjectContract.fieldObject(lock, "generatedBy", "project lock");
		ProjectContract.exactFields(generatedBy, ["sdkVersion", "cliVersion"], "project lock.generatedBy", "profile-resolution");
		ProjectContract.exactVersion(ProjectContract.string(generatedBy, "sdkVersion", "project lock.generatedBy", "profile-resolution"), "locked SDK version");
		ProjectContract.exactVersion(ProjectContract.string(generatedBy, "cliVersion", "project lock.generatedBy", "profile-resolution"), "locked CLI version");

		final project = ProjectContract.fieldObject(lock, "project", "project lock");
		ProjectContract.exactFields(project, ["id", "configPath", "configSemanticSha256"], "project lock.project", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(project, "id", "project lock.project", "profile-resolution"),
			ProjectContract.string(bootstrap.config, "projectId", "project configuration"), "project lock project ID", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(project, "configPath", "project lock.project", "profile-resolution"), "wordpress-hx.json",
			"project lock configPath", "profile-resolution");
		final configDigest = OwnershipJson.digestValue(bootstrap.config);
		ProjectContract.expect(ProjectContract.string(project, "configSemanticSha256", "project lock.project", "profile-resolution"), configDigest,
			"project lock config semantic digest", "profile-resolution");

		final profile = ProjectContract.fieldObject(lock, "profile", "project lock");
		ProjectContract.exactFields(profile, ["id", "catalogRevision", "catalogSha256"], "project lock.profile", "profile-resolution");
		ProjectContract.expect(ProjectContract.string(profile, "id", "project lock.profile", "profile-resolution"),
			ProjectContract.string(ProjectContract.fieldObject(bootstrap.config, "profile", "project configuration"), "id", "project profile"),
			"project lock profile", "profile-resolution");
		ProjectContract.string(profile, "catalogRevision", "project lock.profile", "profile-resolution");
		ProjectContract.sha256(ProjectContract.string(profile, "catalogSha256", "project lock.profile", "profile-resolution"), "profile catalog digest");
		validateComponents(lock);
		validatePackageGraph(bootstrap, lock);
	}

	static function validateComponents(lock:Dynamic):Void {
		final components = ProjectContract.array(lock, "components", "project lock", "profile-resolution");
		final ids:Array<String> = [];
		var previous:Null<String> = null;
		for (index in 0...components.length) {
			final component = ProjectContract.object(components[index], "project lock component");
			ProjectContract.exactFields(component, ["id", "role", "version", "source", "identity", "lockEntrySha256"], "project lock component",
				"profile-resolution");
			final id = ProjectContract.stableId(ProjectContract.string(component, "id", "project lock component", "profile-resolution"), "component ID",
				"profile-resolution");
			if (previous != null && Reflect.compare(previous, id) >= 0) {
				ProjectContract.fail("WPHX1014", "project lock components must be sorted and unique", 3, "profile-resolution");
			}
			previous = id;
			ids.push(id);
			final role = ProjectContract.string(component, "role", "project lock component", "profile-resolution");
			if ([
				"compiler",
				"dependency-manager",
				"package-manager",
				"runtime",
				"sdk",
				"build-tool"
			].indexOf(role) < 0) {
				ProjectContract.fail("WPHX1014", "component role is outside the closed enum", 3, "profile-resolution");
			}
			ProjectContract.exactVersion(ProjectContract.string(component, "version", "project lock component", "profile-resolution"), "component version");
			final source = ProjectContract.string(component, "source", "project lock component", "profile-resolution");
			if (["co-located", "git-source", "npm-release", "haxelib-release", "oci-image"].indexOf(source) < 0) {
				ProjectContract.fail("WPHX1014", "component source is outside the closed enum", 3, "profile-resolution");
			}
			final identity = ProjectContract.string(component, "identity", "project lock component", "profile-resolution");
			if (identity.indexOf("../") >= 0 || identity.indexOf("file:") >= 0 || identity.indexOf("link:") >= 0 || identity.indexOf("haxelib dev") >= 0) {
				throw new CliFailure("WPHX1015", "floating or machine-local component identity is forbidden: " + id, 3, "profile-resolution", null, [
					"Regenerate the project lock with an immutable public package, commit, tree, or OCI digest."
				]);
			}
			final entryDigest = ProjectContract.sha256(ProjectContract.string(component, "lockEntrySha256", "project lock component", "profile-resolution"),
				"component lock-entry digest");
			final material = OwnershipJson.clone(component);
			Reflect.deleteField(material, "lockEntrySha256");
			if (entryDigest != OwnershipJson.digestValue(material)) {
				throw new CliFailure("WPHX1016", "component lock-entry digest mismatch: " + id, 3, "profile-resolution", null,
					["Regenerate the exact project lock and review the component identity."]);
			}
		}
		if (ids.join("\x00") != REQUIRED_COMPONENTS.join("\x00")) {
			throw new CliFailure("WPHX1014", "project lock does not contain the exact v1 component set", 3, "profile-resolution", null,
				["Run the explicit lock command with the installed WordPressHx CLI version."]);
		}
	}

	static function validatePackageGraph(bootstrap:ProjectBootstrap, lock:Dynamic):Void {
		final graph = ProjectContract.fieldObject(lock, "packageGraph", "project lock");
		ProjectContract.exactFields(graph, ["manager", "version", "manifest", "lockfile", "lifecycleScriptsAllowed"], "project lock.packageGraph",
			"profile-resolution");
		ProjectContract.expect(ProjectContract.string(graph, "manager", "project package graph", "profile-resolution"), "npm", "project package manager",
			"profile-resolution");
		ProjectContract.expect(ProjectContract.string(graph, "version", "project package graph", "profile-resolution"), "10.9.2", "project npm version",
			"profile-resolution");
		if (ProjectContract.boolean(graph, "lifecycleScriptsAllowed", "project package graph", "profile-resolution")) {
			throw new CliFailure("WPHX1017", "ordinary build/check/dev forbids npm lifecycle scripts in the locked graph", 3, "profile-resolution",
				bootstrap.lockPath, ["Regenerate the lock with lifecycleScriptsAllowed=false."]);
		}
		for (field => expectedPath in [
			"manifest" => bootstrap.packageManifestPath,
			"lockfile" => bootstrap.packageLockPath
		]) {
			final record = ProjectContract.fieldObject(graph, field, "project package graph");
			ProjectContract.exactFields(record, ["path", "sha256"], "project package graph." + field, "profile-resolution");
			final path = ProjectContract.relativePath(ProjectContract.string(record, "path", "project package graph", "profile-resolution"),
				"project package graph path");
			ProjectContract.expect(path, expectedPath, "project package graph " + field + " path", "profile-resolution");
			final actual = OwnershipJson.digest(ProjectFiles.read(bootstrap.root, path, "locked package file", "profile-resolution"));
			ProjectContract.expect(ProjectContract.string(record, "sha256", "project package graph", "profile-resolution"), actual,
				"project package graph " + field + " digest", "profile-resolution");
		}
	}

	static function parseStrict(buffer:Buffer, label:String, stage:String):Dynamic {
		try {
			return ProjectJson.parseStrict(buffer, label);
		} catch (failure:OwnershipFailure) {
			throw new CliFailure("WPHX1002", failure.message, 3, stage, label, ["Fix the closed JSON document and retry."]);
		}
	}

	static function parseCanonical(buffer:Buffer, label:String, stage:String):Dynamic {
		try {
			return OwnershipJson.parseCanonical(buffer, label);
		} catch (failure:OwnershipFailure) {
			throw new CliFailure("WPHX1011", failure.message, 3, stage, label,
				["Regenerate the exact lock with the explicit lock command; do not hand-edit it."]);
		}
	}
}
