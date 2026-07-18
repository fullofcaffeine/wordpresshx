package wordpress.hx.build._internal;

#if macro
import haxe.Json;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ClassType;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.build.semantic.BuildInputDeclaration;
import wordpress.hx.build.semantic.HookDeclaration;
import wordpress.hx.build.semantic.ModuleDeclaration;

/** Compilation-local, typed semantic declaration registry and plan finalizer. */
class SemanticCollector {
	static final STABLE_ID = ~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/;
	static final MODULE_ID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
	static final SEMVER = ~/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/;
	static final PHP_NAMESPACE = ~/^[A-Z][A-Za-z0-9]*(?:\\[A-Z][A-Za-z0-9]*)*$/;
	static final HOOK_NAME = ~/^[A-Za-z_][A-Za-z0-9_.\/:\-]*$/;
	static final ENVIRONMENT_NAME = ~/^[A-Z][A-Z0-9_]*$/;
	static final SHA256 = ~/^[0-9a-f]{64}$/;
	static final COLLECTOR_ID = "wordpress-hx.build.semantic-plan";
	static final PLAN_SCHEMA = "wordpress-hx.semantic-plan.v1";
	static final INPUTS_SCHEMA = "wordpress-hx.semantic-collector-inputs.v1";
	static final CANONICALIZATION = "wordpress-hx.canonical-json.v1";
	static final MODULE_METADATA = ":wordpressHx.semanticModule";
	static final HOOK_METADATA = ":wordpressHx.semanticHook";
	static final RESOURCE_METADATA = ":wordpressHx.semanticResource";
	static final ENVIRONMENT_METADATA = ":wordpressHx.semanticEnvironment";
	static final COLLECTOR_SOURCES = [
		"wordpress/hx/build/SemanticPlan.hx",
		"wordpress/hx/build/_internal/CanonicalJson.hx",
		"wordpress/hx/build/_internal/SemanticCollector.hx",
		"wordpress/hx/build/semantic/BuildInput.hx",
		"wordpress/hx/build/semantic/BuildInputDeclaration.hx",
		"wordpress/hx/build/semantic/Hook.hx",
		"wordpress/hx/build/semantic/HookDeclaration.hx",
		"wordpress/hx/build/semantic/HookOptions.hx",
		"wordpress/hx/build/semantic/Module.hx",
		"wordpress/hx/build/semantic/ModuleDeclaration.hx",
		"wordpress/hx/build/semantic/ModuleOptions.hx",
		"wordpress/hx/build/semantic/PublicEnvironmentOptions.hx",
		"wordpress/hx/build/semantic/ResourceOptions.hx"
	];

	static var generation = 0;
	static var active:Null<CollectorSession>;

	public static function install(configPath:String, planOutputPath:String, inputsOutputPath:String):Expr {
		generation++;
		final session = loadSession(generation, configPath, planOutputPath, inputsOutputPath);
		active = session;
		final sessionGeneration = generation;
		Context.onGenerate(types -> {
			if (active != null && active.generation == sessionGeneration) {
				finalize(active, types);
			}
		}, false);
		return macro null;
	}

	public static function collectModule(moduleType:String, options:Expr):ExprOf<ModuleDeclaration> {
		final session = requireSession(options.pos);
		final fields = objectFields(options, ["id", "name", "namespace", "version"]);
		final moduleId = literalString(fields.get("id"), "WPHX4002", "module id");
		final displayName = literalString(fields.get("name"), "WPHX4003", "module name");
		final version = literalString(fields.get("version"), "WPHX4004", "module version");
		final namespace = literalString(fields.get("namespace"), "WPHX4005", "module namespace");
		requirePattern(MODULE_ID, moduleId, "WPHX4006", "module id must be a lowercase slug", options.pos);
		requireNonEmpty(displayName, "WPHX4007", "module name must not be empty", options.pos);
		requirePattern(SEMVER, version, "WPHX4008", "module version must be semantic version text", options.pos);
		requirePattern(PHP_NAMESPACE, namespace, "WPHX4009", "module namespace is not a closed PHP namespace", options.pos);
		final owner = localTypeIdentity(options.pos);
		addMetadata(MODULE_METADATA, [
			macro $v{moduleType},
			macro $v{moduleId},
			macro $v{displayName},
			macro $v{version},
			macro $v{namespace},
			macro $v{owner}
		], options.pos);
		return macro null;
	}

	public static function collectHook(hookType:String, options:Expr):ExprOf<HookDeclaration> {
		final session = requireSession(options.pos);
		final fields = objectFields(options, ["callback", "id", "module", "name"], ["priority"]);
		final moduleId = literalString(fields.get("module"), "WPHX4010", "hook module");
		final hookName = literalString(fields.get("name"), "WPHX4011", "hook name");
		final hookId = literalString(fields.get("id"), "WPHX4012", "hook id");
		final callback = fields.get("callback");
		final priority = fields.exists("priority") ? literalInteger(fields.get("priority"), "WPHX4013", "hook priority") : 10;
		requirePattern(MODULE_ID, moduleId, "WPHX4014", "hook module must be a lowercase slug", options.pos);
		requirePattern(HOOK_NAME, hookName, "WPHX4015", "hook name is invalid", options.pos);
		requirePattern(STABLE_ID, hookName, "WPHX4015", "hook name must be lowercase and stable in collector v1", options.pos);
		requirePattern(MODULE_ID, hookId, "WPHX4016", "hook id must be a lowercase slug", options.pos);
		if (priority < 0) {
			fail("WPHX4017", "hook priority cannot be negative", fields.get("priority").pos);
		}
		final callbackName = callbackIdentifier(callback);
		final acceptedArgs = validateHookFunction(hookType, Context.typeof(callback), callback.pos);
		final owner = localTypeIdentity(options.pos);
		final ownerClass = owner.substr(owner.lastIndexOf(".") + 1);
		addMetadata(HOOK_METADATA, [
			macro $v{hookType},
			macro $v{moduleId},
			macro $v{hookName},
			macro $v{hookId},
			macro $v{callbackName},
			macro $v{ownerClass},
			macro $v{owner + "." + callbackName},
			macro $v{priority},
			macro $v{acceptedArgs}
		], options.pos);
		return macro null;
	}

