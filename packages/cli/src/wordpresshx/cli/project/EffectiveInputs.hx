package wordpresshx.cli.project;

import js.Syntax;
import js.node.Buffer;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;
import wordpresshx.cli.project.ProjectJson.ProjectJsonField;

/** Deterministic discovery graph shared by bounded builds and the later watcher. **/
class EffectiveInputs {
	static final COMPATIBILITY_COMPONENTS = [
		"compiler.genes",
		"compiler.haxe",
		"compiler.reflaxe-php",
		"sdk.wordpress-hx",
		"tool.lix"
	];
	static final RESTART_FILE_ROLES = [
		"haxe-config",
		"hxml",
		"package-lock",
		"package-manifest",
		"project-config",
		"project-lock"
	];

	public static function build(bootstrap:ProjectBootstrap, lock:JsonValue, lockBytes:Buffer):JsonValue {
		final resolvedEnvironment = resolveBuildEnvironment(bootstrap.config);
		final records:Array<JsonValue> = [];
		final seen = new Map<String, Bool>();
		addFile(records, seen, bootstrap, ".haxerc", "haxe-config", ["browser", "metadata", "php", "plan"]);
		final hxmlFiles = ProjectFiles.discover(bootstrap.root, ".wphx/bootstrap", [".hxml"], "Haxe bootstrap root");
		if (hxmlFiles.indexOf(".wphx/bootstrap/project.hxml") < 0) {
			throw new CliFailure("WPHX1020", "generated .wphx/bootstrap/project.hxml is missing", 3, "configuration", ".wphx/bootstrap/project.hxml",
				["Regenerate the project bootstrap with the exact CLI version."]);
		}
		for (path in hxmlFiles) {
			addFile(records, seen, bootstrap, path, "hxml", ["browser", "metadata", "php", "plan"]);
		}
		addFile(records, seen, bootstrap, bootstrap.lockPath, "project-lock", ["assets", "browser", "metadata", "php", "plan", "services", "test"]);
		addFile(records, seen, bootstrap, bootstrap.packageManifestPath, "package-manifest", ["assets", "browser", "services"]);
		addFile(records, seen, bootstrap, bootstrap.packageLockPath, "package-lock", ["assets", "browser", "services"]);
		addFile(records, seen, bootstrap, "wordpress-hx.json", "project-config", ["assets", "browser", "metadata", "php", "plan", "services", "test"]);

		for (root in bootstrap.sourceRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, [".hx", ".hxx"], "source root")) {
				addFile(records, seen, bootstrap, path, "haxe-source", ["browser", "metadata", "php", "plan", "services"]);
			}
		}
		for (root in bootstrap.testRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, [".hx", ".hxx"], "test root")) {
				addFile(records, seen, bootstrap, path, "haxe-source", ["test"]);
			}
		}
		for (root in bootstrap.assetRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, null, "asset root")) {
				addFile(records, seen, bootstrap, path, "asset", ["assets"]);
			}
		}
		records.sort((left,
				right) -> ProjectJson.compareText(ProjectContract.string(left, "path", "effective input"),
				ProjectContract.string(right, "path", "effective input")));

		final components = ProjectContract.array(lock, "components", "project lock", "profile-resolution");
		final componentById = new Map<String, JsonValue>();
		final toolchain:Array<JsonValue> = [];
		for (component in components) {
			final id = ProjectContract.string(component, "id", "project lock component", "profile-resolution");
			componentById.set(id, component);
			toolchain.push(object([
				"id" => id,
				"identity" => ProjectContract.string(component, "identity", "project lock component", "profile-resolution"),
				"lockEntrySha256" => ProjectContract.string(component, "lockEntrySha256", "project lock component", "profile-resolution")
			]));
		}
		toolchain.sort((left,
				right) -> ProjectJson.compareText(ProjectContract.string(left, "id", "effective tool"), ProjectContract.string(right, "id", "effective tool")));

		final projectLock = ProjectContract.fieldObject(lock, "project", "project lock");
		final compatibilityFiles:Array<JsonValue> = [];
		for (record in records) {
			final role = ProjectContract.string(record, "role", "effective input");
			if (RESTART_FILE_ROLES.indexOf(role) >= 0) {
				compatibilityFiles.push(object([
					"path" => ProjectContract.string(record, "path", "effective input"),
					"role" => role,
					"sha256" => ProjectContract.string(record, "sha256", "effective input")
				]));
			}
		}
		final compatibilityTools:Array<JsonValue> = [];
		for (id in COMPATIBILITY_COMPONENTS) {
			final component = componentById.get(id);
			compatibilityTools.push(object([
				"id" => id,
				"identity" => ProjectContract.string(component, "identity", "project lock component", "profile-resolution"),
				"lockEntrySha256" => ProjectContract.string(component, "lockEntrySha256", "project lock component", "profile-resolution")
			]));
		}
		final compatibilityPayload = object([
			"projectId" => ProjectContract.string(bootstrap.config, "projectId", "project configuration"),
			"configSemanticSha256" => ProjectContract.string(projectLock, "configSemanticSha256", "project lock.project", "profile-resolution"),
			"lockDigest" => ProjectContract.string(lock, "lockDigest", "project lock", "profile-resolution"),
			"components" => compatibilityTools,
			"restartFiles" => compatibilityFiles,
			"buildEnvironment" => resolvedEnvironment
		]);

		final ignoredRoots = [
			".git",
			bootstrap.stateRoot + "/runtime",
			bootstrap.stateRoot + "/transactions",
			bootstrap.distributionRoot,
			"node_modules"
		];
		for (outputRoot in collapsedOutputRoots(bootstrap.outputRoots)) {
			ignoredRoots.push(outputRoot);
		}
		sortUnique(ignoredRoots, "ignored roots");
		final rootExcludes = [for (root in ignoredRoots) root + "/**"];
		rootExcludes.sort(ProjectJson.compareText);
		final discoveryRoots:Array<JsonValue> = [
			object([
				"path" => ".",
				"includes" => sorted([
					".haxerc",
					bootstrap.packageLockPath,
					bootstrap.packageManifestPath,
					"wordpress-hx.json"
				]),
				"excludes" => rootExcludes,
				"targets" => ["assets", "browser", "metadata", "php", "plan", "services"]
			]),
			object([
				"path" => ".wphx/bootstrap",
				"includes" => ["**/*.hxml"],
				"excludes" => [],
				"targets" => ["browser", "metadata", "php", "plan"]
			])
		];
		for (root in bootstrap.assetRoots) {
			discoveryRoots.push(object([
				"path" => root,
				"includes" => ["**/*"],
				"excludes" => [],
				"targets" => ["assets"]
			]));
		}
		for (root in bootstrap.sourceRoots) {
			discoveryRoots.push(object([
				"path" => root,
				"includes" => ["**/*.hx", "**/*.hxx"],
				"excludes" => [],
				"targets" => ["browser", "metadata", "php", "plan", "services"]
			]));
		}
		for (root in bootstrap.testRoots) {
			discoveryRoots.push(object([
				"path" => root,
				"includes" => ["**/*.hx", "**/*.hxx"],
				"excludes" => [],
				"targets" => ["test"]
			]));
		}
		discoveryRoots.sort((left,
				right) -> ProjectJson.compareText(ProjectContract.string(left, "path", "discovery root"), ProjectContract.string(right, "path",
				"discovery root")));
		for (index in 1...discoveryRoots.length) {
			final path = ProjectContract.string(discoveryRoots[index], "path", "discovery root");
			if (ProjectContract.string(discoveryRoots[index - 1], "path", "discovery root") == path) {
				throw new CliFailure("WPHX1021", "configured discovery roots overlap roles: " + path, 3, "configuration", path,
					["Give source, test, and asset roots distinct project-relative paths."]);
			}
		}
		final watchRoots = [
			for (root in discoveryRoots)
				ProjectContract.string(root, "path", "discovery root")
		];
		sortUnique(watchRoots, "watch roots");

		final runtimeDeclarations = ProjectContract.array(ProjectContract.fieldObject(bootstrap.config, "environment", "project configuration"), "runtime",
			"project environment");
		final runtimeExcluded = [
			for (declaration in runtimeDeclarations)
				ProjectContract.string(declaration, "name", "runtime environment declaration")
		];
		runtimeExcluded.sort(ProjectJson.compareText);
		final profile = OwnershipJson.clone(ProjectContract.fieldObject(lock, "profile", "project lock"));
		final document = object([
			"schema" => "wordpress-hx.effective-inputs.v1",
			"canonicalization" => "wordpress-hx.canonical-json.v1",
			"fingerprintAlgorithm" => "sha256-canonical-json-without-fingerprint-v1",
			"fingerprint" => StringTools.lpad("", "0", 64),
			"project" => object([
				"id" => ProjectContract.string(bootstrap.config, "projectId", "project configuration"),
				"configPath" => ProjectContract.string(projectLock, "configPath", "project lock.project", "profile-resolution"),
				"configSemanticSha256" => ProjectContract.string(projectLock, "configSemanticSha256", "project lock.project", "profile-resolution"),
				"lockPath" => bootstrap.lockPath,
				"lockFileSha256" => OwnershipJson.digest(lockBytes),
				"lockDigest" => ProjectContract.string(lock, "lockDigest", "project lock", "profile-resolution")
			]),
			"profile" => profile,
			"files" => records,
			"discoveryRoots" => discoveryRoots,
			"watchRoots" => watchRoots,
			"ignoredRoots" => ignoredRoots,
			"toolchain" => toolchain,
			"environment" => object(["build" => resolvedEnvironment, "runtimeExcluded" => runtimeExcluded]),
			"compileServer" => object([
				"policy" => "project-isolated-compatible-attach-v1",
				"compatibilityDigestAlgorithm" => "sha256-project-lock-config-compiler-inputs-and-build-env-v2",
				"compatibilityDigest" => OwnershipJson.digestValue(compatibilityPayload),
				"compatibilityComponents" => COMPATIBILITY_COMPONENTS,
				"restartFileRoles" => RESTART_FILE_ROLES,
				"directBuildDefault" => true
			])
		]);
		final fingerprintMaterial = OwnershipJson.withoutField(document, "fingerprint");
		return OwnershipJson.setField(document, "fingerprint", OwnershipJson.text(OwnershipJson.digestValue(fingerprintMaterial)));
	}

	static function resolveBuildEnvironment(config:JsonValue):Array<JsonValue> {
		final declarations = ProjectContract.array(ProjectContract.fieldObject(config, "environment", "project configuration"), "build", "project environment");
		final result:Array<JsonValue> = [];
		for (declaration in declarations) {
			final name = ProjectContract.string(declaration, "name", "build environment declaration");
			final processValue:Null<String> = Syntax.code("process.env[{0}]", name);
			var value:String;
			var source:String;
			if (processValue != null) {
				value = processValue;
				source = "process";
			} else if (ProjectContract.has(declaration, "default", "build environment declaration")) {
				final configuredDefault = ProjectContract.optionalString(declaration, "default", "build environment declaration");
				value = configuredDefault == null ? "" : configuredDefault;
				source = "default";
			} else if (ProjectContract.boolean(declaration, "required", "build environment declaration")) {
				throw new CliFailure("WPHX1022", "required public build environment input is missing: " + name, 3, "configuration", null, [
					"Set " + name + " for the build or add a reviewed default to the project bootstrap."
				]);
			} else {
				value = "";
				source = "default";
			}
			result.push(object([
				"name" => name,
				"source" => source,
				"valueSha256" => OwnershipJson.digest(Buffer.from(value, "utf8"))
			]));
		}
		return result;
	}

	static function addFile(records:Array<JsonValue>, seen:Map<String, Bool>, bootstrap:ProjectBootstrap, path:String, role:String,
			targets:Array<String>):Void {
		final collision = path.toLowerCase();
		if (seen.exists(collision)) {
			throw new CliFailure("WPHX1023", "duplicate or case-colliding effective input: " + path, 3, "configuration", path,
				["Use one portable spelling for every effective input path."]);
		}
		seen.set(collision, true);
		final bytes = ProjectFiles.read(bootstrap.root, path, "effective input");
		targets.sort(ProjectJson.compareText);
		records.push(object([
			"path" => path,
			"sha256" => OwnershipJson.digest(bytes),
			"byteLength" => bytes.length,
			"role" => role,
			"targets" => targets
		]));
	}

	static function object(fields:Map<String, ProjectJsonField>):JsonValue {
		return OwnershipJson.object(fields);
	}

	static function collapsedOutputRoots(roots:Array<ProjectOutputRoot>):Array<String> {
		if (roots.length == 1) {
			return [roots[0].path];
		}
		final first = roots[0].path.split("/");
		var commonLength = first.length;
		for (index in 1...roots.length) {
			final candidate = roots[index].path.split("/");
			commonLength = Std.int(Math.min(commonLength, candidate.length));
			var offset = 0;
			while (offset < commonLength && first[offset] == candidate[offset]) {
				offset++;
			}
			commonLength = offset;
		}
		if (commonLength > 0) {
			return [first.slice(0, commonLength).join("/")];
		}
		return [for (root in roots) root.path];
	}

	static function sorted(values:Array<String>):Array<String> {
		values.sort(ProjectJson.compareText);
		return values;
	}

	static function sortUnique(values:Array<String>, label:String):Void {
		values.sort(ProjectJson.compareText);
		for (index in 1...values.length) {
			if (values[index - 1] == values[index]) {
				throw new CliFailure("WPHX1023", label + " contain a duplicate path: " + values[index], 3, "configuration", values[index]);
			}
		}
	}
}
