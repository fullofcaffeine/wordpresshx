package wordpresshx.cli.project.development;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.CanonicalJson.CanonicalJsonError;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonReader.JsonReadError;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectContext;
import wordpresshx.cli.project.ProjectFiles;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentCommand;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReadinessKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReloadKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentServiceKind;

private typedef PlanNodeRecord = {
	final id:String;
	final dependencies:Array<String>;
}

/** Authenticates the current compiler-produced service plan. */
class DevelopmentPlanReader {
	public static inline final PLAN_PATH = ".wphx/runtime/semantic-plan.next.json";
	static inline final SERVICE_SCHEMA_ID = "wordpress-hx.semantic-node.development.service.v1";
	static inline final SERVICE_SCHEMA_SHA256 = "0e344463d1316909a97a08a2381f9ee6c7cd5a57fd158952b0ac8cab9b911d57";
	static final STABLE_ID = ~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/;
	static final SCHEMA_ID = ~/^[a-z][a-z0-9-]*(?:\.[a-z0-9-]+)+\.v[1-9][0-9]*$/;
	static final SHA256 = ~/^[0-9a-f]{64}$/;
	static final ENVIRONMENT_NAME = ~/^[A-Z][A-Z0-9_]*$/;
	static final EXECUTABLE = ~/^[A-Za-z0-9._+\-]+$/;
	static final RELATIVE_PATH = ~/^[A-Za-z0-9._@+\-]+(?:\/[A-Za-z0-9._@+\-]+)*$/;
	static final URL_PATH = ~/^\/[A-Za-z0-9._~!$&'()*+,;=:@%\/\-]*$/;

	public static function prepare(context:ProjectContext):Void {
		ProjectFiles.requireDirectory(context.bootstrap.root, ".wphx/runtime", "development runtime directory", "service-start");
		final absolute = Path.resolve(context.bootstrap.root, PLAN_PATH);
		if (!Fs.existsSync(absolute)) {
			return;
		}
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			invalid("WPHX2310", "generated development plan path is not a regular file");
		}
		Fs.unlinkSync(absolute);
	}

	public static function load(context:ProjectContext, project:DevelopmentProject):DevelopmentPlan {
		if (!hasExplicit(context)) {
			return project.deployablePlugin == null ? DevelopmentPlan.empty(project.toolchainSha256) : DevelopmentPlan.forPlugin(project.toolchainSha256);
		}
		if (!ProjectFiles.existsRegular(context.bootstrap.root, PLAN_PATH)) {
			return invalid("WPHX2310", "generated development plan path is not a regular file");
		}
		try {
			final buffer = ProjectFiles.read(context.bootstrap.root, PLAN_PATH, "generated development plan", "service-start");
			final source = decodeUtf8(buffer);
			final value = JsonParser.parse(source);
			if (source != CanonicalJson.encode(value) + "\n") {
				return invalid("WPHX2310", "generated development plan is not canonical JSON");
			}
			return decode(value, project);
		} catch (error:JsonParseError) {
			return invalid("WPHX2310", "generated development plan is malformed: " + error.message);
		} catch (error:JsonReadError) {
			return invalid(error.code, error.message);
		} catch (error:CanonicalJsonError) {
			return invalid("WPHX2310", error.message);
		}
	}

	public static function hasExplicit(context:ProjectContext):Bool {
		return ProjectFiles.exists(context.bootstrap.root, PLAN_PATH);
	}

