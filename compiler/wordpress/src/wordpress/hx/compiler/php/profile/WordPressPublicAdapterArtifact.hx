package wordpress.hx.compiler.php.profile;

import haxe.Json;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpVisibility;
import wordpress.hx.compiler.php.profile.WordPressRestMethod.WordPressRestMethodTools;

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
		values.sort((left, right) -> Reflect.compare(left.path, right.path));
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

		final hookRecords:Array<Dynamic> = [];
		for (hook in plan.hooks) {
			hookRecords.push({
				kind: hook.kind == Action ? "action" : "filter",
				hook: hook.hookName,
				callback: plan.absoluteAdapterClass + "::" + hook.callback.value,
				priority: hook.priority,
				acceptedArgs: hook.acceptedArgs
			});
		}
		final routeRecords:Array<Dynamic> = [];
		for (route in plan.restRoutes) {
			routeRecords.push({
				namespace: route.namespace,
				route: route.route,
				method: WordPressRestMethodTools.constantName(route.method),
				callback: plan.absoluteAdapterClass + "::" + route.callback.value,
				permissionCallback: plan.absoluteAdapterClass + "::" + route.permissionCallback.value
			});
		}
		final blockRecords:Array<Dynamic> = [];
		for (block in plan.blocks) {
			blockRecords.push({
				name: block.blockName,
				renderCallback: plan.absoluteAdapterClass + "::" + block.renderCallback.value
			});
		}
		final exportRecords:Array<Dynamic> = [];
		for (export in plan.exports) {
			final method = plan.method(export.method);
			exportRecords.push(exportRecord(plan, method));
		}

		final manifest:Dynamic = {
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
		return Json.stringify(manifest, null, "  ") + "\n";
	}

	static function exportRecord(plan:WordPressPublicAdapterPlan, method:PhpMethod):Dynamic {
		final parameters:Array<Dynamic> = [];
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

	function get_files():Array<WordPressPublicAdapterFile> {
		return fileValues.copy();
	}
}