	public static function collectResource(options:Expr):ExprOf<BuildInputDeclaration> {
		final session = requireSession(options.pos);
		final fields = objectFields(options, ["id", "path"]);
		final id = literalString(fields.get("id"), "WPHX4021", "resource id");
		final path = literalString(fields.get("path"), "WPHX4022", "resource path");
		requirePattern(STABLE_ID, id, "WPHX4023", "resource id is not stable", options.pos);
		final normalized = safeRelativePath(path, "WPHX4024", "resource path", options.pos);
		if (!underAnyRoot(normalized, session.config.resourceRoots)) {
			fail("WPHX4025", "resource path is outside configured resource roots", options.pos);
		}
		addMetadata(RESOURCE_METADATA, [macro $v{id}, macro $v{normalized}], options.pos);
		return macro null;
	}

	public static function collectEnvironment(options:Expr):ExprOf<BuildInputDeclaration> {
		final session = requireSession(options.pos);
		final fields = objectFields(options, ["name"]);
		final name = literalString(fields.get("name"), "WPHX4026", "environment name");
		requirePattern(ENVIRONMENT_NAME, name, "WPHX4027", "public build environment name is invalid", options.pos);
		if (!session.config.environment.exists(name)) {
			fail("WPHX4028", "environment input is not admitted by generated project configuration", options.pos);
		}
		addMetadata(ENVIRONMENT_METADATA, [macro $v{name}], options.pos);
		return macro null;
	}

	static function loadSession(generation:Int, configPath:String, planOutputPath:String, inputsOutputPath:String):CollectorSession {
		final root = normalizePhysical(Sys.getCwd());
		final logicalConfigPath = safeRelativePath(configPath, "WPHX4030", "collector config path", Context.currentPos());
		final configFile = readProjectFile(root, logicalConfigPath, "collector-config", Context.currentPos());
		final rawConfig = parseJson(configFile.content, "WPHX4031", "collector config", Context.currentPos());
		final config = validateConfig(rawConfig, root, Context.currentPos());
		final files:Map<String, InputFile> = [];
		addFile(files, configFile);

		final catalogFile = readProjectFile(root, config.profile.catalogPath, "profile-catalog", Context.currentPos());
		if (catalogFile.sha256 != config.profile.catalogFileSha256) {
			fail("WPHX4032", "exact profile catalog file digest mismatch", Context.currentPos());
		}
		final catalog = parseJson(catalogFile.content, "WPHX4033", "exact profile catalog", Context.currentPos());
		validateCatalog(catalog, config, Context.currentPos());
		addFile(files, catalogFile);

		final toolchainFile = readProjectFile(root, config.toolchainPath, "toolchain-lock", Context.currentPos());
		if (toolchainFile.sha256 != config.toolchainSha256) {
			fail("WPHX4034", "toolchain lock file digest mismatch", Context.currentPos());
		}
		final tools = validateToolchain(parseJson(toolchainFile.content, "WPHX4035", "toolchain lock", Context.currentPos()), config, Context.currentPos());
		addFile(files, toolchainFile);

		for (nodeSchema in config.nodeSchemas) {
			final schemaFile = readProjectFile(root, nodeSchema.path, "node-schema", Context.currentPos());
			if (schemaFile.sha256 != nodeSchema.schemaSha256) {
				fail("WPHX4036", "node schema digest mismatch for " + nodeSchema.schemaId, Context.currentPos());
			}
			final schema = parseJson(schemaFile.content, "WPHX4037", "node schema " + nodeSchema.schemaId, Context.currentPos());
			if (stringField(schema, "$id", "WPHX4038", "node schema", Context.currentPos()) != nodeSchema.schemaId) {
				fail("WPHX4039", "node schema identity mismatch for " + nodeSchema.schemaId, Context.currentPos());
			}
			addFile(files, schemaFile);
		}

		final collectorFiles:Array<InputFile> = [];
		for (sourcePath in COLLECTOR_SOURCES) {
			final physical = Context.resolvePath(sourcePath);
			final source = readTrustedFile(physical, "@wordpress-hx/build/" + sourcePath, "collector-source", Context.currentPos());
			collectorFiles.push(source);
			addFile(files, source);
		}
		collectorFiles.sort((left, right) -> Reflect.compare(left.path, right.path));
		final collectorDigestMaterial = [for (file in collectorFiles) {path: file.path, sha256: file.sha256}];

		return {
			generation: generation,
			finalized: false,
			root: root,
			configPath: logicalConfigPath,
			planOutputPath: resolveOutput(planOutputPath),
			inputsOutputPath: resolveOutput(inputsOutputPath),
			config: config,
			catalogCapabilities: catalogCapabilities(catalog),
			tools: tools,
			files: files,
			collectorSourceSha256: digest(CanonicalJson.encode(collectorDigestMaterial)),
			modules: [],
			hooks: [],
			resources: [],
			environments: []
		};
	}