	static function decode(value:JsonValue, project:DevelopmentProject):DevelopmentPlan {
		final plan = JsonReader.from(value, "semantic plan", "WPHX2310");
		plan.exact([
			"canonicalization",
			"generator",
			"nodeSchemas",
			"nodes",
			"planDigest",
			"planDigestAlgorithm",
			"profile",
			"project",
			"schema"
		], "WPHX2310");
		expect(plan.string("schema", "WPHX2310"), "wordpress-hx.semantic-plan.v1", "semantic plan schema");
		expect(plan.string("canonicalization", "WPHX2310"), "wordpress-hx.canonical-json.v1", "semantic plan canonicalization");
		expect(plan.string("planDigestAlgorithm", "WPHX2310"), "sha256-canonical-json-without-planDigest-v1", "semantic plan digest algorithm");
		final planDigest = sha256(plan.string("planDigest", "WPHX2310"), "semantic plan digest");
		if (CanonicalJson.digest(CanonicalJson.withoutField(value, "planDigest")) != planDigest) {
			invalid("WPHX2311", "semantic plan self-digest mismatch");
		}

		final generator = plan.object("generator", "WPHX2310");
		generator.exact([
			"collectorId",
			"collectorSourceSha256",
			"collectorVersion",
			"sdkVersion",
			"toolchainSha256"
		], "WPHX2310");
		expect(generator.string("collectorId", "WPHX2310"), "wordpress-hx.build.semantic-plan", "semantic plan collector");
		expect(sha256(generator.string("toolchainSha256", "WPHX2310"), "semantic plan toolchain digest"), project.toolchainSha256,
			"semantic plan toolchain digest");

		final profile = plan.object("profile", "WPHX2310");
		profile.exact(["catalogRevision", "catalogSha256", "profileId"], "WPHX2310");
		expect(stableId(profile.string("profileId", "WPHX2310"), "semantic plan profile ID"), project.profileId, "semantic plan profile ID");
		expect(profile.string("catalogRevision", "WPHX2310"), project.catalogRevision, "semantic plan catalog revision");
		expect(sha256(profile.string("catalogSha256", "WPHX2310"), "semantic plan catalog digest"), project.catalogSha256, "semantic plan catalog digest");

		final projectRecord = plan.object("project", "WPHX2310");
		projectRecord.exact(["projectId", "projectVersion", "sourceTreeSha256"], "WPHX2310");
		expect(stableId(projectRecord.string("projectId", "WPHX2310"), "semantic plan project ID"), project.projectId, "semantic plan project ID");
		sha256(projectRecord.string("sourceTreeSha256", "WPHX2310"), "semantic plan source-tree digest");

		validateSchemaRegistry(plan.array("nodeSchemas", "WPHX2310"));
		final services:Array<DevelopmentService> = [];
		final servicePayloads:Array<JsonValue> = [];
		final nodes:Array<PlanNodeRecord> = [];
		var previousNode:Null<String> = null;
		for (nodeValue in plan.array("nodes", "WPHX2310")) {
			final node = JsonReader.from(nodeValue, "semantic node", "WPHX2310");
			node.exact([
				"dependsOn",
				"id",
				"kind",
				"payload",
				"profileCapabilities",
				"projections",
				"relatedSources",
				"schemaId",
				"source"
			], "WPHX2310");
			final id = stableId(node.string("id", "WPHX2310"), "semantic node ID");
			if (previousNode != null && compareText(previousNode, id) >= 0) {
				invalid("WPHX2310", "semantic nodes must be sorted and unique");
			}
			previousNode = id;
			final dependencies = sortedStableIds(node.strings("dependsOn", "WPHX2310"), "semantic node dependencies");
			nodes.push({id: id, dependencies: dependencies});
			validateSource(node.value("source", "WPHX2310"), "semantic node source");
			for (source in node.array("relatedSources", "WPHX2310")) {
				validateSource(source, "semantic node related source");
			}
			sortedStrings(node.strings("profileCapabilities", "WPHX2310"), "semantic node profile capabilities");
			validateProjections(node.array("projections", "WPHX2310"));
			final kind = stableId(node.string("kind", "WPHX2310"), "semantic node kind");
			final schemaId = schemaId(node.string("schemaId", "WPHX2310"), "semantic node schema ID");
			if (kind == "development.service") {
				expect(schemaId, SERVICE_SCHEMA_ID, "development service schema ID");
				final payload = node.value("payload", "WPHX2310");
				final service = decodeService(payload, project);
				expect(id, "service/" + service.id, "development service node ID");
				final expectedDependencies = [for (dependency in service.dependsOn) "service/" + dependency];
				if (dependencies.join("\n") != expectedDependencies.join("\n")) {
					invalid("WPHX2312", "development service envelope dependencies contradict its payload");
				}
				services.push(service);
				servicePayloads.push(payload);
			}
		}
		validateNodeDependencies(nodes);
		validateServiceGraph(services);
		return new DevelopmentPlan(DevelopmentPlan.digestServices(project.toolchainSha256, servicePayloads), services);
	}

