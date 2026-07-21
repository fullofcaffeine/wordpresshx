package wordpress.hx.compiler.php.profile;

import haxe.Json;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpVisibility;
import wordpress.hx.compiler.php.profile.WordPressRestMethod.WordPressRestMethodTools;

typedef WordPressPublicAdapterManifestSource = {
	final file:String;
	final startLine:Int;
	final startColumn:Int;
	final endLine:Int;
	final endColumn:Int;
}

typedef WordPressPublicAdapterManifestDeclaration = {
	final stableName:String;
	final source:WordPressPublicAdapterManifestSource;
	final generatedStartLine:Int;
	final generatedEndLine:Int;
}

typedef WordPressPublicAdapterManifestFile = {
	final path:String;
	final role:String;
	final classification:String;
	final bytes:Int;
	final sha256:String;
	final declarations:Array<WordPressPublicAdapterManifestDeclaration>;
}

typedef WordPressPublicAdapterManifestHook = {
	final kind:String;
	final hook:String;
	final callback:String;
	final priority:Int;
	final acceptedArgs:Int;
}

typedef WordPressPublicAdapterManifestRoute = {
	final namespace:String;
	final route:String;
	final method:String;
	final callback:String;
	final permissionCallback:String;
}

typedef WordPressPublicAdapterManifestBlock = {
	final name:String;
	final renderCallback:String;
}

typedef WordPressPublicAdapterManifestParameter = {
	final name:String;
	final type:String;
	final byReference:Bool;
	final variadic:Bool;
	final hasDefault:Bool;
}

typedef WordPressPublicAdapterManifestExport = {
	final stableName:String;
	final parameters:Array<WordPressPublicAdapterManifestParameter>;
	final returnsByReference:Bool;
	final returnType:String;
}

typedef WordPressPublicAdapterManifest = {
	final schemaVersion:Int;
	final manifestId:String;
	final schemaStatus:String;
	final profileId:String;
	final classification:String;
	final plugin:{
		final slug:String;
		final rootPath:String;
		final adapterClass:String;
		final adapterPath:String;
		final registrationPath:String;
	};
	final files:Array<WordPressPublicAdapterManifestFile>;
	final hooks:Array<WordPressPublicAdapterManifestHook>;
	final restRoutes:Array<WordPressPublicAdapterManifestRoute>;
	final blocks:Array<WordPressPublicAdapterManifestBlock>;
	final publicExports:Array<WordPressPublicAdapterManifestExport>;
	final boundary:{
		final semanticPlanClassification:String;
		final semanticPlanSchema:String;
		final ownershipTransaction:String;
		final rawPhpSegments:Int;
		final stockHaxePhpFiles:Int;
		final buildTimeServerDependency:Bool;
		final runtimeHxxDependency:Bool;
		final privateImplementationMethods:Int;
	};
	final claims:{
		final generation:String;
		final wordpress70Runtime:String;
		final productionSupport:String;
		final publicationAuthorized:Bool;
	};
}

/** Deterministic SDK-023 public adapter artifact and ABI evidence manifest. **/
class WordPressPublicAdapterArtifact {
	public final plan:WordPressPublicAdapterPlan;

	final fileValues:Array<WordPressPublicAdapterFile>;

	public var files(get, never):Array<WordPressPublicAdapterFile>;

	public function new(plan:WordPressPublicAdapterPlan, files:Array<WordPressPublicAdapterFile>) {
		if (plan == null || files == null) {
			throw "WordPress public adapter artifact requires plan and files";
		}
		final values = files.copy();
		values.sort((left, right) -> compareText(left.path, right.path));
		final expected = [
			"plugin-root" => plan.plugin.rootPath,
			"autoload" => plan.plugin.autoloadPath,
			"bootstrap" => plan.plugin.bootstrapPath,
			"adapter-class" => plan.adapterPath,
			"registrations" => plan.registrationPath
		];
		final paths:Map<String, Bool> = [];
		final roles:Map<String, Bool> = [];
		for (file in values) {
			if (file == null || paths.exists(file.path) || roles.exists(file.role)) {
				throw "WordPress public adapter file paths and roles must be unique";
			}
			if (expected.get(file.role) != file.path) {
				throw "WordPress public adapter role/path mismatch: " + file.role + " -> " + file.path;
			}
			paths.set(file.path, true);
			roles.set(file.role, true);
		}
		if (values.length != 5 || Lambda.count(expected) != Lambda.count(roles)) {
			throw "SDK-023 public adapter artifact must contain exactly five role-bound PHP files";
		}
		for (role in expected.keys()) {
			if (!roles.exists(role)) {
				throw "WordPress public adapter artifact is missing role: " + role;
			}
		}
		this.plan = plan;
		this.fileValues = values;
	}