	static function finalize(session:CollectorSession, types:Array<Type>):Void {
		if (session.finalized) {
			return;
		}
		session.finalized = true;
		hydrateDeclarations(session, types);
		if (session.modules.length == 0) {
			fail("WPHX4040", "semantic plan must declare at least one WordPress module", Context.currentPos());
		}

		final modules:Map<String, ModuleDraft> = [];
		for (draft in session.modules) {
			if (modules.exists(draft.moduleId)) {
				fail("WPHX4041", "duplicate module id " + draft.moduleId, draft.position);
			}
			modules.set(draft.moduleId, draft);
		}

		final resourceRecords:Array<Dynamic> = [];
		final resourceIds:Map<String, Bool> = [];
		for (resource in session.resources) {
			if (resourceIds.exists(resource.id)) {
				fail("WPHX4042", "duplicate resource id " + resource.id, resource.position);
			}
			resourceIds.set(resource.id, true);
			final file = readProjectFile(session.root, resource.path, "resource", resource.position);
			addFile(session.files, file);
			resourceRecords.push({id: resource.id, path: resource.path});
		}
		resourceRecords.sort((left, right) -> Reflect.compare(left.id, right.id));

		final environmentRecords:Array<Dynamic> = [];
		final environmentNames:Map<String, Bool> = [];
		for (declaration in session.environments) {
			if (environmentNames.exists(declaration.name)) {
				fail("WPHX4043", "duplicate environment declaration " + declaration.name, declaration.position);
			}
			environmentNames.set(declaration.name, true);
			final rule = session.config.environment.get(declaration.name);
			var value = Sys.getEnv(declaration.name);
			var source = "environment";
			if (value == null) {
				if (rule.defaultValue != null) {
					value = rule.defaultValue;
					source = "default";
				} else if (rule.required) {
					fail("WPHX4044", "required public build environment input is missing: " + declaration.name, declaration.position);
				} else {
					value = "";
					source = "unset";
				}
			}
			try {
				CanonicalJson.requireCanonicalString(value, "environment " + declaration.name);
			} catch (message:String) {
				fail("WPHX4049", message, declaration.position);
			}
			environmentRecords.push({
				name: declaration.name,
				classification: "public-build",
				required: rule.required,
				source: source,
				valueSha256: digest(value)
			});
		}
		environmentRecords.sort((left, right) -> Reflect.compare(left.name, right.name));

		final fileRecords = [
			for (file in session.files)
				{
					path: file.path,
					sha256: file.sha256,
					byteLength: file.byteLength,
					role: file.role
				}
		];
		fileRecords.sort((left, right) -> Reflect.compare(left.path, right.path));

		final inputMaterial = {
			schema: INPUTS_SCHEMA,
			canonicalization: CANONICALIZATION,
			fingerprintAlgorithm: "sha256-canonical-json-without-fingerprint-and-planDigest-v1",
			project: {
				id: session.config.projectId,
				version: session.config.projectVersion,
				configPath: session.configPath
			},
			profile: {
				id: session.config.profile.id,
				catalogRevision: session.config.profile.catalogRevision,
				catalogSha256: session.config.profile.catalogSha256
			},
			files: fileRecords,
			resources: resourceRecords,
			environment: environmentRecords,
			tools: session.tools
		};
		final inputsFingerprint = digest(CanonicalJson.encode(inputMaterial));

		final nodes:Array<Dynamic> = [];
		for (draft in session.modules) {
			nodes.push(moduleNode(draft));
		}
		final nodeIds:Map<String, Bool> = [];
		for (node in nodes) {
			nodeIds.set(node.id, true);
		}
		for (draft in session.hooks) {
			if (!modules.exists(draft.moduleId)) {
				fail("WPHX4045", "hook references undeclared module " + draft.moduleId, draft.position);
			}
			final module = modules.get(draft.moduleId);
			final node = hookNode(draft, module);
			if (nodeIds.exists(node.id)) {
				fail("WPHX4046", "duplicate semantic node id " + node.id, draft.position);
			}
			for (capability in cast(node.profileCapabilities, Array<Dynamic>)) {
				if (!session.catalogCapabilities.exists(cast capability)) {
					fail("WPHX4047", "exact profile lacks capability " + capability, draft.position);
				}
			}
			nodeIds.set(node.id, true);
			nodes.push(node);
		}
		nodes.sort((left, right) -> Reflect.compare(left.id, right.id));
		final projections:Map<String, Bool> = [];
		for (node in nodes) {
			for (projection in cast(node.projections, Array<Dynamic>)) {
				if (projections.exists(projection.projectionId)) {
					fail("WPHX4048", "duplicate projection id " + projection.projectionId, Context.currentPos());
				}
				projections.set(projection.projectionId, true);
			}
		}

		final nodeSchemas = [for (nodeSchema in session.config.nodeSchemas) nodeSchemaRecord(nodeSchema)];
		nodeSchemas.sort((left, right) -> Reflect.compare(left.schemaId, right.schemaId));
		final planWithoutDigest = {
			schema: PLAN_SCHEMA,
			canonicalization: CANONICALIZATION,
			planDigestAlgorithm: "sha256-canonical-json-without-planDigest-v1",
			generator: {
				sdkVersion: session.config.sdkVersion,
				collectorId: COLLECTOR_ID,
				collectorVersion: session.config.collectorVersion,
				collectorSourceSha256: session.collectorSourceSha256,
				toolchainSha256: session.config.toolchainSha256
			},
			profile: {
				profileId: session.config.profile.id,
				catalogRevision: session.config.profile.catalogRevision,
				catalogSha256: session.config.profile.catalogSha256
			},
			project: {
				projectId: session.config.projectId,
				projectVersion: session.config.projectVersion,
				sourceTreeSha256: inputsFingerprint
			},
			nodeSchemas: nodeSchemas,
			nodes: nodes
		};
		final planDigest = digest(CanonicalJson.encode(planWithoutDigest));
		Reflect.setField(planWithoutDigest, "planDigest", planDigest);
		final inputs = {
			schema: inputMaterial.schema,
			canonicalization: inputMaterial.canonicalization,
			fingerprintAlgorithm: inputMaterial.fingerprintAlgorithm,
			fingerprint: inputsFingerprint,
			planDigest: planDigest,
			project: inputMaterial.project,
			profile: inputMaterial.profile,
			files: inputMaterial.files,
			resources: inputMaterial.resources,
			environment: inputMaterial.environment,
			tools: inputMaterial.tools
		};
		atomicWrite(session.planOutputPath, CanonicalJson.encode(planWithoutDigest) + "\n");
		atomicWrite(session.inputsOutputPath, CanonicalJson.encode(inputs) + "\n");
	}