	static function validateSchemaRegistry(values:Array<JsonValue>):Void {
		var previous:Null<String> = null;
		var serviceSchemaFound = false;
		for (value in values) {
			final registration = JsonReader.from(value, "semantic node schema registration", "WPHX2310");
			final expectedFields = registration.has("extensionId") ? [
				"authority",
				"consumerEmitters",
				"extensionId",
				"kind",
				"schemaId",
				"schemaSha256",
				"version"
			] : ["authority", "consumerEmitters", "kind", "schemaId", "schemaSha256", "version"];
			registration.exact(expectedFields, "WPHX2310");
			final id = schemaId(registration.string("schemaId", "WPHX2310"), "registered schema ID");
			if (previous != null && compareText(previous, id) >= 0) {
				invalid("WPHX2310", "semantic node schemas must be sorted and unique");
			}
			previous = id;
			final emitters = sortedStableIds(registration.strings("consumerEmitters", "WPHX2310"), "schema consumer emitters");
			if (id == SERVICE_SCHEMA_ID) {
				expect(registration.string("kind", "WPHX2310"), "development.service", "development service schema kind");
				expect(registration.string("authority", "WPHX2310"), "core", "development service schema authority");
				expect(sha256(registration.string("schemaSha256", "WPHX2310"), "development service schema digest"), SERVICE_SCHEMA_SHA256,
					"development service schema digest");
				if (registration.integer("version", "WPHX2310") != 1 || emitters.join("\n") != "wordpresshx.dev") {
					invalid("WPHX2310", "development service schema registration drifted");
				}
				serviceSchemaFound = true;
			}
		}
		if (!serviceSchemaFound) {
			invalid("WPHX2310", "semantic plan does not register the development service schema");
		}
	}