	public function file(path:String):WordPressPublicAdapterFile {
		for (file in fileValues) {
			if (file.path == path) {
				return file;
			}
		}
		throw "Unknown WordPress public adapter artifact path: " + path;
	}

	public function manifestSource():String {
		return Json.stringify(manifest(), null, "  ") + "\n";
	}

	public function manifest():WordPressPublicAdapterManifest {
		final fileRecords:Array<WordPressPublicAdapterManifestFile> = [];
		for (file in fileValues) {
			final declarations:Array<WordPressPublicAdapterManifestDeclaration> = [];
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

		final hookRecords:Array<WordPressPublicAdapterManifestHook> = [];
		for (hook in plan.hooks) {
			hookRecords.push({
				kind: hook.kind == Action ? "action" : "filter",
				hook: hook.hookName,
				callback: plan.absoluteAdapterClass + "::" + hook.callback.value,
				priority: hook.priority,
				acceptedArgs: hook.acceptedArgs
			});
		}
		final routeRecords:Array<WordPressPublicAdapterManifestRoute> = [];
		for (route in plan.restRoutes) {
			routeRecords.push({
				namespace: route.namespace,
				route: route.route,
				method: WordPressRestMethodTools.constantName(route.method),
				callback: plan.absoluteAdapterClass + "::" + route.callback.value,
				permissionCallback: plan.absoluteAdapterClass + "::" + route.permissionCallback.value
			});
		}
		final blockRecords:Array<WordPressPublicAdapterManifestBlock> = [];
		for (block in plan.blocks) {
			blockRecords.push({
				name: block.blockName,
				renderCallback: plan.absoluteAdapterClass + "::" + block.renderCallback.value
			});
		}
		final exportRecords:Array<WordPressPublicAdapterManifestExport> = [];
		for (export in plan.exports) {
			final method = plan.method(export.method);
			exportRecords.push(exportRecord(plan, method));
		}

		return {
			schemaVersion: 1,
			manifestId: "wordpresshx-public-php-adapters-v1",
			schemaStatus: "internal-sdk023-evidence",
			profileId: plan.plugin.profileId,
			classification: "public-native",
			plugin: {
				slug: plan.plugin.slug,
				rootPath: plan.plugin.rootPath,
				adapterClass: plan.absoluteAdapterClass,
				adapterPath: plan.adapterPath,
				registrationPath: plan.registrationPath
			},
			files: fileRecords,
			hooks: hookRecords,
			restRoutes: routeRecords,
			blocks: blockRecords,
			publicExports: exportRecords,
			boundary: {
				semanticPlanClassification: "file-symbol-edge",
				semanticPlanSchema: "not-implemented-adr-006",
				ownershipTransaction: "not-implemented-adr-007",
				rawPhpSegments: 0,
				stockHaxePhpFiles: 0,
				buildTimeServerDependency: false,
				runtimeHxxDependency: false,
				privateImplementationMethods: privateMethodCount(plan.methods)
			},
			claims: {
				generation: "generated",
				wordpress70Runtime: "not-tested",
				productionSupport: "not-tested",
				publicationAuthorized: false
			}
		};
	}

	static function exportRecord(plan:WordPressPublicAdapterPlan, method:PhpMethod):WordPressPublicAdapterManifestExport {
		final parameters:Array<WordPressPublicAdapterManifestParameter> = [];
		for (parameter in method.parameters) {
			parameters.push({
				name: parameter.name.value,
				type: WordPressPublicAdapterPlan.typeLabel(parameter.type),
				byReference: parameter.byReference,
				variadic: parameter.variadic,
				hasDefault: parameter.defaultValue != null
			});
		}
		return {
			stableName: plan.absoluteAdapterClass + "::" + method.name.value,
			parameters: parameters,
			returnsByReference: method.returnsByReference,
			returnType: WordPressPublicAdapterPlan.typeLabel(method.returnType)
		};
	}

	static function privateMethodCount(methods:Array<PhpMethod>):Int {
		var count = 0;
		for (method in methods) {
			switch (method.visibility) {
				case PhpPrivate:
					count++;
				case _:
			}
		}
		return count;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	function get_files():Array<WordPressPublicAdapterFile> {
		return fileValues.copy();
	}
}