	static function hydrateDeclarations(session:CollectorSession, types:Array<Type>):Void {
		session.modules.resize(0);
		session.hooks.resize(0);
		session.resources.resize(0);
		session.environments.resize(0);
		final seenTypes:Map<String, Bool> = [];
		for (type in types) {
			final classType:Null<ClassType> = switch type {
				case TInst(reference, _): reference.get();
				case _: null;
			};
			if (classType == null || seenTypes.exists(classType.module + ":" + classType.name)) {
				continue;
			}
			seenTypes.set(classType.module + ":" + classType.name, true);
			final classIdentity = classType.pack.concat([classType.name]).join(".");
			for (entry in classType.meta.extract(MODULE_METADATA)) {
				requireMetadataArity(entry, 6);
				final moduleType = metadataString(entry, 0);
				final moduleId = metadataString(entry, 1);
				final displayName = metadataString(entry, 2);
				final version = metadataString(entry, 3);
				final namespace = metadataString(entry, 4);
				final owner = metadataString(entry, 5);
				if (["plugin", "mu-plugin", "theme", "block"].indexOf(moduleType) < 0) {
					fail("WPHX4001", "cached module type is unsupported", entry.pos);
				}
				requirePattern(MODULE_ID, moduleId, "WPHX4006", "module id must be a lowercase slug", entry.pos);
				requireNonEmpty(displayName, "WPHX4007", "module name must not be empty", entry.pos);
				requirePattern(SEMVER, version, "WPHX4008", "module version must be semantic version text", entry.pos);
				requirePattern(PHP_NAMESPACE, namespace, "WPHX4009", "module namespace is not a closed PHP namespace", entry.pos);
				if (owner != classIdentity) {
					fail("WPHX4001", "cached module owner contradicts its typed Haxe class", entry.pos);
				}
				session.modules.push({
					moduleId: moduleId,
					moduleType: moduleType,
					displayName: displayName,
					version: version,
					namespace: namespace,
					span: sourceSpan(entry.pos, owner + ".module", session),
					position: entry.pos
				});
			}
			for (entry in classType.meta.extract(HOOK_METADATA)) {
				requireMetadataArity(entry, 9);
				final hookType = metadataString(entry, 0);
				final moduleId = metadataString(entry, 1);
				final hookName = metadataString(entry, 2);
				final hookId = metadataString(entry, 3);
				final callbackName = metadataString(entry, 4);
				final callbackOwner = metadataString(entry, 5);
				final callbackHaxeSymbol = metadataString(entry, 6);
				if (hookType != "action" && hookType != "filter") {
					fail("WPHX4001", "cached hook type is unsupported", entry.pos);
				}
				requirePattern(MODULE_ID, moduleId, "WPHX4014", "hook module must be a lowercase slug", entry.pos);
				requirePattern(HOOK_NAME, hookName, "WPHX4015", "hook name is invalid", entry.pos);
				requirePattern(STABLE_ID, hookName, "WPHX4015", "hook name must be lowercase and stable in collector v1", entry.pos);
				requirePattern(MODULE_ID, hookId, "WPHX4016", "hook id must be a lowercase slug", entry.pos);
				if (callbackOwner != classType.name || callbackHaxeSymbol != classIdentity + "." + callbackName) {
					fail("WPHX4001", "cached callback owner contradicts its typed Haxe class", entry.pos);
				}
				final callbackField = staticField(classType, callbackName, entry.pos);
				final acceptedArgs = validateHookFunction(hookType, callbackField.type, entry.pos);
				if (metadataInteger(entry, 8) != acceptedArgs) {
					fail("WPHX4001", "cached callback arity contradicts its typed Haxe function", entry.pos);
				}
				final priority = metadataInteger(entry, 7);
				if (priority < 0) {
					fail("WPHX4017", "hook priority cannot be negative", entry.pos);
				}
				session.hooks.push({
					moduleId: moduleId,
					hookName: hookName,
					hookId: hookId,
					hookType: hookType,
					callbackName: callbackName,
					callbackOwner: callbackOwner,
					callbackHaxeSymbol: callbackHaxeSymbol,
					priority: priority,
					acceptedArgs: acceptedArgs,
					span: sourceSpan(entry.pos, callbackHaxeSymbol, session),
					position: entry.pos
				});
			}
			for (entry in classType.meta.extract(RESOURCE_METADATA)) {
				requireMetadataArity(entry, 2);
				final path = safeRelativePath(metadataString(entry, 1), "WPHX4024", "resource path", entry.pos);
				if (!underAnyRoot(path, session.config.resourceRoots)) {
					fail("WPHX4025", "resource path is outside configured resource roots", entry.pos);
				}
				final id = metadataString(entry, 0);
				requirePattern(STABLE_ID, id, "WPHX4023", "resource id is not stable", entry.pos);
				session.resources.push({id: id, path: path, position: entry.pos});
			}
			for (entry in classType.meta.extract(ENVIRONMENT_METADATA)) {
				requireMetadataArity(entry, 1);
				final name = metadataString(entry, 0);
				requirePattern(ENVIRONMENT_NAME, name, "WPHX4027", "public build environment name is invalid", entry.pos);
				if (!session.config.environment.exists(name)) {
					fail("WPHX4028", "environment input is not admitted by generated project configuration", entry.pos);
				}
				session.environments.push({name: name, position: entry.pos});
			}
		}
	}

	static function moduleNode(draft:ModuleDraft):Dynamic {
		final artifactKind = switch draft.moduleType {
			case "plugin": "plugin.bootstrap.php";
			case "mu-plugin": "mu-plugin.bootstrap.php";
			case "theme": "theme.bootstrap.php";
			case "block": "block.bootstrap.php";
			case _: throw "unsupported module type";
		};
		return {
			id: "module/" + draft.moduleId,
			kind: "wordpress.module",
			schemaId: "wordpress-hx.semantic-node.wordpress.module.v1",
			source: draft.span,
			relatedSources: [],
			dependsOn: [],
			profileCapabilities: [],
			projections: [
				{
					projectionId: "php/" + draft.moduleId + "/bootstrap",
					emitterId: "wordpress.php",
					artifactKind: artifactKind
				}
			],
			payload: {
				moduleId: draft.moduleId,
				moduleType: draft.moduleType,
				displayName: draft.displayName,
				version: draft.version,
				namespace: draft.namespace
			}
		};
	}

	static function hookNode(draft:HookDraft, module:ModuleDraft):Dynamic {
		final capability = "wordpress.php.function.add_" + draft.hookType;
		final nativeKind = draft.hookType == "action" ? "hook" : "filter";
		final capabilities = ["wordpress." + nativeKind + "." + draft.hookName, capability];
		capabilities.sort(Reflect.compare);
		return {
			id: "hook/" + draft.moduleId + "/" + draft.hookName + "/" + draft.hookId,
			kind: "wordpress.hook",
			schemaId: "wordpress-hx.semantic-node.wordpress.hook.v1",
			source: draft.span,
			relatedSources: [],
			dependsOn: ["module/" + draft.moduleId],
			profileCapabilities: capabilities,
			projections: [
				{
					projectionId: "php/" + draft.moduleId + "/hooks/" + draft.hookName + "/" + draft.hookId,
					emitterId: "wordpress.php",
					artifactKind: "hook.registration.php"
				}
			],
			payload: {
				hookName: draft.hookName,
				hookType: draft.hookType,
				callbackSymbol: module.namespace + "\\" + draft.callbackOwner + "::" + draft.callbackName,
				priority: draft.priority,
				acceptedArgs: draft.acceptedArgs
			}
		};
	}

	static function nodeSchemaRecord(value:NodeSchemaConfig):Dynamic {
		final record:Dynamic = {
			schemaId: value.schemaId,
			kind: value.kind,
			version: value.version,
			authority: value.authority,
			schemaSha256: value.schemaSha256,
			consumerEmitters: value.consumerEmitters.copy()
		};
		if (value.extensionId != null) {
			Reflect.setField(record, "extensionId", value.extensionId);
		}
		return record;
	}

