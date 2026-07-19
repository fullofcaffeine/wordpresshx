package wordpress.hx.build._internal;

#if macro
import wordpress.hx.build._internal.JsonValue.JsonField;
import wordpress.hx.build._internal.SemanticModel.CollectorInputMaterial;
import wordpress.hx.build._internal.SemanticModel.CollectorInputs;
import wordpress.hx.build._internal.SemanticModel.DevelopmentCommand;
import wordpress.hx.build._internal.SemanticModel.DevelopmentReadinessKind;
import wordpress.hx.build._internal.SemanticModel.DevelopmentReloadKind;
import wordpress.hx.build._internal.SemanticModel.DevelopmentServiceData;
import wordpress.hx.build._internal.SemanticModel.DevelopmentServiceKind;
import wordpress.hx.build._internal.SemanticModel.EnvironmentRecord;
import wordpress.hx.build._internal.SemanticModel.FileDigestRecord;
import wordpress.hx.build._internal.SemanticModel.GeneratorRecord;
import wordpress.hx.build._internal.SemanticModel.HookNodePayload;
import wordpress.hx.build._internal.SemanticModel.InputFileRecord;
import wordpress.hx.build._internal.SemanticModel.InputProfileRecord;
import wordpress.hx.build._internal.SemanticModel.InputProjectRecord;
import wordpress.hx.build._internal.SemanticModel.ModuleNodePayload;
import wordpress.hx.build._internal.SemanticModel.NodeSchemaRecord;
import wordpress.hx.build._internal.SemanticModel.PlanProfileRecord;
import wordpress.hx.build._internal.SemanticModel.PlanProjectRecord;
import wordpress.hx.build._internal.SemanticModel.Projection;
import wordpress.hx.build._internal.SemanticModel.ResourceRecord;
import wordpress.hx.build._internal.SemanticModel.SemanticNode;
import wordpress.hx.build._internal.SemanticModel.SemanticPayload;
import wordpress.hx.build._internal.SemanticModel.SemanticPlanRecord;
import wordpress.hx.build._internal.SemanticModel.SourcePoint;
import wordpress.hx.build._internal.SemanticModel.SourceSpan;
import wordpress.hx.build._internal.SemanticModel.ToolRecord;

/** Explicit projection from typed semantic records into canonical JSON. */
class SemanticJson {
	public static function fileDigests(values:Array<FileDigestRecord>):JsonValue {
		return array([
			for (value in values)
				object([field("path", string(value.path)), field("sha256", string(value.sha256))])
		]);
	}

	public static function inputMaterial(value:CollectorInputMaterial):JsonValue {
		return object([
			field("schema", string(value.schema)),
			field("canonicalization", string(value.canonicalization)),
			field("fingerprintAlgorithm", string(value.fingerprintAlgorithm)),
			field("project", inputProject(value.project)),
			field("profile", inputProfile(value.profile)),
			field("files", array([for (entry in value.files) inputFile(entry)])),
			field("resources", array([for (entry in value.resources) resource(entry)])),
			field("environment", array([for (entry in value.environment) environment(entry)])),
			field("tools", array([for (entry in value.tools) tool(entry)]))
		]);
	}

	public static function inputs(value:CollectorInputs):JsonValue {
		final material = value.material;
		return object([
			field("schema", string(material.schema)),
			field("canonicalization", string(material.canonicalization)),
			field("fingerprintAlgorithm", string(material.fingerprintAlgorithm)),
			field("fingerprint", string(value.fingerprint)),
			field("planDigest", string(value.planDigest)),
			field("project", inputProject(material.project)),
			field("profile", inputProfile(material.profile)),
			field("files", array([for (entry in material.files) inputFile(entry)])),
			field("resources", array([for (entry in material.resources) resource(entry)])),
			field("environment", array([for (entry in material.environment) environment(entry)])),
			field("tools", array([for (entry in material.tools) tool(entry)]))
		]);
	}

