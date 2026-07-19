package wordpresshx.cli.project.development;

import js.node.Buffer;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.CanonicalJson.CanonicalJsonError;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonReader.JsonReadError;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.project.ProjectContext;

typedef RuntimeEnvironmentRule = {
	final name:String;
	final required:Bool;
	final services:Array<String>;
}

/** Closed project facts needed by the service runtime. */
class DevelopmentProject {
	static final STABLE_ID = ~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/;
	static final ENVIRONMENT_NAME = ~/^[A-Z][A-Z0-9_]*$/;

	public final root:String;
	public final projectId:String;
	public final profileId:String;
	public final catalogRevision:String;
	public final catalogSha256:String;
	public final toolchainSha256:String;

	final components:Map<String, Bool>;
	final environmentRules:Map<String, RuntimeEnvironmentRule>;

	public static function from(context:ProjectContext):DevelopmentProject {
		try {
			final config = parseDocument(context.bootstrap.configBytes, "wordpress-hx.json", false);
			final lock = parseDocument(context.lockBytes, context.bootstrap.lockPath, true);
			return decode(context.bootstrap.root, config, lock, OwnershipJson.digest(context.lockBytes));
		} catch (error:JsonParseError) {
			return invalid("WPHX2300", "development project JSON is malformed: " + error.message);
		} catch (error:JsonReadError) {
			return invalid(error.code, error.message);
		} catch (error:CanonicalJsonError) {
			return invalid("WPHX2300", error.message);
		}
	}

	function new(root:String, projectId:String, profileId:String, catalogRevision:String, catalogSha256:String, toolchainSha256:String,
			components:Map<String, Bool>, environmentRules:Map<String, RuntimeEnvironmentRule>) {
		this.root = root;
		this.projectId = projectId;
		this.profileId = profileId;
		this.catalogRevision = catalogRevision;
		this.catalogSha256 = catalogSha256;
		this.toolchainSha256 = toolchainSha256;
		this.components = components;
		this.environmentRules = environmentRules;
	}

	public function hasComponent(id:String):Bool {
		return components.exists(id);
	}

	public function environmentRule(name:String):Null<RuntimeEnvironmentRule> {
		return environmentRules.get(name);
	}

	static function decode(root:String, configValue:JsonValue, lockValue:JsonValue, toolchainSha256:String):DevelopmentProject {
		final config = JsonReader.from(configValue, "project configuration", "WPHX2300");
		config.exact([
			"entryPoint",
			"environment",
			"paths",
			"profile",
			"projectId",
			"schema",
			"toolchain"
		], "WPHX2300");
		expect(config.string("schema", "WPHX2300"), "wordpress-hx.project.v1", "project configuration schema");
		final projectId = stableId(config.string("projectId", "WPHX2300"), "project ID");
		final configProfile = config.object("profile", "WPHX2300");
		configProfile.exact(["id"], "WPHX2300");
		final configuredProfileId = stableId(configProfile.string("id", "WPHX2300"), "configured profile ID");
		final environmentRules = decodeEnvironment(config.object("environment", "WPHX2300"));

		final lock = JsonReader.from(lockValue, "project lock", "WPHX2300");
		lock.exact([
			"canonicalization",
			"components",
			"generatedBy",
			"lockDigest",
			"lockDigestAlgorithm",
			"packageGraph",
			"profile",
			"project",
			"schema"
		], "WPHX2300");
		expect(lock.string("schema", "WPHX2300"), "wordpress-hx.project-lock.v1", "project lock schema");
		final lockedProject = lock.object("project", "WPHX2300");
		lockedProject.exact(["configPath", "configSemanticSha256", "id"], "WPHX2300");
		expect(lockedProject.string("id", "WPHX2300"), projectId, "locked project ID");
		final profile = lock.object("profile", "WPHX2300");
		profile.exact(["catalogRevision", "catalogSha256", "id"], "WPHX2300");
		final profileId = stableId(profile.string("id", "WPHX2300"), "locked profile ID");
		expect(profileId, configuredProfileId, "locked profile ID");
		final catalogRevision = profile.string("catalogRevision", "WPHX2300");
		final catalogSha256 = sha256(profile.string("catalogSha256", "WPHX2300"), "profile catalog digest");
		final components:Map<String, Bool> = [];
		var previousComponent:Null<String> = null;
		for (value in lock.array("components", "WPHX2300")) {
			final component = JsonReader.from(value, "project lock component", "WPHX2300");
			component.exact(["id", "identity", "lockEntrySha256", "role", "source", "version"], "WPHX2300");
			final id = stableId(component.string("id", "WPHX2300"), "component ID");
			if (previousComponent != null && compareText(previousComponent, id) >= 0) {
				invalid("WPHX2300", "project lock components must be sorted and unique");
			}
			previousComponent = id;
			components.set(id, true);
		}
		return new DevelopmentProject(root, projectId, profileId, catalogRevision, catalogSha256, toolchainSha256, components, environmentRules);
	}