	static function validateConfig(value:Dynamic, root:String, position:Position):CollectorConfig {
		exactObject(value, [
			"canonicalization",
			"collectorVersion",
			"environment",
			"nodeSchemas",
			"profile",
			"project",
			"resourceRoots",
			"schema",
			"sdkVersion",
			"toolchainLock"
		], "WPHX4050", "collector config", position);
		if (stringField(value, "schema", "WPHX4051", "collector config", position) != "wordpress-hx.semantic-collector-config.v1"
			|| stringField(value, "canonicalization", "WPHX4052", "collector config", position) != CANONICALIZATION) {
			fail("WPHX4053", "unsupported collector config contract", position);
		}
		final sdkVersion = semanticVersion(stringField(value, "sdkVersion", "WPHX4054", "collector config", position), "SDK version", position);
		final collectorVersion = semanticVersion(stringField(value, "collectorVersion", "WPHX4055", "collector config", position), "collector version",
			position);
		final project = Reflect.field(value, "project");
		exactObject(project, ["id", "version"], "WPHX4056", "collector project", position);
		final projectId = stringField(project, "id", "WPHX4057", "collector project", position);
		requirePattern(STABLE_ID, projectId, "WPHX4058", "project id is not stable", position);
		final projectVersion = semanticVersion(stringField(project, "version", "WPHX4059", "collector project", position), "project version", position);

		final profile = Reflect.field(value, "profile");
		exactObject(profile, ["catalogFileSha256", "catalogPath", "catalogRevision", "catalogSha256", "id"], "WPHX4060", "collector profile", position);
		final profileConfig:ProfileConfig = {
			id: stringField(profile, "id", "WPHX4061", "collector profile", position),
			catalogRevision: stringField(profile, "catalogRevision", "WPHX4062", "collector profile", position),
			catalogPath: safeRelativePath(stringField(profile, "catalogPath", "WPHX4063", "collector profile", position), "WPHX4064", "profile catalog path",
				position),
			catalogSha256: digestField(profile, "catalogSha256", "WPHX4065", "collector profile", position),
			catalogFileSha256: digestField(profile, "catalogFileSha256", "WPHX4066", "collector profile", position)
		};
		requirePattern(STABLE_ID, profileConfig.id, "WPHX4067", "profile id is not stable", position);
		if (profileConfig.catalogRevision.indexOf(profileConfig.id + "/") != 0) {
			fail("WPHX4068", "profile catalog revision contradicts profile id", position);
		}

		final lock = Reflect.field(value, "toolchainLock");
		exactObject(lock, ["path", "sha256"], "WPHX4069", "toolchain lock", position);
		final toolchainPath = safeRelativePath(stringField(lock, "path", "WPHX4070", "toolchain lock", position), "WPHX4071", "toolchain lock path", position);
		final toolchainSha256 = digestField(lock, "sha256", "WPHX4072", "toolchain lock", position);

		final roots = dynamicArray(value, "resourceRoots", "WPHX4073", "collector config", position);
		final resourceRoots:Array<String> = [];
		for (entry in roots) {
			if (!Std.isOfType(entry, String)) {
				fail("WPHX4074", "resource root must be a string", position);
			}
			resourceRoots.push(safeRelativePath(cast entry, "WPHX4075", "resource root", position));
		}
		if (resourceRoots.length == 0) {
			fail("WPHX4076", "collector config requires at least one resource root", position);
		}
		sortUnique(resourceRoots, "WPHX4076", "resource roots", position);

		final environment:Map<String, EnvironmentRule> = [];
		for (entry in dynamicArray(value, "environment", "WPHX4077", "collector config", position)) {
			final hasDefault = Reflect.hasField(entry, "default");
			exactObject(entry, hasDefault ? ["classification", "default", "name", "required"] : ["classification", "name", "required"], "WPHX4078",
				"build environment rule", position);
			if (stringField(entry, "classification", "WPHX4079", "build environment rule", position) != "public-build") {
				fail("WPHX4080", "collector may read public-build environment only", position);
			}
			final name = stringField(entry, "name", "WPHX4081", "build environment rule", position);
			requirePattern(ENVIRONMENT_NAME, name, "WPHX4082", "build environment name is invalid", position);
			if (environment.exists(name)) {
				fail("WPHX4083", "duplicate build environment rule " + name, position);
			}
			final required = boolField(entry, "required", "WPHX4084", "build environment rule", position);
			final defaultValue = hasDefault ? stringField(entry, "default", "WPHX4085", "build environment rule", position) : null;
			if (required && defaultValue != null) {
				fail("WPHX4086", "required build environment input cannot also have a default", position);
			}
			environment.set(name, {required: required, defaultValue: defaultValue});
		}

		final nodeSchemas:Array<NodeSchemaConfig> = [];
		final schemaIds:Map<String, Bool> = [];
		for (entry in dynamicArray(value, "nodeSchemas", "WPHX4087", "collector config", position)) {
			final hasExtension = Reflect.hasField(entry, "extensionId");
			exactObject(entry, hasExtension ? [
				"authority",
				"consumerEmitters",
				"extensionId",
				"kind",
				"path",
				"schemaId",
				"schemaSha256",
				"version"
			] : [
				"authority",
				"consumerEmitters",
				"kind",
				"path",
				"schemaId",
				"schemaSha256",
				"version"
			], "WPHX4088", "node schema registration", position);
			final schemaId = stringField(entry, "schemaId", "WPHX4089", "node schema registration", position);
			requirePattern(STABLE_ID, schemaId, "WPHX4089", "node schema id is not stable", position);
			if (schemaIds.exists(schemaId)) {
				fail("WPHX4090", "duplicate node schema registration " + schemaId, position);
			}
			schemaIds.set(schemaId, true);
			final authority = stringField(entry, "authority", "WPHX4091", "node schema registration", position);
			if (authority != "core" && authority != "extension") {
				fail("WPHX4092", "node schema authority must be core or extension", position);
			}
			if ((authority == "extension") != hasExtension) {
				fail("WPHX4093", "only an extension node schema must declare extensionId", position);
			}
			final extensionId = hasExtension ? stringField(entry, "extensionId", "WPHX4100", "node schema registration", position) : null;
			if (extensionId != null) {
				requirePattern(STABLE_ID, extensionId, "WPHX4100", "extension id is not stable", position);
			}
			final emitters:Array<String> = [];
			for (emitter in dynamicArray(entry, "consumerEmitters", "WPHX4094", "node schema registration", position)) {
				if (!Std.isOfType(emitter, String)) {
					fail("WPHX4095", "node schema emitter must be a string", position);
				}
				final emitterId:String = cast emitter;
				requirePattern(STABLE_ID, emitterId, "WPHX4095", "node schema emitter id is not stable", position);
				emitters.push(emitterId);
			}
			if (emitters.length == 0) {
				fail("WPHX4096", "node schema requires at least one consumer emitter", position);
			}
			sortUnique(emitters, "WPHX4096", "node schema emitters", position);
			final version = intField(entry, "version", "WPHX4097", "node schema registration", position);
			if (version < 1 || !StringTools.endsWith(schemaId, ".v" + version)) {
				fail("WPHX4098", "node schema version contradicts schema id", position);
			}
			final kind = stringField(entry, "kind", "WPHX4099", "node schema registration", position);
			requirePattern(STABLE_ID, kind, "WPHX4099", "node schema kind is not stable", position);
			if ((schemaId == "wordpress-hx.semantic-node.wordpress.hook.v1" && kind != "wordpress.hook")
				|| (schemaId == "wordpress-hx.semantic-node.wordpress.module.v1" && kind != "wordpress.module")) {
				fail("WPHX4099", "core node schema kind contradicts its schema id", position);
			}
			nodeSchemas.push({
				schemaId: schemaId,
				kind: kind,
				version: version,
				authority: authority,
				extensionId: extensionId,
				path: safeRelativePath(stringField(entry, "path", "WPHX4101", "node schema registration", position), "WPHX4102", "node schema path", position),
				schemaSha256: digestField(entry, "schemaSha256", "WPHX4103", "node schema registration", position),
				consumerEmitters: emitters
			});
		}
		nodeSchemas.sort((left, right) -> Reflect.compare(left.schemaId, right.schemaId));
		for (required in [
			"wordpress-hx.semantic-node.wordpress.hook.v1",
			"wordpress-hx.semantic-node.wordpress.module.v1"
		]) {
			if (!schemaIds.exists(required)) {
				fail("WPHX4104", "collector v1 requires node schema " + required, position);
			}
		}

		return {
			sdkVersion: sdkVersion,
			collectorVersion: collectorVersion,
			projectId: projectId,
			projectVersion: projectVersion,
			profile: profileConfig,
			toolchainPath: toolchainPath,
			toolchainSha256: toolchainSha256,
			resourceRoots: resourceRoots,
			environment: environment,
			nodeSchemas: nodeSchemas
		};
	}

