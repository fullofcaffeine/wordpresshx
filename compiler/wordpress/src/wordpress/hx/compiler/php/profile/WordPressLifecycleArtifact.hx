package wordpress.hx.compiler.php.profile;

import haxe.Json;

typedef WordPressLifecycleManifestFile = {
	final path:String;
	final role:String;
	final bytes:Int;
	final sha256:String;
}

typedef WordPressLifecycleManifestStep = {
	final fromVersion:Int;
	final toVersion:Int;
}

typedef WordPressLifecycleManifest = {
	final schemaVersion:Int;
	final manifestId:String;
	final profileId:String;
	final packageKind:String;
	final plugin:{
		final slug:String;
		final rootPath:String;
		final requiresWordPress:String;
		final requiresPhp:String;
	};
	final lifecycle:{
		final className:String;
		final schemaOption:String;
		final targetSchemaVersion:Int;
		final activationHook:Bool;
		final deactivationHook:Bool;
		final upgradeHook:String;
		final steps:Array<WordPressLifecycleManifestStep>;
		final retryPolicy:String;
		final uninstallPolicy:String;
		final uninstallOptions:Array<String>;
	};
	final files:Array<WordPressLifecycleManifestFile>;
	final claims:{
		final generation:String;
		final wordpress70Runtime:String;
		final phpFloorRuntime:String;
		final publicationAuthorized:Bool;
	};
}

/** Deterministic SDK-051 lifecycle package and evidence manifest. */
class WordPressLifecycleArtifact {
	public final plan:WordPressPluginLifecyclePlan;

	final fileValues:Array<WordPressLifecycleFile>;

	public var files(get, never):Array<WordPressLifecycleFile>;

	public function new(plan:WordPressPluginLifecyclePlan, files:Array<WordPressLifecycleFile>) {
		if (plan == null || files == null) {
			throw "WordPress lifecycle artifact requires plan and files";
		}
		final values = files.copy();
		values.sort((left, right) -> left.path < right.path ? -1 : left.path > right.path ? 1 : 0);
		final expected:Map<String, String> = [
			"plugin-root" => plan.rootPath,
			"autoload" => plan.autoloadPath,
			"bootstrap" => plan.bootstrapPath,
			"lifecycle" => plan.lifecyclePath
		];
		if (plan.uninstallPath != null) {
			expected.set("uninstall", plan.uninstallPath);
		}
		final roles:Map<String, Bool> = [];
		final paths:Map<String, Bool> = [];
		for (file in values) {
			if (file == null || roles.exists(file.role) || paths.exists(file.path)) {
				throw "WordPress lifecycle artifact roles and paths must be unique";
			}
			if (expected.get(file.role) != file.path) {
				throw "WordPress lifecycle role/path mismatch: " + file.role + " -> " + file.path;
			}
			roles.set(file.role, true);
			paths.set(file.path, true);
		}
		if (values.length != Lambda.count(expected)) {
			throw "WordPress lifecycle artifact file count differs from its package kind";
		}
		for (role in expected.keys()) {
			if (!roles.exists(role)) {
				throw "WordPress lifecycle artifact is missing role: " + role;
			}
		}
		this.plan = plan;
		this.fileValues = values;
	}

	public function file(path:String):WordPressLifecycleFile {
		for (file in fileValues) {
			if (file.path == path) {
				return file;
			}
		}
		throw "Unknown WordPress lifecycle artifact path: " + path;
	}

	public function manifestSource():String {
		return Json.stringify(manifest(), null, "  ") + "\n";
	}

	public function manifest():WordPressLifecycleManifest {
		final files:Array<WordPressLifecycleManifestFile> = [];
		for (file in fileValues) {
			files.push({
				path: file.path,
				role: file.role,
				bytes: file.byteLength,
				sha256: file.sha256
			});
		}
		final steps:Array<WordPressLifecycleManifestStep> = [];
		for (step in plan.upgradeSteps) {
			steps.push({fromVersion: step.fromVersion, toVersion: step.toVersion});
		}
		final standard = plan.installKind == StandardPlugin;
		return {
			schemaVersion: 1,
			manifestId: "wordpresshx-plugin-lifecycle-v1",
			profileId: plan.plugin.profileId,
			packageKind: standard ? "standard-plugin" : "must-use-plugin",
			plugin: {
				slug: plan.plugin.slug,
				rootPath: plan.rootPath,
				requiresWordPress: plan.plugin.header.requiresWordPress,
				requiresPhp: plan.plugin.header.requiresPhp
			},
			lifecycle: {
				className: plan.absoluteLifecycleClass,
				schemaOption: plan.schemaOption,
				targetSchemaVersion: plan.targetSchemaVersion,
				activationHook: standard,
				deactivationHook: standard,
				upgradeHook: "plugins_loaded",
				steps: steps,
				retryPolicy: "checkpoint-after-each-successful-contiguous-step",
				uninstallPolicy: switch (plan.uninstallPolicy) {
					case RetainPluginData: "retain-declared-data";
					case DeleteDeclaredPluginData: "delete-declared-options";
				},
				uninstallOptions: plan.uninstallOptions
			},
			files: files,
			claims: {
				generation: "generated",
				wordpress70Runtime: "not-tested",
				phpFloorRuntime: "not-tested",
				publicationAuthorized: false
			}
		};
	}

	function get_files():Array<WordPressLifecycleFile> {
		return fileValues.copy();
	}
}