	static function decodeEnvironment(environment:JsonReader):Map<String, RuntimeEnvironmentRule> {
		environment.exact(["build", "runtime"], "WPHX2300");
		final result:Map<String, RuntimeEnvironmentRule> = [];
		var previous:Null<String> = null;
		for (value in environment.array("runtime", "WPHX2300")) {
			final rule = JsonReader.from(value, "runtime environment declaration", "WPHX2300");
			rule.exact(["classification", "name", "required", "services"], "WPHX2300");
			final name = rule.string("name", "WPHX2300");
			if (!ENVIRONMENT_NAME.match(name)) {
				invalid("WPHX2300", "runtime environment name is invalid");
			}
			if (previous != null && compareText(previous, name) >= 0) {
				invalid("WPHX2300", "runtime environment declarations must be sorted and unique");
			}
			previous = name;
			final classification = rule.string("classification", "WPHX2300");
			if (classification != "public-runtime" && classification != "secret-runtime") {
				invalid("WPHX2300", "runtime environment classification is outside the closed enum");
			}
			final services = sortedStableIds(rule.strings("services", "WPHX2300"), "runtime environment services");
			if (services.length == 0) {
				invalid("WPHX2300", "runtime environment services may not be empty");
			}
			result.set(name, {name: name, required: rule.boolean("required", "WPHX2300"), services: services});
		}
		return result;
	}

	static function parseDocument(buffer:Buffer, label:String, canonical:Bool):JsonValue {
		final source = buffer.toString("utf8");
		if (Buffer.compareBuffers(buffer, Buffer.from(source, "utf8")) != 0) {
			invalid("WPHX2300", label + " is not valid UTF-8");
		}
		final value = JsonParser.parse(source);
		if (canonical && source != CanonicalJson.encode(value) + "\n") {
			invalid("WPHX2300", label + " is not canonical JSON");
		}
		return value;
	}

	static function sortedStableIds(values:Array<String>, label:String):Array<String> {
		var previous:Null<String> = null;
		for (value in values) {
			stableId(value, label);
			if (previous != null && compareText(previous, value) >= 0) {
				invalid("WPHX2300", label + " must be sorted and unique");
			}
			previous = value;
		}
		return values;
	}

	static function stableId(value:String, label:String):String {
		if (!STABLE_ID.match(value)) {
			invalid("WPHX2300", label + " is not a stable ID");
		}
		return value;
	}

	static function sha256(value:String, label:String):String {
		if (!~/^[0-9a-f]{64}$/.match(value)) {
			invalid("WPHX2300", label + " is not a lowercase SHA-256");
		}
		return value;
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			invalid("WPHX2300", label + " contradicts the authenticated project");
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid<T>(code:String, message:String):T {
		throw new CliFailure(code, message, 7, "service-start", ".wphx/runtime/semantic-plan.next.json",
			["Rebuild from current Haxe sources; do not edit generated development plans."]);
	}
}