	static function validateCatalog(value:Dynamic, config:CollectorConfig, position:Position):Void {
		final catalog = Reflect.field(value, "catalog");
		if (catalog == null
			|| stringField(catalog, "profileId", "WPHX4110", "profile catalog", position) != config.profile.id
			|| stringField(catalog, "catalogRevision", "WPHX4111", "profile catalog", position) != config.profile.catalogRevision
			|| stringField(value, "catalogDigest", "WPHX4112", "profile catalog", position) != config.profile.catalogSha256) {
			fail("WPHX4113", "profile catalog identity or semantic digest mismatch", position);
		}
	}

	static function catalogCapabilities(value:Dynamic):Map<String, Bool> {
		final capabilities:Map<String, Bool> = [];
		final catalog = Reflect.field(value, "catalog");
		for (entry in dynamicArray(catalog, "capabilities", "WPHX4114", "profile catalog", Context.currentPos())) {
			final id = stringField(entry, "capabilityId", "WPHX4115", "profile capability", Context.currentPos());
			capabilities.set(id, true);
		}
		return capabilities;
	}

	static function validateToolchain(value:Dynamic, config:CollectorConfig, position:Position):Array<Dynamic> {
		if (stringField(value, "schema", "WPHX4120", "toolchain lock", position) != "wordpress-hx.project-lock.v1") {
			fail("WPHX4121", "unsupported generated project lock", position);
		}
		final project = Reflect.field(value, "project");
		final profile = Reflect.field(value, "profile");
		if (stringField(project, "id", "WPHX4122", "toolchain project", position) != config.projectId
			|| stringField(profile, "id", "WPHX4123", "toolchain profile", position) != config.profile.id
			|| stringField(profile, "catalogRevision", "WPHX4124", "toolchain profile", position) != config.profile.catalogRevision
			|| stringField(profile, "catalogSha256", "WPHX4125", "toolchain profile", position) != config.profile.catalogSha256) {
			fail("WPHX4126", "toolchain lock contradicts collector project/profile", position);
		}
		final tools:Array<Dynamic> = [];
		for (entry in dynamicArray(value, "components", "WPHX4127", "toolchain lock", position)) {
			tools.push({
				id: stringField(entry, "id", "WPHX4128", "toolchain component", position),
				version: stringField(entry, "version", "WPHX4129", "toolchain component", position),
				identity: stringField(entry, "identity", "WPHX4130", "toolchain component", position),
				lockEntrySha256: digestField(entry, "lockEntrySha256", "WPHX4131", "toolchain component", position)
			});
		}
		tools.sort((left, right) -> Reflect.compare(left.id, right.id));
		return tools;
	}

	static function sourceSpan(position:Position, symbol:String, session:CollectorSession):Dynamic {
		final info = Context.getPosInfos(position);
		final physical = normalizePhysical(info.file);
		if (!StringTools.startsWith(physical, session.root + "/")) {
			fail("WPHX4140", "semantic declaration source is outside the project root", position);
		}
		final path = physical.substr(session.root.length + 1);
		safeRelativePath(path, "WPHX4141", "declaration source path", position);
		final file = readProjectFile(session.root, path, "source", position);
		addFile(session.files, file);
		if (info.min < 0 || info.max <= info.min || info.max > file.bytes.length) {
			fail("WPHX4142", "compiler source span is not a non-empty UTF-8 byte range", position);
		}
		return {
			path: path,
			sourceSha256: file.sha256,
			start: point(file.bytes, info.min, position),
			end: point(file.bytes, info.max, position),
			symbol: symbol
		};
	}

	static function point(bytes:Bytes, offset:Int, position:Position):Dynamic {
		if (offset < bytes.length && (bytes.get(offset) & 0xc0) == 0x80) {
			fail("WPHX4143", "compiler source span splits a UTF-8 sequence", position);
		}
		var line = 1;
		var lastNewline = -1;
		for (index in 0...offset) {
			if (bytes.get(index) == 0x0a) {
				line++;
				lastNewline = index;
			}
		}
		return {offset: offset, line: line, column: offset - lastNewline - 1};
	}

