package wordpress.hx.compiler.php.profile;

import haxe.Json;

typedef WordPressPluginManifestSource = {
	final file:String;
	final startLine:Int;
	final startColumn:Int;
	final endLine:Int;
	final endColumn:Int;
}

typedef WordPressPluginManifestDeclaration = {
	final stableName:String;
	final source:WordPressPluginManifestSource;
	final generatedStartLine:Int;
	final generatedEndLine:Int;
}

typedef WordPressPluginManifestFile = {
	final path:String;
	final role:String;
	final classification:String;
	final bytes:Int;
	final sha256:String;
	final declarations:Array<WordPressPluginManifestDeclaration>;
}

typedef WordPressPluginManifest = {
	final schemaVersion:Int;
	final manifestId:String;
	final schemaStatus:String;
	final profileId:String;
	final classification:String;
	final plugin:{
		final slug:String;
		final rootPath:String;
		final textDomain:String;
		final requiresWordPress:String;
		final requiresPhp:String;
		final bootstrapClass:String;
		final autoloadPath:String;
	};
	final files:Array<WordPressPluginManifestFile>;
	final boundary:{
		final semanticPlanClassification:String;
		final semanticPlanSchema:String;
		final ownershipTransaction:String;
		final rawPhpSegments:Int;
		final stockHaxePhpFiles:Int;
		final buildTimeServerDependency:Bool;
		final runtimeHxxDependency:Bool;
	};
	final claims:{
		final generation:String;
		final wordpress70Activation:String;
		final productionSupport:String;
		final publicationAuthorized:Bool;
	};
}

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
		values.sort((left, right) -> compareText(left.path, right.path));
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
		return Json.stringify(manifest(), null, "  ") + "\n";
	}

	public function manifest():WordPressPluginManifest {
		final fileRecords:Array<WordPressPluginManifestFile> = [];
		for (file in fileValues) {
			final declarations:Array<WordPressPluginManifestDeclaration> = [];
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

		return {
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
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