	public static function plan(value:SemanticPlanRecord):JsonValue {
		final fields = [
			field("schema", string(value.schema)),
			field("canonicalization", string(value.canonicalization)),
			field("planDigestAlgorithm", string(value.planDigestAlgorithm)),
			field("generator", generator(value.generator)),
			field("profile", planProfile(value.profile)),
			field("project", planProject(value.project)),
			field("nodeSchemas", array([for (entry in value.nodeSchemas) nodeSchema(entry)])),
			field("nodes", array([for (entry in value.nodes) node(entry)]))
		];
		if (value.planDigest != null) {
			fields.push(field("planDigest", string(value.planDigest)));
		}
		return object(fields);
	}

	public static function developmentService(value:DevelopmentServiceData):JsonValue {
		return object([
			field("serviceId", string(value.serviceId)),
			field("serviceKind", string(serviceKind(value.serviceKind))),
			field("dependsOn", strings(value.dependsOn)),
			field("workingDirectory", string(value.workingDirectory)),
			field("command", command(value.command)),
			field("environment", strings(value.environment)),
			field("port", object([
				field("preferred", integer(value.port.preferred)),
				field("strict", boolean(value.port.strict))
			])),
			field("readiness", object([
				field("kind", string(readinessKind(value.readiness.kind))),
				field("path", string(value.readiness.path)),
				field("text", string(value.readiness.text)),
				field("timeoutMs", integer(value.readiness.timeoutMs)),
				field("intervalMs", integer(value.readiness.intervalMs))
			])),
			field("restart",
				object([
					field("maxAttempts", integer(value.restart.maxAttempts)),
					field("backoffMs", integer(value.restart.backoffMs))
				])),
			field("url", object([field("scheme", string(value.url.scheme)), field("path", string(value.url.path))])),
			field("reload", string(reloadKind(value.reload)))
		]);
	}

	static function node(value:SemanticNode):JsonValue {
		return object([
			field("id", string(value.id)),
			field("kind", string(value.kind)),
			field("schemaId", string(value.schemaId)),
			field("source", sourceSpan(value.source)),
			field("relatedSources", array([for (entry in value.relatedSources) sourceSpan(entry)])),
			field("dependsOn", strings(value.dependsOn)),
			field("profileCapabilities", strings(value.profileCapabilities)),
			field("projections", array([for (entry in value.projections) projection(entry)])),
			field("payload", payload(value.payload))
		]);
	}

	static function payload(value:SemanticPayload):JsonValue {
		return switch value {
			case ModulePayload(payload): object([
					field("moduleId", string(payload.moduleId)),
					field("moduleType", string(payload.moduleType)),
					field("displayName", string(payload.displayName)),
					field("version", string(payload.version)),
					field("namespace", string(payload.namespace))
				]);
			case HookPayload(payload): object([
					field("hookName", string(payload.hookName)),
					field("hookType", string(payload.hookType)),
					field("callbackSymbol", string(payload.callbackSymbol)),
					field("priority", integer(payload.priority)),
					field("acceptedArgs", integer(payload.acceptedArgs))
				]);
			case DevelopmentPayload(payload): developmentService(payload);
		};
	}

	static function sourceSpan(value:SourceSpan):JsonValue {
		return object([
			field("path", string(value.path)),
			field("sourceSha256", string(value.sourceSha256)),
			field("start", point(value.start)),
			field("end", point(value.end)),
			field("symbol", string(value.symbol))
		]);
	}

	static function point(value:SourcePoint):JsonValue {
		return object([
			field("offset", integer(value.offset)),
			field("line", integer(value.line)),
			field("column", integer(value.column))
		]);
	}

	static function projection(value:Projection):JsonValue {
		return object([
			field("projectionId", string(value.projectionId)),
			field("emitterId", string(value.emitterId)),
			field("artifactKind", string(value.artifactKind))
		]);
	}