	static function objectFields(expression:Expr, required:Array<String>, optional:Array<String> = null):Map<String, Expr> {
		final values = switch expression.expr {
			case EObjectDecl(fields): fields;
			case _: fail("WPHX4150", "semantic declaration options must be a literal object", expression.pos);
		};
		final allowed = required.copy();
		if (optional != null) {
			allowed.push(optional[0]);
			for (index in 1...optional.length) {
				allowed.push(optional[index]);
			}
		}
		final result:Map<String, Expr> = [];
		for (field in values) {
			if (allowed.indexOf(field.field) < 0) {
				fail("WPHX4151", "unknown semantic declaration field " + field.field, field.expr.pos);
			}
			if (result.exists(field.field)) {
				fail("WPHX4152", "duplicate semantic declaration field " + field.field, field.expr.pos);
			}
			result.set(field.field, field.expr);
		}
		for (field in required) {
			if (!result.exists(field)) {
				fail("WPHX4153", "missing semantic declaration field " + field, expression.pos);
			}
		}
		return result;
	}

	static function addMetadata(name:String, parameters:Array<Expr>, position:Position):Void {
		final reference = Context.getLocalClass();
		if (reference == null) {
			fail("WPHX4155", "semantic declaration must appear inside a Haxe class", position);
		}
		reference.get().meta.add(name, parameters, position);
	}

	static function requireMetadataArity(entry:MetadataEntry, expected:Int):Void {
		if (entry.params.length != expected) {
			fail("WPHX4156", "cached semantic declaration metadata has invalid arity", entry.pos);
		}
	}

	static function metadataString(entry:MetadataEntry, index:Int):String {
		return literalString(entry.params[index], "WPHX4157", "cached semantic declaration value");
	}

	static function metadataInteger(entry:MetadataEntry, index:Int):Int {
		return literalInteger(entry.params[index], "WPHX4158", "cached semantic declaration value");
	}

	static function callbackIdentifier(expression:Expr):String {
		return switch expression.expr {
			case EConst(CIdent(name)): name;
			case _: fail("WPHX4154", "hook callback must be a direct local function reference", expression.pos);
		};
	}

	static function literalString(expression:Expr, code:String, label:String):String {
		return switch expression.expr {
			case EConst(CString(value, _)):
				try {
					CanonicalJson.requireCanonicalString(value, label);
				} catch (message:String) {
					fail(code, message, expression.pos);
				}
				value;
			case _: fail(code, label + " must be a string literal", expression.pos);
		};
	}

	static function literalInteger(expression:Expr, code:String, label:String):Int {
		return switch expression.expr {
			case EConst(CInt(value, _)):
				final parsed = Std.parseInt(value);
				if (parsed == null) {
					fail(code, label + " is not an integer literal", expression.pos);
				}
				parsed;
			case _: fail(code, label + " must be an integer literal", expression.pos);
		};
	}

	static function staticField(classType:ClassType, name:String, position:Position):ClassField {
		for (field in classType.statics.get()) {
			if (field.name == name) {
				return field;
			}
		}
		return fail("WPHX4020", "hook callback is not a static function on its declaration class", position);
	}

	static function validateHookFunction(hookType:String, type:Type, position:Position):Int {
		return switch Context.follow(type) {
			case TFun(arguments, result):
				if (hookType == "action" && !isVoid(result)) {
					fail("WPHX4018", "an action callback must return Void", position);
				}
				if (hookType == "filter") {
					if (arguments.length == 0 || isVoid(result) || !Context.unify(result, arguments[0].t)) {
						fail("WPHX4019", "a filter callback must accept and return its filtered value", position);
					}
				}
				arguments.length;
			case _:
				fail("WPHX4020", "hook callback must be a statically typed function", position);
		};
	}

	static function isVoid(type:Type):Bool {
		return switch Context.follow(type) {
			case TAbstract(reference, _): reference.get().name == "Void";
			case _: false;
		};
	}

	static function localTypeIdentity(position:Position):String {
		final reference = Context.getLocalClass();
		if (reference == null) {
			fail("WPHX4155", "semantic declaration must appear inside a Haxe class", position);
		}
		final type = reference.get();
		return type.pack.concat([type.name]).join(".");
	}

	static function readProjectFile(root:String, path:String, role:String, position:Position):InputFile {
		final physical = root + "/" + path;
		final normalized = normalizePhysical(physical);
		if (normalized != physical || !StringTools.startsWith(normalized, root + "/")) {
			fail("WPHX4160", role + " resolves through a symlink or outside the project root: " + path, position);
		}
		return readTrustedFile(normalized, path, role, position);
	}

	static function readTrustedFile(physical:String, logical:String, role:String, position:Position):InputFile {
		if (!FileSystem.exists(physical) || FileSystem.isDirectory(physical)) {
			fail("WPHX4161", role + " is not a regular file: " + logical, position);
		}
		final bytes = File.getBytes(physical);
		return {
			path: logical,
			role: role,
			sha256: Sha256.make(bytes).toHex().toLowerCase(),
			byteLength: bytes.length,
			content: bytes.toString(),
			bytes: bytes
		};
	}

	static function addFile(files:Map<String, InputFile>, file:InputFile):Void {
		if (files.exists(file.path)) {
			final previous = files.get(file.path);
			if (previous.sha256 != file.sha256 || previous.role != file.role) {
				fail("WPHX4162", "effective input path has conflicting identity or role: " + file.path, Context.currentPos());
			}
			return;
		}
		files.set(file.path, file);
	}

	static function normalizePhysical(path:String):String {
		return FileSystem.fullPath(path).split("\\").join("/");
	}

	static function resolveOutput(path:String):String {
		if (Path.isAbsolute(path)) {
			return Path.normalize(path);
		}
		return Path.normalize(Sys.getCwd() + "/" + path);
	}

	static function atomicWrite(path:String, content:String):Void {
		final parent = Path.directory(path);
		if (parent.length > 0 && !FileSystem.exists(parent)) {
			FileSystem.createDirectory(parent);
		}
		final temporary = path + ".tmp." + generation;
		if (FileSystem.exists(temporary)) {
			FileSystem.deleteFile(temporary);
		}
		File.saveContent(temporary, content);
		try {
			FileSystem.rename(temporary, path);
		} catch (error:Dynamic) {
			if (FileSystem.exists(temporary)) {
				FileSystem.deleteFile(temporary);
			}
			throw error;
		}
	}

	static function safeRelativePath(value:String, code:String, label:String, position:Position):String {
		if (value == null || value.length == 0 || value.charAt(0) == "/" || value.indexOf("\\") >= 0 || value.indexOf(":") >= 0) {
			fail(code, label + " must be a normalized project-relative POSIX path", position);
		}
		final parts = value.split("/");
		for (part in parts) {
			if (part.length == 0 || part == "." || part == "..") {
				fail(code, label + " contains an unsafe path segment", position);
			}
			CanonicalJson.requireCanonicalString(part, label);
		}
		return parts.join("/");
	}

