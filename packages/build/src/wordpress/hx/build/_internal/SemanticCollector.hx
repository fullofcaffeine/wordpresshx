package wordpress.hx.build._internal;

#if macro
import haxe.Exception;
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
import wordpress.hx.build.semantic.DevelopmentServiceDeclaration;
import wordpress.hx.build.semantic.HookDeclaration;
import wordpress.hx.build.semantic.ModuleDeclaration;
import wordpress.hx.build._internal.CanonicalJson.CanonicalJsonError;
import wordpress.hx.build._internal.JsonObjectReader.JsonReadError;
import wordpress.hx.build._internal.JsonParser.JsonParseError;
import wordpress.hx.build._internal.SemanticModel.CollectorInputMaterial;
import wordpress.hx.build._internal.SemanticModel.CollectorInputs;
import wordpress.hx.build._internal.SemanticModel.DevelopmentCommand;
import wordpress.hx.build._internal.SemanticModel.DevelopmentReadinessKind;
import wordpress.hx.build._internal.SemanticModel.DevelopmentReloadKind;
import wordpress.hx.build._internal.SemanticModel.DevelopmentServiceData;
import wordpress.hx.build._internal.SemanticModel.DevelopmentServiceKind;
import wordpress.hx.build._internal.SemanticModel.EnvironmentRecord;
import wordpress.hx.build._internal.SemanticModel.FileDigestRecord;
import wordpress.hx.build._internal.SemanticModel.InputFileRecord;
import wordpress.hx.build._internal.SemanticModel.NodeSchemaRecord;
import wordpress.hx.build._internal.SemanticModel.ResourceRecord;
import wordpress.hx.build._internal.SemanticModel.SemanticNode;
import wordpress.hx.build._internal.SemanticModel.SemanticPayload;
import wordpress.hx.build._internal.SemanticModel.SemanticPlanRecord;
import wordpress.hx.build._internal.SemanticModel.SourcePoint;
import wordpress.hx.build._internal.SemanticModel.SourceSpan;
import wordpress.hx.build._internal.SemanticModel.ToolRecord;