	static function decodeService(value:JsonValue, project:DevelopmentProject):DevelopmentService {
		final service = JsonReader.from(value, "development service", "WPHX2312");
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
		], "WPHX2312");
		final id = stableId(service.string("serviceId", "WPHX2312"), "development service ID");
		final kind = switch service.string("serviceKind", "WPHX2312") {
			case "external": External;
			case "wordpress": WordPress;
			case _: invalid("WPHX2312", "development service kind is outside the closed enum");
		};
		final dependencies = sortedStableIds(service.strings("dependsOn", "WPHX2312"), "development service dependencies");
		if (dependencies.indexOf(id) >= 0) {
			invalid("WPHX2312", "development service cannot depend on itself");
		}
		final workingDirectory = service.string("workingDirectory", "WPHX2312");
		if (workingDirectory != "." && !RELATIVE_PATH.match(workingDirectory)) {
			invalid("WPHX2312", "development service working directory is not project-relative");
		}
		final command = decodeCommand(service.value("command", "WPHX2312"), kind, project);
		final environment = sortedEnvironment(service.strings("environment", "WPHX2312"), id, project);
		final port = service.object("port", "WPHX2312");
		port.exact(["preferred", "strict"], "WPHX2312");
		final preferredPort = port.integer("preferred", "WPHX2312");
		if (preferredPort < 1 || preferredPort > 65535) {
			invalid("WPHX2312", "development service preferred port is outside 1...65535");
		}
		final readiness = service.object("readiness", "WPHX2312");
		readiness.exact(["intervalMs", "kind", "path", "text", "timeoutMs"], "WPHX2312");
		final readinessKind = switch readiness.string("kind", "WPHX2312") {
			case "http": Http;
			case "log": Log;
			case "process": Process;
			case "tcp": Tcp;
			case _: invalid("WPHX2312", "development readiness kind is outside the closed enum");
		};
		final readinessPath = urlPath(readiness.string("path", "WPHX2312"), "development readiness path");
		final readinessText = readiness.string("text", "WPHX2312");
		if ((readinessKind == Log) != (readinessText.length > 0)) {
			invalid("WPHX2312", "only log readiness requires non-empty readiness text");
		}
		final timeoutMs = readiness.integer("timeoutMs", "WPHX2312");
		final intervalMs = readiness.integer("intervalMs", "WPHX2312");
		if (timeoutMs < 100 || timeoutMs > 300000 || intervalMs < 10 || intervalMs > 5000 || intervalMs > timeoutMs) {
			invalid("WPHX2312", "development readiness bounds are invalid");
		}
		final restart = service.object("restart", "WPHX2312");
		restart.exact(["backoffMs", "maxAttempts"], "WPHX2312");
		final maxAttempts = restart.integer("maxAttempts", "WPHX2312");
		final backoffMs = restart.integer("backoffMs", "WPHX2312");
		if (maxAttempts < 0 || maxAttempts > 10 || backoffMs < 0 || backoffMs > 60000) {
			invalid("WPHX2312", "development restart bounds are invalid");
		}
		final url = service.object("url", "WPHX2312");
		url.exact(["path", "scheme"], "WPHX2312");
		final scheme = url.string("scheme", "WPHX2312");
		if (scheme != "http" && scheme != "https") {
			invalid("WPHX2312", "development service URL scheme is outside the closed enum");
		}
		final reload = switch service.string("reload", "WPHX2312") {
			case "full-page": FullPage;
			case "none": NoReload;
			case _: invalid("WPHX2312", "development reload kind is outside the closed enum");
		};
		return new DevelopmentService(id, kind, dependencies, workingDirectory, command, environment, {
			preferred: preferredPort,
			strict: port.boolean("strict", "WPHX2312")
		}, {
			kind: readinessKind,
			path: readinessPath,
			text: readinessText,
			timeoutMs: timeoutMs,
			intervalMs: intervalMs
		}, {
			maxAttempts: maxAttempts,
			backoffMs: backoffMs
		}, {
			scheme: scheme,
			path: urlPath(url.string("path", "WPHX2312"), "development service URL path")
		}, reload);
	}

	static function decodeCommand(value:JsonValue, kind:DevelopmentServiceKind, project:DevelopmentProject):Null<DevelopmentCommand> {
		return switch value {
			case NullValue:
				if (kind != WordPress) {
					invalid("WPHX2312", "external development service requires a command");
				}
				null;
			case ObjectValue(_):
				if (kind != External) {
					invalid("WPHX2312", "WordPress development service may not supply a command");
				}
				final command = JsonReader.from(value, "development service command", "WPHX2312");
				command.exact(["arguments", "component", "executable"], "WPHX2312");
				final component = stableId(command.string("component", "WPHX2312"), "development command component");
				if (!project.hasComponent(component)) {
					invalid("WPHX2312", "development command component is absent from the exact project lock");
				}
				final executable = command.string("executable", "WPHX2312");
				if (!EXECUTABLE.match(executable) || DevelopmentExecutable.forComponent(component) != executable) {
					invalid("WPHX2312", "development command executable contradicts its SDK-admitted component mapping");
				}
				final arguments = command.strings("arguments", "WPHX2312");
				var portTokens = 0;
				for (argument in arguments) {
					if (argument.indexOf("{port}") >= 0) {
						portTokens++;
					}
				}
				if (portTokens > 1) {
					invalid("WPHX2312", "development command may contain {port} in at most one argument");
				}
				{component: component, executable: executable, arguments: arguments};
			case _:
				invalid("WPHX2312", "development service command must be an object or null");
		};
	}

	static function sortedEnvironment(values:Array<String>, serviceId:String, project:DevelopmentProject):Array<String> {
		var previous:Null<String> = null;
		for (name in values) {
			if (!ENVIRONMENT_NAME.match(name)) {
				invalid("WPHX2312", "development service environment name is invalid");
			}
			if (previous != null && compareText(previous, name) >= 0) {
				invalid("WPHX2312", "development service environment must be sorted and unique");
			}
			previous = name;
			final rule = project.environmentRule(name);
			if (rule == null || rule.services.indexOf(serviceId) < 0) {
				invalid("WPHX2312", "development service environment is not admitted by project configuration");
			}
		}
		return values;
	}

	static function validateSource(value:JsonValue, label:String):Void {
		final source = JsonReader.from(value, label, "WPHX2310");
		source.exact(["end", "path", "sourceSha256", "start", "symbol"], "WPHX2310");
		if (!RELATIVE_PATH.match(source.string("path", "WPHX2310"))) {
			invalid("WPHX2310", label + " path is not project-relative");
		}
		sha256(source.string("sourceSha256", "WPHX2310"), label + " digest");
		validatePoint(source.object("start", "WPHX2310"), label + " start");
		validatePoint(source.object("end", "WPHX2310"), label + " end");
	}

	static function validatePoint(point:JsonReader, label:String):Void {
		point.exact(["column", "line", "offset"], "WPHX2310");
		if (point.integer("offset", "WPHX2310") < 0 || point.integer("line", "WPHX2310") < 1 || point.integer("column", "WPHX2310") < 0) {
			invalid("WPHX2310", label + " is outside source coordinates");
		}
	}

	static function validateProjections(values:Array<JsonValue>):Void {
		if (values.length == 0) {
			invalid("WPHX2310", "semantic node must request at least one projection");
		}
		var previous:Null<String> = null;
		for (value in values) {
			final projection = JsonReader.from(value, "semantic projection", "WPHX2310");
			projection.exact(["artifactKind", "emitterId", "projectionId"], "WPHX2310");
			final id = stableId(projection.string("projectionId", "WPHX2310"), "semantic projection ID");
			if (previous != null && compareText(previous, id) >= 0) {
				invalid("WPHX2310", "semantic projections must be sorted and unique");
			}
			previous = id;
			stableId(projection.string("emitterId", "WPHX2310"), "semantic projection emitter");
			stableId(projection.string("artifactKind", "WPHX2310"), "semantic projection artifact kind");
		}
	}

	static function validateNodeDependencies(nodes:Array<PlanNodeRecord>):Void {
		final ids:Map<String, Bool> = [];
		for (node in nodes) {
			ids.set(node.id, true);
		}
		for (node in nodes) {
			for (dependency in node.dependencies) {
				if (!ids.exists(dependency)) {
					invalid("WPHX2310", "semantic node has an unknown dependency");
				}
			}
		}
	}

	static function validateServiceGraph(services:Array<DevelopmentService>):Void {
		final byId:Map<String, DevelopmentService> = [];
		for (service in services) {
			if (byId.exists(service.id)) {
				invalid("WPHX2312", "development service IDs must be unique");
			}
			byId.set(service.id, service);
		}
		for (service in services) {
			for (dependency in service.dependsOn) {
				if (!byId.exists(dependency)) {
					invalid("WPHX2312", "development service has an unknown dependency");
				}
			}
		}
		final state:Map<String, Int> = [];
		for (service in services) {
			visitService(service, byId, state);
		}
	}

	static function visitService(service:DevelopmentService, byId:Map<String, DevelopmentService>, state:Map<String, Int>):Void {
		final current = state.exists(service.id) ? state.get(service.id) : 0;
		if (current == 2) {
			return;
		}
		if (current == 1) {
			invalid("WPHX2312", "development service dependency graph contains a cycle");
		}
		state.set(service.id, 1);
		for (dependency in service.dependsOn) {
			final target = byId.get(dependency);
			if (target == null) {
				invalid("WPHX2312", "development service has an unknown dependency");
			}
			visitService(target, byId, state);
		}
		state.set(service.id, 2);
	}

	static function sortedStableIds(values:Array<String>, label:String):Array<String> {
		sortedStrings(values, label);
		for (value in values) {
			stableId(value, label);
		}
		return values;
	}

	static function sortedStrings(values:Array<String>, label:String):Array<String> {
		var previous:Null<String> = null;
		for (value in values) {
			if (previous != null && compareText(previous, value) >= 0) {
				invalid("WPHX2310", label + " must be sorted and unique");
			}
			previous = value;
		}
		return values;
	}

	static function stableId(value:String, label:String):String {
		if (!STABLE_ID.match(value)) {
			invalid("WPHX2310", label + " is not a stable ID");
		}
		return value;
	}

	static function schemaId(value:String, label:String):String {
		if (!SCHEMA_ID.match(value)) {
			invalid("WPHX2310", label + " is not a versioned schema ID");
		}
		return value;
	}

	static function sha256(value:String, label:String):String {
		if (!SHA256.match(value)) {
			invalid("WPHX2310", label + " is not a lowercase SHA-256");
		}
		return value;
	}

	static function urlPath(value:String, label:String):String {
		if (!URL_PATH.match(value)) {
			invalid("WPHX2312", label + " is not an absolute URL path");
		}
		return value;
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			invalid("WPHX2310", label + " contradicts the authenticated project or SDK contract");
		}
	}

	static function decodeUtf8(buffer:Buffer):String {
		final source = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(source, "utf8")) != 0) {
			invalid("WPHX2310", "generated development plan is not valid UTF-8");
		}
		return source;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid<T>(code:String, message:String):T {
		throw new CliFailure(code, message, 7, "service-start", PLAN_PATH, ["Rebuild from current Haxe sources; do not edit generated development plans."]);
	}
}