	static function underAnyRoot(path:String, roots:Array<String>):Bool {
		for (root in roots) {
			if (path == root || StringTools.startsWith(path, root + "/")) {
				return true;
			}
		}
		return false;
	}

	static function digest(value:String):String {
		return Sha256.make(Bytes.ofString(value)).toHex().toLowerCase();
	}

	static function semanticVersion(value:String, label:String, position:Position):String {
		requirePattern(SEMVER, value, "WPHX4170", label + " must be exact semantic version text", position);
		return value;
	}

	static function requireSession(position:Position):CollectorSession {
		if (active == null) {
			fail("WPHX4000", "semantic collector is not installed by the generated HXML", position);
		}
		if (active.finalized) {
			fail("WPHX4001", "semantic declaration was typed after collector finalization", position);
		}
		return active;
	}

	static function exactObject(value:Dynamic, fields:Array<String>, code:String, label:String, position:Position):Void {
		if (value == null || Std.isOfType(value, Array) || Std.isOfType(value, String)) {
			fail(code, label + " must be an object", position);
		}
		final actual = Reflect.fields(value);
		actual.sort(Reflect.compare);
		final expected = fields.copy();
		expected.sort(Reflect.compare);
		if (actual.join("\n") != expected.join("\n")) {
			fail(code, label + " fields must be exactly [" + expected.join(", ") + "]", position);
		}
	}

	static function stringField(value:Dynamic, field:String, code:String, label:String, position:Position):String {
		final result = Reflect.field(value, field);
		if (!Std.isOfType(result, String)) {
			fail(code, label + "." + field + " must be a string", position);
		}
		try {
			CanonicalJson.requireCanonicalString(cast result, label + "." + field);
		} catch (message:String) {
			fail(code, message, position);
		}
		return cast result;
	}

	static function digestField(value:Dynamic, field:String, code:String, label:String, position:Position):String {
		final result = stringField(value, field, code, label, position);
		requirePattern(SHA256, result, code, label + "." + field + " must be a lowercase SHA-256", position);
		return result;
	}

	static function boolField(value:Dynamic, field:String, code:String, label:String, position:Position):Bool {
		final result = Reflect.field(value, field);
		if (!Std.isOfType(result, Bool)) {
			fail(code, label + "." + field + " must be a boolean", position);
		}
		return cast result;
	}

	static function intField(value:Dynamic, field:String, code:String, label:String, position:Position):Int {
		final result = Reflect.field(value, field);
		return switch Type.typeof(result) {
			case TInt: cast result;
			case _: fail(code, label + "." + field + " must be an integer", position);
		};
	}

	static function dynamicArray(value:Dynamic, field:String, code:String, label:String, position:Position):Array<Dynamic> {
		final result = Reflect.field(value, field);
		if (!Std.isOfType(result, Array)) {
			fail(code, label + "." + field + " must be an array", position);
		}
		return cast result;
	}

	static function sortUnique(values:Array<String>, code:String, label:String, position:Position):Void {
		values.sort(Reflect.compare);
		for (index in 1...values.length) {
			if (values[index - 1] == values[index]) {
				fail(code, label + " contains duplicate " + values[index], position);
			}
		}
	}

	static function requirePattern(pattern:EReg, value:String, code:String, message:String, position:Position):Void {
		if (!pattern.match(value)) {
			fail(code, message + ": " + value, position);
		}
	}

	static function requireNonEmpty(value:String, code:String, message:String, position:Position):Void {
		if (value.length == 0) {
			fail(code, message, position);
		}
	}

	static function parseJson(content:String, code:String, label:String, position:Position):Dynamic {
		try {
			return Json.parse(content);
		} catch (error:Dynamic) {
			return fail(code, label + " is not valid JSON", position);
		}
	}

	static function fail(code:String, message:String, position:Position):Dynamic {
		Context.error(code + ": " + message, position);
		throw code + ": " + message;
	}
}

private typedef CollectorSession = {
	final generation:Int;
	var finalized:Bool;
	final root:String;
	final configPath:String;
	final planOutputPath:String;
	final inputsOutputPath:String;
	final config:CollectorConfig;
	final catalogCapabilities:Map<String, Bool>;
	final tools:Array<Dynamic>;
	final files:Map<String, InputFile>;
	final collectorSourceSha256:String;
	final modules:Array<ModuleDraft>;
	final hooks:Array<HookDraft>;
	final resources:Array<ResourceDraft>;
	final environments:Array<EnvironmentDraft>;
}

private typedef CollectorConfig = {
	final sdkVersion:String;
	final collectorVersion:String;
	final projectId:String;
	final projectVersion:String;
	final profile:ProfileConfig;
	final toolchainPath:String;
	final toolchainSha256:String;
	final resourceRoots:Array<String>;
	final environment:Map<String, EnvironmentRule>;
	final nodeSchemas:Array<NodeSchemaConfig>;
}

private typedef ProfileConfig = {
	final id:String;
	final catalogRevision:String;
	final catalogPath:String;
	final catalogSha256:String;
	final catalogFileSha256:String;
}

private typedef EnvironmentRule = {
	final required:Bool;
	final defaultValue:Null<String>;
}

private typedef NodeSchemaConfig = {
	final schemaId:String;
	final kind:String;
	final version:Int;
	final authority:String;
	final extensionId:Null<String>;
	final path:String;
	final schemaSha256:String;
	final consumerEmitters:Array<String>;
}

private typedef InputFile = {
	final path:String;
	final role:String;
	final sha256:String;
	final byteLength:Int;
	final content:String;
	final bytes:Bytes;
}

private typedef ModuleDraft = {
	final moduleId:String;
	final moduleType:String;
	final displayName:String;
	final version:String;
	final namespace:String;
	final span:Dynamic;
	final position:Position;
}

private typedef HookDraft = {
	final moduleId:String;
	final hookName:String;
	final hookId:String;
	final hookType:String;
	final callbackName:String;
	final callbackOwner:String;
	final callbackHaxeSymbol:String;
	final priority:Int;
	final acceptedArgs:Int;
	final span:Dynamic;
	final position:Position;
}

private typedef ResourceDraft = {
	final id:String;
	final path:String;
	final position:Position;
}

private typedef EnvironmentDraft = {
	final name:String;
	final position:Position;
}
#end