/** Compilation-local, typed semantic declaration registry and plan finalizer. */
class SemanticCollector {
	static final STABLE_ID = ~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/;
	static final MODULE_ID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
	static final SEMVER = ~/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/;
	static final PHP_NAMESPACE = ~/^[A-Z][A-Za-z0-9]*(?:\\[A-Z][A-Za-z0-9]*)*$/;
	static final HOOK_NAME = ~/^[A-Za-z_][A-Za-z0-9_.\/:\-]*$/;
	static final ENVIRONMENT_NAME = ~/^[A-Z][A-Z0-9_]*$/;
	static final EXECUTABLE_NAME = ~/^[A-Za-z0-9._+\-]+$/;
	static final SHA256 = ~/^[0-9a-f]{64}$/;
	static final COLLECTOR_ID = "wordpress-hx.build.semantic-plan";
	static final PLAN_SCHEMA = "wordpress-hx.semantic-plan.v1";
	static final INPUTS_SCHEMA = "wordpress-hx.semantic-collector-inputs.v1";
	static final CANONICALIZATION = "wordpress-hx.canonical-json.v1";
	static final MODULE_METADATA = ":wordpressHx.semanticModule";
	static final HOOK_METADATA = ":wordpressHx.semanticHook";
	static final RESOURCE_METADATA = ":wordpressHx.semanticResource";
	static final ENVIRONMENT_METADATA = ":wordpressHx.semanticEnvironment";
	static final DEVELOPMENT_SERVICE_METADATA = ":wordpressHx.semanticDevelopmentService";
	static final DEVELOPMENT_SERVICE_SCHEMA = "wordpress-hx.semantic-node.development.service.v1";
	static final DEVELOPMENT_SERVICE_KIND = "development.service";
	static final DEVELOPMENT_SERVICE_EMITTER = "wordpresshx.dev";
	static final COLLECTOR_SOURCES = [
		"wordpress/hx/build/SemanticPlan.hx",
		"wordpress/hx/build/_internal/CanonicalJson.hx",
		"wordpress/hx/build/_internal/JsonObjectReader.hx",
		"wordpress/hx/build/_internal/JsonParser.hx",
		"wordpress/hx/build/_internal/JsonValue.hx",
		"wordpress/hx/build/_internal/SemanticCollector.hx",
		"wordpress/hx/build/_internal/SemanticJson.hx",
		"wordpress/hx/build/_internal/SemanticModel.hx",
		"wordpress/hx/build/semantic/BuildInput.hx",
		"wordpress/hx/build/semantic/BuildInputDeclaration.hx",
		"wordpress/hx/build/semantic/Dev.hx",
		"wordpress/hx/build/semantic/DevelopmentCommandOptions.hx",
		"wordpress/hx/build/semantic/DevelopmentReadinessKind.hx",
		"wordpress/hx/build/semantic/DevelopmentServiceDeclaration.hx",
		"wordpress/hx/build/semantic/DevelopmentServiceOptions.hx",
		"wordpress/hx/build/semantic/Hook.hx",
		"wordpress/hx/build/semantic/HookDeclaration.hx",
		"wordpress/hx/build/semantic/HookOptions.hx",
		"wordpress/hx/build/semantic/Module.hx",
		"wordpress/hx/build/semantic/ModuleDeclaration.hx",
		"wordpress/hx/build/semantic/ModuleOptions.hx",
		"wordpress/hx/build/semantic/PublicEnvironmentOptions.hx",
		"wordpress/hx/build/semantic/ResourceOptions.hx",
		"wordpress/hx/build/semantic/WordPressDevelopmentOptions.hx"
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

	public static function collectWordPressService(options:Null<Expr>):ExprOf<DevelopmentServiceDeclaration> {
		return collectDevelopmentService(WordPressService, optionalExpression(options));
	}

	public static function collectExternalService(options:Expr):ExprOf<DevelopmentServiceDeclaration> {
		return collectDevelopmentService(ExternalService, options);
	}

	static function collectDevelopmentService(serviceKind:DevelopmentServiceKind, options:Null<Expr>):ExprOf<DevelopmentServiceDeclaration> {
		final position = options == null ? Context.currentPos() : options.pos;
		final session = requireSession(position);
		final data = developmentServiceData(serviceKind, options, session);
		final owner = localTypeIdentity(position);
		addMetadata(DEVELOPMENT_SERVICE_METADATA, [
			macro $v{CanonicalJson.encode(SemanticJson.developmentService(data))},
			macro $v{owner}
		], position);
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
			final schemaId = readJson(Context.currentPos(), () -> JsonObjectReader.from(schema, "node schema", "WPHX4038").string("$id", "WPHX4038"));
			if (schemaId != nodeSchema.schemaId) {
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
		collectorFiles.sort((left, right) -> compareText(left.path, right.path));
		final collectorDigestMaterial:Array<FileDigestRecord> = [for (file in collectorFiles) {path: file.path, sha256: file.sha256}];

		return {
			generation: generation,
			finalized: false,
			root: root,
			configPath: logicalConfigPath,
			planOutputPath: resolveOutput(planOutputPath),
			inputsOutputPath: resolveOutput(inputsOutputPath),
			config: config,
			catalogCapabilities: catalogCapabilities(catalog, Context.currentPos()),
			tools: tools,
			files: files,
			collectorSourceSha256: digest(CanonicalJson.encode(SemanticJson.fileDigests(collectorDigestMaterial))),
			modules: [],
			hooks: [],
			resources: [],
			environments: [],
			services: []
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

		final services:Map<String, DevelopmentServiceDraft> = [];
		for (draft in session.services) {
			if (services.exists(draft.serviceId)) {
				fail("WPHX4181", "duplicate development service id " + draft.serviceId, draft.position);
			}
			services.set(draft.serviceId, draft);
		}
		if (session.services.length > 0) {
			validateDevelopmentServiceRegistration(session.config.nodeSchemas, Context.currentPos());
			for (draft in session.services) {
				for (dependency in draft.dependsOn) {
					if (!services.exists(dependency)) {
						fail("WPHX4182", "development service " + draft.serviceId + " depends on undeclared service " + dependency, draft.position);
					}
				}
			}
			detectDevelopmentServiceCycles(services);
		}

		final resourceRecords:Array<ResourceRecord> = [];
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
		resourceRecords.sort((left, right) -> compareText(left.id, right.id));

		final environmentRecords:Array<EnvironmentRecord> = [];
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
			} catch (error:CanonicalJsonError) {
				fail("WPHX4049", error.message, declaration.position);
			}
			environmentRecords.push({
				name: declaration.name,
				classification: "public-build",
				required: rule.required,
				source: source,
				valueSha256: digest(value)
			});
		}
		environmentRecords.sort((left, right) -> compareText(left.name, right.name));

		final fileRecords:Array<InputFileRecord> = [
			for (file in session.files)
				{
					path: file.path,
					sha256: file.sha256,
					byteLength: file.byteLength,
					role: file.role
				}
		];
		fileRecords.sort((left, right) -> compareText(left.path, right.path));

		final inputMaterial:CollectorInputMaterial = {
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
		final inputsFingerprint = digest(CanonicalJson.encode(SemanticJson.inputMaterial(inputMaterial)));

		final nodes:Array<SemanticNode> = [];
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
			for (capability in node.profileCapabilities) {
				if (!session.catalogCapabilities.exists(capability)) {
					fail("WPHX4047", "exact profile lacks capability " + capability, draft.position);
				}
			}
			nodeIds.set(node.id, true);
			nodes.push(node);
		}
		for (draft in session.services) {
			final node = developmentServiceNode(draft);
			if (nodeIds.exists(node.id)) {
				fail("WPHX4181", "duplicate semantic node id " + node.id, draft.position);
			}
			nodeIds.set(node.id, true);
			nodes.push(node);
		}
		nodes.sort((left, right) -> compareText(left.id, right.id));
		final projections:Map<String, Bool> = [];
		for (node in nodes) {
			for (projection in node.projections) {
				if (projections.exists(projection.projectionId)) {
					fail("WPHX4048", "duplicate projection id " + projection.projectionId, Context.currentPos());
				}
				projections.set(projection.projectionId, true);
			}
		}

		final nodeSchemas:Array<NodeSchemaRecord> = [for (nodeSchema in session.config.nodeSchemas) nodeSchemaRecord(nodeSchema)];
		nodeSchemas.sort((left, right) -> compareText(left.schemaId, right.schemaId));
		final planMaterial:SemanticPlanRecord = {
			schema: PLAN_SCHEMA,
			canonicalization: CANONICALIZATION,
			planDigestAlgorithm: "sha256-canonical-json-without-planDigest-v1",
			planDigest: null,
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
		final planDigest = digest(CanonicalJson.encode(SemanticJson.plan(planMaterial)));
		final plan:SemanticPlanRecord = {
			schema: planMaterial.schema,
			canonicalization: planMaterial.canonicalization,
			planDigestAlgorithm: planMaterial.planDigestAlgorithm,
			planDigest: planDigest,
			generator: planMaterial.generator,
			profile: planMaterial.profile,
			project: planMaterial.project,
			nodeSchemas: planMaterial.nodeSchemas,
			nodes: planMaterial.nodes
		};
		final inputs:CollectorInputs = {
			material: inputMaterial,
			fingerprint: inputsFingerprint,
			planDigest: planDigest
		};
		atomicWrite(session.planOutputPath, CanonicalJson.encode(SemanticJson.plan(plan)) + "\n");
		atomicWrite(session.inputsOutputPath, CanonicalJson.encode(SemanticJson.inputs(inputs)) + "\n");
	}

	static function hydrateDeclarations(session:CollectorSession, types:Array<Type>):Void {
		session.modules.resize(0);
		session.hooks.resize(0);
		session.resources.resize(0);
		session.environments.resize(0);
		session.services.resize(0);
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
			for (entry in classType.meta.extract(DEVELOPMENT_SERVICE_METADATA)) {
				requireMetadataArity(entry, 2);
				final encoded = metadataString(entry, 0);
				final owner = metadataString(entry, 1);
				if (owner != classIdentity) {
					fail("WPHX4183", "cached development service owner contradicts its typed Haxe class", entry.pos);
				}
				final encodedData = parseJson(encoded, "WPHX4183", "cached development service", entry.pos);
				if (CanonicalJson.encode(encodedData) != encoded) {
					fail("WPHX4183", "cached development service is not canonical", entry.pos);
				}
				final data = decodeDevelopmentService(encodedData, session, entry.pos);
				session.services.push({
					serviceId: data.serviceId,
					dependsOn: data.dependsOn.copy(),
					data: data,
					span: sourceSpan(entry.pos, owner + ".development." + data.serviceId, session),
					position: entry.pos
				});
			}
		}
	}

	static function moduleNode(draft:ModuleDraft):SemanticNode {
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
			payload: ModulePayload({
				moduleId: draft.moduleId,
				moduleType: draft.moduleType,
				displayName: draft.displayName,
				version: draft.version,
				namespace: draft.namespace
			})
		};
	}