	static function nodeSchema(value:NodeSchemaRecord):JsonValue {
		final fields = [
			field("schemaId", string(value.schemaId)),
			field("kind", string(value.kind)),
			field("version", integer(value.version)),
			field("authority", string(value.authority)),
			field("schemaSha256", string(value.schemaSha256)),
			field("consumerEmitters", strings(value.consumerEmitters))
		];
		if (value.extensionId != null) {
			fields.push(field("extensionId", string(value.extensionId)));
		}
		return object(fields);
	}

	static function generator(value:GeneratorRecord):JsonValue {
		return object([
			field("sdkVersion", string(value.sdkVersion)),
			field("collectorId", string(value.collectorId)),
			field("collectorVersion", string(value.collectorVersion)),
			field("collectorSourceSha256", string(value.collectorSourceSha256)),
			field("toolchainSha256", string(value.toolchainSha256))
		]);
	}

	static function planProfile(value:PlanProfileRecord):JsonValue {
		return object([
			field("profileId", string(value.profileId)),
			field("catalogRevision", string(value.catalogRevision)),
			field("catalogSha256", string(value.catalogSha256))
		]);
	}

	static function planProject(value:PlanProjectRecord):JsonValue {
		return object([
			field("projectId", string(value.projectId)),
			field("projectVersion", string(value.projectVersion)),
			field("sourceTreeSha256", string(value.sourceTreeSha256))
		]);
	}

	static function inputProject(value:InputProjectRecord):JsonValue {
		return object([
			field("id", string(value.id)),
			field("version", string(value.version)),
			field("configPath", string(value.configPath))
		]);
	}

	static function inputProfile(value:InputProfileRecord):JsonValue {
		return object([
			field("id", string(value.id)),
			field("catalogRevision", string(value.catalogRevision)),
			field("catalogSha256", string(value.catalogSha256))
		]);
	}

	static function inputFile(value:InputFileRecord):JsonValue {
		return object([
			field("path", string(value.path)),
			field("sha256", string(value.sha256)),
			field("byteLength", integer(value.byteLength)),
			field("role", string(value.role))
		]);
	}

	static function resource(value:ResourceRecord):JsonValue {
		return object([field("id", string(value.id)), field("path", string(value.path))]);
	}

	static function environment(value:EnvironmentRecord):JsonValue {
		return object([
			field("name", string(value.name)),
			field("classification", string(value.classification)),
			field("required", boolean(value.required)),
			field("source", string(value.source)),
			field("valueSha256", string(value.valueSha256))
		]);
	}

	static function tool(value:ToolRecord):JsonValue {
		return object([
			field("id", string(value.id)),
			field("version", string(value.version)),
			field("identity", string(value.identity)),
			field("lockEntrySha256", string(value.lockEntrySha256))
		]);
	}

	static function command(value:Null<DevelopmentCommand>):JsonValue {
		if (value == null) {
			return NullValue;
		}
		return object([
			field("component", string(value.component)),
			field("executable", string(value.executable)),
			field("arguments", strings(value.arguments))
		]);
	}

	static function serviceKind(value:DevelopmentServiceKind):String {
		return switch value {
			case WordPressService: "wordpress";
			case ExternalService: "external";
		};
	}

	static function readinessKind(value:DevelopmentReadinessKind):String {
		return switch value {
			case HttpReadiness: "http";
			case LogReadiness: "log";
			case ProcessReadiness: "process";
			case TcpReadiness: "tcp";
		};
	}

	static function reloadKind(value:DevelopmentReloadKind):String {
		return switch value {
			case FullPageReload: "full-page";
			case NoReload: "none";
		};
	}

	static function strings(values:Array<String>):JsonValue {
		return array([for (value in values) string(value)]);
	}

	static function object(fields:Array<JsonField>):JsonValue {
		return ObjectValue(fields);
	}

	static function array(values:Array<JsonValue>):JsonValue {
		return ArrayValue(values);
	}

	static function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	static function string(value:String):JsonValue {
		return StringValue(value);
	}

	static function integer(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}

	static function boolean(value:Bool):JsonValue {
		return BoolValue(value);
	}
}
#end
