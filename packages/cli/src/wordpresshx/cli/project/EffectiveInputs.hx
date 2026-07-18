package wordpresshx.cli.project;

import js.Syntax;
import js.node.Buffer;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Deterministic discovery graph shared by bounded builds and the later watcher. **/
class EffectiveInputs {
	static final COMPATIBILITY_COMPONENTS = [
		"compiler.genes",
		"compiler.haxe",
		"compiler.reflaxe-php",
		"sdk.wordpress-hx",
		"tool.lix"
	];

	public static function build(bootstrap:ProjectBootstrap, lock:Dynamic, lockBytes:Buffer):Dynamic {
		final resolvedEnvironment = resolveBuildEnvironment(bootstrap.config);
		final records:Array<Dynamic> = [];
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
		records.sort((left, right) -> Reflect.compare(Reflect.field(left, "path"), Reflect.field(right, "path")));

		final components = ProjectContract.array(lock, "components", "project lock", "profile-resolution");
		final componentById = new Map<String, Dynamic>();
		final toolchain:Array<Dynamic> = [];
		for (component in components) {
			final id = ProjectContract.string(component, "id", "project lock component", "profile-resolution");
			componentById.set(id, component);
			toolchain.push(object([
				"id" => id,
				"identity" => ProjectContract.string(component, "identity", "project lock component", "profile-resolution"),
				"lockEntrySha256" => ProjectContract.string(component, "lockEntrySha256", "project lock component", "profile-resolution")
			]));
		}
		toolchain.sort((left, right) -> Reflect.compare(Reflect.field(left, "id"), Reflect.field(right, "id")));

		final projectLock = ProjectContract.fieldObject(lock, "project", "project lock");
		final compatibilityTools:Array<Dynamic> = [];
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
		rootExcludes.sort(Reflect.compare);
		final discoveryRoots:Array<Dynamic> = [
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
		discoveryRoots.sort((left, right) -> Reflect.compare(Reflect.field(left, "path"), Reflect.field(right, "path")));
		for (index in 1...discoveryRoots.length) {
			if (Reflect.field(discoveryRoots[index - 1], "path") == Reflect.field(discoveryRoots[index], "path")) {
				throw new CliFailure("WPHX1021", "configured discovery roots overlap roles: " + Reflect.field(discoveryRoots[index], "path"), 3,
					"configuration", cast Reflect.field(discoveryRoots[index], "path"),
					["Give source, test, and asset roots distinct project-relative paths."]);
			}
		}
		final watchRoots = [for (root in discoveryRoots) cast(Reflect.field(root, "path"), String)];
		sortUnique(watchRoots, "watch roots");

		final runtimeDeclarations = ProjectContract.array(ProjectContract.fieldObject(bootstrap.config, "environment", "project configuration"), "runtime",
			"project environment");
		final runtimeExcluded = [
			for (declaration in runtimeDeclarations)
				ProjectContract.string(declaration, "name", "runtime environment declaration")
		];
		runtimeExcluded.sort(Reflect.compare);
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
				"compatibilityDigestAlgorithm" => "sha256-project-lock-config-compiler-and-build-env-v1",
				"compatibilityDigest" => OwnershipJson.digestValue(compatibilityPayload),
				"compatibilityComponents" => COMPATIBILITY_COMPONENTS,
				"restartFileRoles" => [
					"haxe-config",
					"hxml",
					"package-lock",
					"package-manifest",
					"project-config",
					"project-lock"
				],
				"directBuildDefault" => true
			])
		]);
		final fingerprintMaterial = OwnershipJson.clone(document);
		Reflect.deleteField(fingerprintMaterial, "fingerprint");
		Reflect.setField(document, "fingerprint", OwnershipJson.digestValue(fingerprintMaterial));
		return document;
	}

	static function resolveBuildEnvironment(config:Dynamic):Array<Dynamic> {
		final declarations = ProjectContract.array(ProjectContract.fieldObject(config, "environment", "project configuration"), "build", "project environment");
		final result:Array<Dynamic> = [];
		for (declaration in declarations) {
			final name = ProjectContract.string(declaration, "name", "build environment declaration");
			final processValue:Dynamic = Syntax.code("process.env[{0}]", name);
			var value:String;
			var source:String;
			if (processValue != null) {
				value = cast processValue;
				source = "process";
			} else if (Reflect.hasField(declaration, "default")) {
				value = cast Reflect.field(declaration, "default");
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

	static function addFile(records:Array<Dynamic>, seen:Map<String, Bool>, bootstrap:ProjectBootstrap, path:String, role:String, targets:Array<String>):Void {
		final collision = path.toLowerCase();
		if (seen.exists(collision)) {
			throw new CliFailure("WPHX1023", "duplicate or case-colliding effective input: " + path, 3, "configuration", path,
				["Use one portable spelling for every effective input path."]);
		}
		seen.set(collision, true);
		final bytes = ProjectFiles.read(bootstrap.root, path, "effective input");
		targets.sort(Reflect.compare);
		records.push(object([
			"path" => path,
			"sha256" => OwnershipJson.digest(bytes),
			"byteLength" => bytes.length,
			"role" => role,
			"targets" => targets
		]));
	}

	static function object(fields:Map<String, Dynamic>):Dynamic {
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
		values.sort(Reflect.compare);
		return values;
	}

	static function sortUnique(values:Array<String>, label:String):Void {
		values.sort(Reflect.compare);
		for (index in 1...values.length) {
			if (values[index - 1] == values[index]) {
				throw new CliFailure("WPHX1023", label + " contain a duplicate path: " + values[index], 3, "configuration", values[index]);
			}
		}
	}
}
