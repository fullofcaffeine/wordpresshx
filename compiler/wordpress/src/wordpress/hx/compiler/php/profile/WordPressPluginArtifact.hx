package wordpress.hx.compiler.php.profile;

import haxe.Json;

/** Deterministic in-memory public PHP artifact and provenance manifest. **/
class WordPressPluginArtifact {
	public final plan:PluginBootstrapPlan;

	final fileValues:Array<WordPressPluginFile>;

	public var files(get, never):Array<WordPressPluginFile>;

	public function new(plan:PluginBootstrapPlan, files:Array<WordPressPluginFile>) {
		if (plan == null || files == null) {
			throw "WordPress plugin artifact requires a plan and files";
		}
		final values = files.copy();
		values.sort((left, right) -> Reflect.compare(left.path, right.path));
		final paths:Map<String, Bool> = [];
		final roles:Map<String, Bool> = [];
		for (file in values) {
			if (file == null || paths.exists(file.path) || roles.exists(file.role)) {
				throw "WordPress plugin artifact file paths and roles must be unique";
			}
			paths.set(file.path, true);
			roles.set(file.role, true);
		}
		for (requiredPath in [plan.rootPath, plan.autoloadPath, plan.bootstrapPath]) {
			if (!paths.exists(requiredPath)) {
				throw "WordPress plugin artifact is missing: " + requiredPath;
			}
		}
		for (requiredRole in ["plugin-root", "autoload", "bootstrap"]) {
			if (!roles.exists(requiredRole)) {
				throw "WordPress plugin artifact is missing role: " + requiredRole;
			}
		}
		final expectedPaths = [
			"plugin-root" => plan.rootPath,
			"autoload" => plan.autoloadPath,
			"bootstrap" => plan.bootstrapPath
		];
		for (file in values) {
			if (expectedPaths.get(file.role) != file.path) {
				throw "WordPress plugin artifact role/path mismatch: " + file.role + " -> " + file.path;
			}
		}
		if (values.length != 3) {
			throw "SDK-022 bootstrap artifact must contain exactly three PHP files";
		}
		this.plan = plan;
		this.fileValues = values;
	}

	function get_files():Array<WordPressPluginFile> {
		return fileValues.copy();
	}

	public function file(path:String):WordPressPluginFile {
		for (file in fileValues) {
			if (file.path == path) {
				return file;
			}
		}
		throw "Unknown WordPress plugin artifact path: " + path;
	}

	public function manifestSource():String {
		final fileRecords:Array<Dynamic> = [];
		for (file in fileValues) {
			final declarations:Array<Dynamic> = [];
			for (declaration in file.rendered) {
				declarations.push({
					stableName: declaration.stableName,
					source: {
						file: declaration.source.file,
						startLine: declaration.source.startLine,
						startColumn: declaration.source.startColumn,
						endLine: declaration.source.endLine,
						endColumn: declaration.source.endColumn
					},
					generatedStartLine: declaration.generatedStartLine,
					generatedEndLine: declaration.generatedEndLine
				});
			}
			fileRecords.push({
				path: file.path,
				role: file.role,
				classification: file.classification,
				bytes: file.byteLength,
				sha256: file.sha256,
				declarations: declarations
			});
		}

		final manifest:Dynamic = {
			schemaVersion: 1,
			manifestId: "wordpresshx-public-php-artifact-v1",
			schemaStatus: "internal-sdk022-evidence",
			profileId: plan.profileId,
			classification: "public-native",
			plugin: {
				slug: plan.slug,
				rootPath: plan.rootPath,
				textDomain: plan.header.textDomain,
				requiresWordPress: plan.header.requiresWordPress,
				requiresPhp: plan.header.requiresPhp,
				bootstrapClass: plan.absoluteBootstrapClass,
				autoloadPath: plan.autoloadPath
			},
			files: fileRecords,
			boundary: {
				semanticPlanClassification: "file-symbol-edge",
				semanticPlanSchema: "not-implemented-adr-006",
				ownershipTransaction: "not-implemented-adr-007",
				rawPhpSegments: 0,
				stockHaxePhpFiles: 0,
				buildTimeServerDependency: false,
				runtimeHxxDependency: false
			},
			claims: {
				generation: "generated",
				wordpress70Activation: "not-tested",
				productionSupport: "not-tested",
				publicationAuthorized: false
			}
		};
		return Json.stringify(manifest, null, "  ") + "\n";
	}
}