	static function hookNode(draft:HookDraft, module:ModuleDraft):SemanticNode {
		final capability = "wordpress.php.function.add_" + draft.hookType;
		final nativeKind = draft.hookType == "action" ? "hook" : "filter";
		final capabilities = ["wordpress." + nativeKind + "." + draft.hookName, capability];
		capabilities.sort(compareText);
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
			payload: HookPayload({
				hookName: draft.hookName,
				hookType: draft.hookType,
				callbackSymbol: module.namespace + "\\" + draft.callbackOwner + "::" + draft.callbackName,
				priority: draft.priority,
				acceptedArgs: draft.acceptedArgs
			})
		};
	}

	static function developmentServiceNode(draft:DevelopmentServiceDraft):SemanticNode {
		final dependencies = [for (dependency in draft.dependsOn) "service/" + dependency];
		dependencies.sort(compareText);
		return {
			id: "service/" + draft.serviceId,
			kind: DEVELOPMENT_SERVICE_KIND,
			schemaId: DEVELOPMENT_SERVICE_SCHEMA,
			source: draft.span,
			relatedSources: [],
			dependsOn: dependencies,
			profileCapabilities: [],
			projections: [
				{
					projectionId: "dev/service/" + draft.serviceId,
					emitterId: DEVELOPMENT_SERVICE_EMITTER,
					artifactKind: "development.service"
				}
			],
			payload: DevelopmentPayload(draft.data)
		};
	}

	static function developmentServiceData(serviceKind:DevelopmentServiceKind, options:Null<Expr>, session:CollectorSession):DevelopmentServiceData {
		final position = options == null ? Context.currentPos() : options.pos;
		final optionalFields = [
			"dependsOn",
			"environment",
			"preferredPort",
			"readinessIntervalMs",
			"readinessKind",
			"readinessPath",
			"readinessText",
			"readinessTimeoutMs",
			"restartAttempts",
			"restartBackoffMs",
			"strictPort",
			"urlPath",
			"workingDirectory"
		];
		final fields:Map<String, Expr> = switch serviceKind {
			case WordPressService:
				optionalFields.push("id");
				options == null ? [] : objectFields(options, [], optionalFields);
			case ExternalService:
				if (options == null) {
					fail("WPHX4183", "Dev.service requires a literal options object", position);
				}
				objectFields(options, ["command", "id"], optionalFields);
		};
		final serviceId = fields.exists("id") ? literalString(fields.get("id"), "WPHX4184", "development service id") : "wordpress";
		requirePattern(STABLE_ID, serviceId, "WPHX4184", "development service id is not stable", position);
		final workingDirectoryValue = fields.exists("workingDirectory") ? literalString(fields.get("workingDirectory"), "WPHX4185",
			"development service working directory") : ".";
		final workingDirectory = projectDirectory(workingDirectoryValue, "WPHX4185", "development service working directory", position);
		final dependencies = fields.exists("dependsOn") ? literalStringArray(fields.get("dependsOn"), "WPHX4186", "development service dependencies") : [];
		for (dependency in dependencies) {
			requirePattern(STABLE_ID, dependency, "WPHX4186", "development service dependency is not stable", fields.get("dependsOn").pos);
		}
		sortUnique(dependencies, "WPHX4186", "development service dependencies", position);

		final environment = fields.exists("environment") ? literalStringArray(fields.get("environment"), "WPHX4187", "development service environment") : [];
		for (name in environment) {
			requirePattern(ENVIRONMENT_NAME, name, "WPHX4187", "development service environment name is invalid", fields.get("environment").pos);
		}
		sortUnique(environment, "WPHX4187", "development service environment", position);

		final command:Null<DevelopmentCommand> = switch serviceKind {
			case WordPressService: null;
			case ExternalService:
				final commandFields = objectFields(fields.get("command"), ["component"], ["arguments"]);
				final component = literalString(commandFields.get("component"), "WPHX4188", "development command component");
				requirePattern(STABLE_ID, component, "WPHX4188", "development command component is not stable", commandFields.get("component").pos);
				if (!toolExists(session.tools, component)) {
					fail("WPHX4188", "development command component is absent from the exact project lock: " + component, commandFields.get("component").pos);
				}
				{
					component: component,
					executable: developmentExecutable(component, commandFields.get("component").pos),
					arguments: commandFields.exists("arguments") ? literalStringArray(commandFields.get("arguments"), "WPHX4190",
						"development command arguments") : []
				};
		};

		final preferredPort = fields.exists("preferredPort") ? literalInteger(fields.get("preferredPort"), "WPHX4191",
			"development service preferred port") : switch serviceKind {
				case WordPressService: 8888;
				case ExternalService: 8080;
			};
		final strictPort = fields.exists("strictPort") ? literalBoolean(fields.get("strictPort"), "WPHX4192", "development service strict port") : false;
		final readinessKindName = fields.exists("readinessKind") ? literalReadinessKind(fields.get("readinessKind"), "WPHX4193",
			"development readiness kind") : "http";
		final readinessPath = fields.exists("readinessPath") ? literalString(fields.get("readinessPath"), "WPHX4194",
			"development readiness path") : switch serviceKind {
				case WordPressService: "/wp-json/";
				case ExternalService: "/";
			};
		final readinessText = fields.exists("readinessText") ? literalString(fields.get("readinessText"), "WPHX4195", "development readiness text") : "";
		final readinessTimeoutMs = fields.exists("readinessTimeoutMs") ? literalInteger(fields.get("readinessTimeoutMs"), "WPHX4196",
			"development readiness timeout") : 60000;
		final readinessIntervalMs = fields.exists("readinessIntervalMs") ? literalInteger(fields.get("readinessIntervalMs"), "WPHX4197",
			"development readiness interval") : 100;
		final restartAttempts = fields.exists("restartAttempts") ? literalInteger(fields.get("restartAttempts"), "WPHX4198",
			"development restart attempts") : 1;
		final restartBackoffMs = fields.exists("restartBackoffMs") ? literalInteger(fields.get("restartBackoffMs"), "WPHX4199",
			"development restart backoff") : 250;
		final urlPath = fields.exists("urlPath") ? literalString(fields.get("urlPath"), "WPHX4200", "development service URL path") : "/";
		final reload = switch serviceKind {
			case WordPressService: FullPageReload;
			case ExternalService: NoReload;
		};
		final readiness = parseReadinessKind(readinessKindName, position);

		final data:DevelopmentServiceData = {
			serviceId: serviceId,
			serviceKind: serviceKind,
			dependsOn: dependencies,
			workingDirectory: workingDirectory,
			command: command,
			environment: environment,
			port: {
				preferred: preferredPort,
				strict: strictPort
			},
			readiness: {
				kind: readiness,
				path: readinessPath,
				text: readinessText,
				timeoutMs: readinessTimeoutMs,
				intervalMs: readinessIntervalMs
			},
			restart: {
				maxAttempts: restartAttempts,
				backoffMs: restartBackoffMs
			},
			url: {
				scheme: "http",
				path: urlPath
			},
			reload: reload
		};
		validateDevelopmentServiceData(data, session, position);
		return data;
	}

	static function decodeDevelopmentService(value:JsonValue, session:CollectorSession, position:Position):DevelopmentServiceData {
		return readJson(position, () -> {
			final service = JsonObjectReader.from(value, "development service", "WPHX4183");
			service.exact([
				"command",
				"dependsOn",
				"environment",
				"port",
				"readiness",
				"reload",
				"restart",
				"serviceId",
				"serviceKind",
				"url",
				"workingDirectory"
			], "WPHX4183");
			final command:Null<DevelopmentCommand> = switch service.value("command", "WPHX4188") {
				case NullValue: null;
				case value:
					final command = JsonObjectReader.from(value, "development service.command", "WPHX4188");
					command.exact(["arguments", "component", "executable"], "WPHX4188");
					{
						component: command.string("component", "WPHX4188"),
						executable: command.string("executable", "WPHX4189"),
						arguments: command.strings("arguments", "WPHX4190")
					};
			};
			final port = service.object("port", "WPHX4191");
			port.exact(["preferred", "strict"], "WPHX4191");
			final readiness = service.object("readiness", "WPHX4193");
			readiness.exact(["intervalMs", "kind", "path", "text", "timeoutMs"], "WPHX4193");
			final restart = service.object("restart", "WPHX4198");
			restart.exact(["backoffMs", "maxAttempts"], "WPHX4198");
			final url = service.object("url", "WPHX4200");
			url.exact(["path", "scheme"], "WPHX4200");
			final data:DevelopmentServiceData = {
				serviceId: service.string("serviceId", "WPHX4184"),
				serviceKind: parseServiceKind(service.string("serviceKind", "WPHX4180"), position),
				dependsOn: service.strings("dependsOn", "WPHX4186"),
				workingDirectory: service.string("workingDirectory", "WPHX4185"),
				command: command,
				environment: service.strings("environment", "WPHX4187"),
				port: {
					preferred: port.integer("preferred", "WPHX4191"),
					strict: port.boolean("strict", "WPHX4192")
				},
				readiness: {
					kind: parseReadinessKind(readiness.string("kind", "WPHX4193"), position),
					path: readiness.string("path", "WPHX4194"),
					text: readiness.string("text", "WPHX4195"),
					timeoutMs: readiness.integer("timeoutMs", "WPHX4196"),
					intervalMs: readiness.integer("intervalMs", "WPHX4197")
				},
				restart: {
					maxAttempts: restart.integer("maxAttempts", "WPHX4198"),
					backoffMs: restart.integer("backoffMs", "WPHX4199")
				},
				url: {
					scheme: url.string("scheme", "WPHX4200"),
					path: url.string("path", "WPHX4200")
				},
				reload: parseReloadKind(service.string("reload", "WPHX4201"), position)
			};
			validateDevelopmentServiceData(data, session, position);
			return data;
		});
	}

	static function validateDevelopmentServiceData(data:DevelopmentServiceData, session:CollectorSession, position:Position):Void {
		requirePattern(STABLE_ID, data.serviceId, "WPHX4184", "development service id is not stable", position);
		projectDirectory(data.workingDirectory, "WPHX4185", "development service working directory", position);

		for (dependency in data.dependsOn) {
			requirePattern(STABLE_ID, dependency, "WPHX4186", "development service dependency is not stable", position);
			if (dependency == data.serviceId) {
				fail("WPHX4182", "development service cannot depend on itself: " + data.serviceId, position);
			}
		}
		requireSortedUnique(data.dependsOn, "WPHX4186", "development service dependencies", position);

		for (name in data.environment) {
			requirePattern(ENVIRONMENT_NAME, name, "WPHX4187", "development service environment name is invalid", position);
			final rule = session.config.runtimeEnvironment.get(name);
			if (rule == null || rule.services.indexOf(data.serviceId) < 0) {
				fail("WPHX4187", "runtime environment " + name + " is not admitted for development service " + data.serviceId, position);
			}
		}
		requireSortedUnique(data.environment, "WPHX4187", "development service environment", position);

		switch data.serviceKind {
			case WordPressService:
				if (data.command != null) {
					fail("WPHX4188", "the SDK-owned WordPress provider must not declare a raw command", position);
				}
			case ExternalService:
				final command = requireDevelopmentCommand(data.command, position);
				requirePattern(STABLE_ID, command.component, "WPHX4188", "development command component is not stable", position);
				if (!toolExists(session.tools, command.component)) {
					fail("WPHX4188", "development command component is absent from the exact project lock: " + command.component, position);
				}
				requirePattern(EXECUTABLE_NAME, command.executable, "WPHX4189", "development command executable must be a portable basename", position);
				final expectedExecutable = developmentExecutable(command.component, position);
				if (command.executable != expectedExecutable) {
					fail("WPHX4189", "development command executable contradicts the SDK mapping for " + command.component, position);
				}
				var portTokens = 0;
				for (argument in command.arguments) {
					if (argument.indexOf("{port}") >= 0) {
						portTokens++;
					}
				}
				if (portTokens > 1) {
					fail("WPHX4190", "development command may contain {port} in at most one argument", position);
				}
		}

		if (data.port.preferred < 1 || data.port.preferred > 65535) {
			fail("WPHX4191", "development service preferred port must be between 1 and 65535", position);
		}

		absoluteUrlPath(data.readiness.path, "WPHX4194", "development readiness path", position);
		final logReadiness = switch data.readiness.kind {
			case LogReadiness: true;
			case _: false;
		};
		if (logReadiness != (data.readiness.text.length > 0)) {
			fail("WPHX4195", "only log readiness requires non-empty readinessText", position);
		}
		if (data.readiness.timeoutMs < 100 || data.readiness.timeoutMs > 300000) {
			fail("WPHX4196", "development readiness timeout must be between 100 and 300000 milliseconds", position);
		}
		if (data.readiness.intervalMs < 10 || data.readiness.intervalMs > 5000 || data.readiness.intervalMs > data.readiness.timeoutMs) {
			fail("WPHX4197", "development readiness interval must be between 10 and 5000 milliseconds and not exceed timeout", position);
		}

		if (data.restart.maxAttempts < 0 || data.restart.maxAttempts > 10) {
			fail("WPHX4198", "development restart attempts must be between 0 and 10", position);
		}
		if (data.restart.backoffMs < 0 || data.restart.backoffMs > 60000) {
			fail("WPHX4199", "development restart backoff must be between 0 and 60000 milliseconds", position);
		}

		if (data.url.scheme != "http") {
			fail("WPHX4200", "development service URL scheme must be http in collector v1", position);
		}
		absoluteUrlPath(data.url.path, "WPHX4200", "development service URL path", position);
		final expectedReload = switch data.serviceKind {
			case WordPressService: FullPageReload;
			case ExternalService: NoReload;
		};
		if (data.reload != expectedReload) {
			fail("WPHX4201", "development service reload behavior contradicts its provider", position);
		}
	}

	static function requireDevelopmentCommand(command:Null<DevelopmentCommand>, position:Position):DevelopmentCommand {
		if (command == null) {
			return fail("WPHX4188", "an external development service requires a raw command", position);
		}
		return command;
	}

	static function parseServiceKind(value:String, position:Position):DevelopmentServiceKind {
		return switch value {
			case "wordpress": WordPressService;
			case "external": ExternalService;
			case _: fail("WPHX4180", "development service provider is outside the closed set", position);
		};
	}

	static function parseReadinessKind(value:String, position:Position):DevelopmentReadinessKind {
		return switch value {
			case "http": HttpReadiness;
			case "log": LogReadiness;
			case "process": ProcessReadiness;
			case "tcp": TcpReadiness;
			case _: fail("WPHX4193", "development readiness kind is outside the closed set", position);
		};
	}

	static function parseReloadKind(value:String, position:Position):DevelopmentReloadKind {
		return switch value {
			case "full-page": FullPageReload;
			case "none": NoReload;
			case _: fail("WPHX4201", "development reload behavior is outside the closed set", position);
		};
	}

	static function validateDevelopmentServiceRegistration(schemas:Array<NodeSchemaConfig>, position:Position):Void {
		for (schema in schemas) {
			if (schema.schemaId == DEVELOPMENT_SERVICE_SCHEMA) {
				if (schema.kind != DEVELOPMENT_SERVICE_KIND
					|| schema.authority != "core"
					|| schema.consumerEmitters.indexOf(DEVELOPMENT_SERVICE_EMITTER) < 0) {
					fail("WPHX4202", "development service schema registration contradicts the core contract", position);
				}
				return;
			}
		}
		fail("WPHX4202", "typed development services require the core development service node schema", position);
	}

	static function detectDevelopmentServiceCycles(services:Map<String, DevelopmentServiceDraft>):Void {
		final states:Map<String, Int> = [];
		var visit:String->Void = null;
		visit = serviceId -> {
			final state = states.exists(serviceId) ? states.get(serviceId) : 0;
			if (state == 2) {
				return;
			}
			if (state == 1) {
				final service = services.get(serviceId);
				fail("WPHX4203", "development service dependency graph contains a cycle at " + serviceId, service.position);
			}
			states.set(serviceId, 1);
			final service = services.get(serviceId);
			for (dependency in service.dependsOn) {
				visit(dependency);
			}
			states.set(serviceId, 2);
		};
		final ids = [for (serviceId in services.keys()) serviceId];
		ids.sort(compareText);
		for (serviceId in ids) {
			visit(serviceId);
		}
	}

	static function nodeSchemaRecord(value:NodeSchemaConfig):NodeSchemaRecord {
		return {
			schemaId: value.schemaId,
			kind: value.kind,
			version: value.version,
			authority: value.authority,
			extensionId: value.extensionId,
			schemaSha256: value.schemaSha256,
			consumerEmitters: value.consumerEmitters.copy()
		};
	}

	static function validateConfig(value:JsonValue, root:String, position:Position):CollectorConfig {
		return readJson(position, () -> {
			final config = JsonObjectReader.from(value, "collector config", "WPHX4050");
			final hasRuntimeEnvironment = config.has("runtimeEnvironment");
			final configFields = [
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
			];
			if (hasRuntimeEnvironment) {
				configFields.push("runtimeEnvironment");
			}
			config.exact(configFields, "WPHX4050");
			if (config.string("schema", "WPHX4051") != "wordpress-hx.semantic-collector-config.v1"
				|| config.string("canonicalization", "WPHX4052") != CANONICALIZATION) {
				fail("WPHX4053", "unsupported collector config contract", position);
			}
			final sdkVersion = semanticVersion(config.string("sdkVersion", "WPHX4054"), "SDK version", position);
			final collectorVersion = semanticVersion(config.string("collectorVersion", "WPHX4055"), "collector version", position);
			final project = config.object("project", "WPHX4056");
			project.exact(["id", "version"], "WPHX4056");
			final projectId = project.string("id", "WPHX4057");
			requirePattern(STABLE_ID, projectId, "WPHX4058", "project id is not stable", position);
			final projectVersion = semanticVersion(project.string("version", "WPHX4059"), "project version", position);

			final profile = config.object("profile", "WPHX4060");
			profile.exact(["catalogFileSha256", "catalogPath", "catalogRevision", "catalogSha256", "id"], "WPHX4060");
			final profileConfig:ProfileConfig = {
				id: profile.string("id", "WPHX4061"),
				catalogRevision: profile.string("catalogRevision", "WPHX4062"),
				catalogPath: safeRelativePath(profile.string("catalogPath", "WPHX4063"), "WPHX4064", "profile catalog path", position),
				catalogSha256: digestValue(profile.string("catalogSha256", "WPHX4065"), "WPHX4065", "collector profile.catalogSha256", position),
				catalogFileSha256: digestValue(profile.string("catalogFileSha256", "WPHX4066"), "WPHX4066", "collector profile.catalogFileSha256", position)
			};
			requirePattern(STABLE_ID, profileConfig.id, "WPHX4067", "profile id is not stable", position);
			if (profileConfig.catalogRevision.indexOf(profileConfig.id + "/") != 0) {
				fail("WPHX4068", "profile catalog revision contradicts profile id", position);
			}

			final lock = config.object("toolchainLock", "WPHX4069");
			lock.exact(["path", "sha256"], "WPHX4069");
			final toolchainPath = safeRelativePath(lock.string("path", "WPHX4070"), "WPHX4071", "toolchain lock path", position);
			final toolchainSha256 = digestValue(lock.string("sha256", "WPHX4072"), "WPHX4072", "toolchain lock.sha256", position);

			final resourceRoots = config.strings("resourceRoots", "WPHX4073");
			for (index in 0...resourceRoots.length) {
				resourceRoots[index] = safeRelativePath(resourceRoots[index], "WPHX4075", "resource root", position);
			}
			if (resourceRoots.length == 0) {
				fail("WPHX4076", "collector config requires at least one resource root", position);
			}
			sortUnique(resourceRoots, "WPHX4076", "resource roots", position);

			final environment:Map<String, EnvironmentRule> = [];
			for (value in config.array("environment", "WPHX4077")) {
				final entry = JsonObjectReader.from(value, "build environment rule", "WPHX4078");
				final hasDefault = entry.has("default");
				entry.exact(hasDefault ? ["classification", "default", "name", "required"] : ["classification", "name", "required"], "WPHX4078");
				if (entry.string("classification", "WPHX4079") != "public-build") {
					fail("WPHX4080", "collector may read public-build environment only", position);
				}
				final name = entry.string("name", "WPHX4081");
				requirePattern(ENVIRONMENT_NAME, name, "WPHX4082", "build environment name is invalid", position);
				if (environment.exists(name)) {
					fail("WPHX4083", "duplicate build environment rule " + name, position);
				}
				final required = entry.boolean("required", "WPHX4084");
				final defaultValue = entry.optionalString("default", "WPHX4085");
				if (required && defaultValue != null) {
					fail("WPHX4086", "required build environment input cannot also have a default", position);
				}
				environment.set(name, {required: required, defaultValue: defaultValue});
			}

			final runtimeEnvironment:Map<String, RuntimeEnvironmentRule> = [];
			if (hasRuntimeEnvironment) {
				for (value in config.array("runtimeEnvironment", "WPHX4204")) {
					final entry = JsonObjectReader.from(value, "runtime environment rule", "WPHX4204");
					entry.exact(["classification", "name", "required", "services"], "WPHX4204");
					final name = entry.string("name", "WPHX4204");
					requirePattern(ENVIRONMENT_NAME, name, "WPHX4204", "runtime environment name is invalid", position);
					if (environment.exists(name) || runtimeEnvironment.exists(name)) {
						fail("WPHX4204", "build and runtime environment names must be disjoint and unique: " + name, position);
					}
					final classification = entry.string("classification", "WPHX4204");
					if (classification != "public-runtime" && classification != "secret-runtime") {
						fail("WPHX4204", "runtime environment classification is outside the closed set", position);
					}
					final services = entry.strings("services", "WPHX4204");
					for (serviceId in services) {
						requirePattern(STABLE_ID, serviceId, "WPHX4204", "runtime environment service is not stable", position);
					}
					if (services.length == 0) {
						fail("WPHX4204", "runtime environment rule must admit at least one service", position);
					}
					requireSortedUnique(services, "WPHX4204", "runtime environment services", position);
					runtimeEnvironment.set(name, {
						required: entry.boolean("required", "WPHX4204"),
						classification: classification,
						services: services
					});
				}
			}

			final nodeSchemas:Array<NodeSchemaConfig> = [];
			final schemaIds:Map<String, Bool> = [];
			for (value in config.array("nodeSchemas", "WPHX4087")) {
				final entry = JsonObjectReader.from(value, "node schema registration", "WPHX4088");
				final hasExtension = entry.has("extensionId");
				entry.exact(hasExtension ? [
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
				], "WPHX4088");
				final schemaId = entry.string("schemaId", "WPHX4089");
				requirePattern(STABLE_ID, schemaId, "WPHX4089", "node schema id is not stable", position);
				if (schemaIds.exists(schemaId)) {
					fail("WPHX4090", "duplicate node schema registration " + schemaId, position);
				}
				schemaIds.set(schemaId, true);
				final authority = entry.string("authority", "WPHX4091");
				if (authority != "core" && authority != "extension") {
					fail("WPHX4092", "node schema authority must be core or extension", position);
				}
				if ((authority == "extension") != hasExtension) {
					fail("WPHX4093", "only an extension node schema must declare extensionId", position);
				}
				final extensionId = entry.optionalString("extensionId", "WPHX4100");
				if (extensionId != null) {
					requirePattern(STABLE_ID, extensionId, "WPHX4100", "extension id is not stable", position);
				}
				final emitters = entry.strings("consumerEmitters", "WPHX4094");
				for (emitterId in emitters) {
					requirePattern(STABLE_ID, emitterId, "WPHX4095", "node schema emitter id is not stable", position);
				}
				if (emitters.length == 0) {
					fail("WPHX4096", "node schema requires at least one consumer emitter", position);
				}
				sortUnique(emitters, "WPHX4096", "node schema emitters", position);
				final version = entry.integer("version", "WPHX4097");
				if (version < 1 || !StringTools.endsWith(schemaId, ".v" + version)) {
					fail("WPHX4098", "node schema version contradicts schema id", position);
				}
				final kind = entry.string("kind", "WPHX4099");
				requirePattern(STABLE_ID, kind, "WPHX4099", "node schema kind is not stable", position);
				if ((schemaId == "wordpress-hx.semantic-node.wordpress.hook.v1" && kind != "wordpress.hook")
					|| (schemaId == "wordpress-hx.semantic-node.wordpress.module.v1" && kind != "wordpress.module")
					|| (schemaId == DEVELOPMENT_SERVICE_SCHEMA && kind != DEVELOPMENT_SERVICE_KIND)) {
					fail("WPHX4099", "core node schema kind contradicts its schema id", position);
				}
				nodeSchemas.push({
					schemaId: schemaId,
					kind: kind,
					version: version,
					authority: authority,
					extensionId: extensionId,
					path: safeRelativePath(entry.string("path", "WPHX4101"), "WPHX4102", "node schema path", position),
					schemaSha256: digestValue(entry.string("schemaSha256", "WPHX4103"), "WPHX4103", "node schema registration.schemaSha256", position),
					consumerEmitters: emitters
				});
			}
			nodeSchemas.sort((left, right) -> compareText(left.schemaId, right.schemaId));
			for (required in [
				"wordpress-hx.semantic-node.wordpress.hook.v1",
				"wordpress-hx.semantic-node.wordpress.module.v1"
			]) {
				if (!schemaIds.exists(required)) {
					fail("WPHX4104", "collector v1 requires node schema " + required, position);
				}
			}

			final validated:CollectorConfig = {
				sdkVersion: sdkVersion,
				collectorVersion: collectorVersion,
				projectId: projectId,
				projectVersion: projectVersion,
				profile: profileConfig,
				toolchainPath: toolchainPath,
				toolchainSha256: toolchainSha256,
				resourceRoots: resourceRoots,
				environment: environment,
				runtimeEnvironment: runtimeEnvironment,
				nodeSchemas: nodeSchemas
			};
			return validated;
		});
	}

	static function validateCatalog(value:JsonValue, config:CollectorConfig, position:Position):Void {
		readJson(position, () -> {
			final document = JsonObjectReader.from(value, "profile catalog", "WPHX4110");
			final catalog = document.object("catalog", "WPHX4110");
			if (catalog.string("profileId", "WPHX4110") != config.profile.id
				|| catalog.string("catalogRevision", "WPHX4111") != config.profile.catalogRevision
				|| document.string("catalogDigest", "WPHX4112") != config.profile.catalogSha256) {
				fail("WPHX4113", "profile catalog identity or semantic digest mismatch", position);
			}
		});
	}

	static function catalogCapabilities(value:JsonValue, position:Position):Map<String, Bool> {
		return readJson(position, () -> {
			final capabilities:Map<String, Bool> = [];
			final catalog = JsonObjectReader.from(value, "profile catalog", "WPHX4114").object("catalog", "WPHX4114");
			for (value in catalog.array("capabilities", "WPHX4114")) {
				final entry = JsonObjectReader.from(value, "profile capability", "WPHX4115");
				capabilities.set(entry.string("capabilityId", "WPHX4115"), true);
			}
			return capabilities;
		});
	}

	static function validateToolchain(value:JsonValue, config:CollectorConfig, position:Position):Array<ToolRecord> {
		return readJson(position, () -> {
			final lock = JsonObjectReader.from(value, "toolchain lock", "WPHX4120");
			if (lock.string("schema", "WPHX4120") != "wordpress-hx.project-lock.v1") {
				fail("WPHX4121", "unsupported generated project lock", position);
			}
			final project = lock.object("project", "WPHX4122");
			final profile = lock.object("profile", "WPHX4123");
			if (project.string("id", "WPHX4122") != config.projectId
				|| profile.string("id", "WPHX4123") != config.profile.id
				|| profile.string("catalogRevision", "WPHX4124") != config.profile.catalogRevision
				|| profile.string("catalogSha256", "WPHX4125") != config.profile.catalogSha256) {
				fail("WPHX4126", "toolchain lock contradicts collector project/profile", position);
			}
			final tools:Array<ToolRecord> = [];
			for (value in lock.array("components", "WPHX4127")) {
				final entry = JsonObjectReader.from(value, "toolchain component", "WPHX4128");
				tools.push({
					id: entry.string("id", "WPHX4128"),
					version: entry.string("version", "WPHX4129"),
					identity: entry.string("identity", "WPHX4130"),
					lockEntrySha256: digestValue(entry.string("lockEntrySha256", "WPHX4131"), "WPHX4131", "toolchain component.lockEntrySha256", position)
				});
			}
			tools.sort((left, right) -> compareText(left.id, right.id));
			return tools;
		});
	}

	static function sourceSpan(position:Position, symbol:String, session:CollectorSession):SourceSpan {
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

	static function point(bytes:Bytes, offset:Int, position:Position):SourcePoint {
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
				} catch (error:CanonicalJsonError) {
					fail(code, error.message, expression.pos);
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

	static function literalBoolean(expression:Expr, code:String, label:String):Bool {
		return switch expression.expr {
			case EConst(CIdent("true")): true;
			case EConst(CIdent("false")): false;
			case _: fail(code, label + " must be a boolean literal", expression.pos);
		};
	}

	static function literalReadinessKind(expression:Expr, code:String, label:String):String {
		if (!Context.unify(Context.typeof(expression), Context.getType("wordpress.hx.build.semantic.DevelopmentReadinessKind"))) {
			fail(code, label + " must be a DevelopmentReadinessKind value", expression.pos);
		}
		final name = switch expression.expr {
			case EConst(CIdent(name)): name;
			case EField(_, name): name;
			case _: fail(code, label + " must be a DevelopmentReadinessKind value", expression.pos);
		};
		return switch name {
			case "Http": "http";
			case "Log": "log";
			case "Process": "process";
			case "Tcp": "tcp";
			case _: fail(code, label + " must be a DevelopmentReadinessKind value", expression.pos);
		};
	}

	static function literalStringArray(expression:Expr, code:String, label:String):Array<String> {
		final values = switch expression.expr {
			case EArrayDecl(items): items;
			case _: fail(code, label + " must be an array literal", expression.pos);
		};
		return [
			for (index in 0...values.length)
				literalString(values[index], code, label + "[" + index + "]")
		];
	}

	static function optionalExpression(expression:Null<Expr>):Null<Expr> {
		if (expression == null) {
			return null;
		}
		return switch expression.expr {
			case EConst(CIdent("null")): null;
			case _: expression;
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
		} catch (error:Exception) {
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
			try {
				CanonicalJson.requireCanonicalString(part, label);
			} catch (error:CanonicalJsonError) {
				fail(code, error.message, position);
			}
		}
		return parts.join("/");
	}

	static function projectDirectory(value:String, code:String, label:String, position:Position):String {
		if (value == ".") {
			return value;
		}
		return safeRelativePath(value, code, label, position);
	}

	static function absoluteUrlPath(value:String, code:String, label:String, position:Position):String {
		if (value.length == 0 || value.charAt(0) != "/" || value.indexOf("\\") >= 0 || value.indexOf("?") >= 0 || value.indexOf("#") >= 0) {
			fail(code, label + " must begin with / and contain no query, fragment, or backslash", position);
		}
		try {
			CanonicalJson.requireCanonicalString(value, label);
		} catch (error:CanonicalJsonError) {
			fail(code, error.message, position);
		}
		return value;
	}

	static function toolExists(tools:Array<ToolRecord>, component:String):Bool {
		for (tool in tools) {
			if (tool.id == component) {
				return true;
			}
		}
		return false;
	}

	static function developmentExecutable(component:String, position:Position):String {
		return switch component {
			case "compiler.haxe": "haxe";
			case "runtime.node": "node";
			case "tool.lix": "lix";
			case "tool.npm": "npm";
			case "tool.wordpress-scripts": "wp-scripts";
			case _:
				fail("WPHX4189", "development command component has no SDK-admitted executable mapping: " + component, position);
		};
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

	static function digestValue(value:String, code:String, label:String, position:Position):String {
		requirePattern(SHA256, value, code, label + " must be a lowercase SHA-256", position);
		return value;
	}

	static function sortUnique(values:Array<String>, code:String, label:String, position:Position):Void {
		values.sort(compareText);
		for (index in 1...values.length) {
			if (values[index - 1] == values[index]) {
				fail(code, label + " contains duplicate " + values[index], position);
			}
		}
	}

	static function requireSortedUnique(values:Array<String>, code:String, label:String, position:Position):Void {
		for (index in 1...values.length) {
			if (compareText(values[index - 1], values[index]) >= 0) {
				fail(code, label + " must be sorted and unique", position);
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

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function parseJson(content:String, code:String, label:String, position:Position):JsonValue {
		try {
			return JsonParser.parse(content);
		} catch (error:JsonParseError) {
			return fail(code, label + " is not valid JSON: " + error.message, position);
		}
	}

	static function readJson<T>(position:Position, operation:Void->T):T {
		try {
			return operation();
		} catch (error:JsonReadError) {
			return fail(error.code, error.message, position);
		}
	}

	static function fail<T>(code:String, message:String, position:Position):T {
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
	final tools:Array<ToolRecord>;
	final files:Map<String, InputFile>;
	final collectorSourceSha256:String;
	final modules:Array<ModuleDraft>;
	final hooks:Array<HookDraft>;
	final resources:Array<ResourceDraft>;
	final environments:Array<EnvironmentDraft>;
	final services:Array<DevelopmentServiceDraft>;
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
	final runtimeEnvironment:Map<String, RuntimeEnvironmentRule>;
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

private typedef RuntimeEnvironmentRule = {
	final required:Bool;
	final classification:String;
	final services:Array<String>;
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
	final span:SourceSpan;
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
	final span:SourceSpan;
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

private typedef DevelopmentServiceDraft = {
	final serviceId:String;
	final dependsOn:Array<String>;
	final data:DevelopmentServiceData;
	final span:SourceSpan;
	final position:Position;
}
#end
