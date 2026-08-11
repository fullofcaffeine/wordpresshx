package reflaxe.php.compiler;

import reflaxe.php.ir.PhpStableId;
import reflaxe.php.map.PhpCanonicalJson;
import reflaxe.php.map.PhpCanonicalJson.PhpJsonField;
import reflaxe.php.map.PhpCanonicalJson.PhpJsonValue;

enum abstract PhpCompilationArtifactKind(String) to String {
	var ModuleArtifact = "module";
	var RuntimeArtifact = "runtime";
	var BootstrapArtifact = "bootstrap";

	public inline function value():String {
		return this;
	}
}

/** Immutable manifest input for one mapped generated PHP artifact. **/
class PhpCompilationArtifactRecord {
	public final kind:PhpCompilationArtifactKind;
	public final identity:String;
	public final path:String;
	public final sha256:String;
	public final mapPath:String;
	public final mapSha256:String;

	final dependencyValues:Array<String>;

	public var dependencies(get, never):Array<String>;

	public function new(kind:PhpCompilationArtifactKind, identity:String, path:String, sha256:String, mapPath:String, mapSha256:String,
			dependencies:Array<String>) {
		this.kind = kind;
		this.identity = PhpStableId.validate(identity, "artifact identity");
		this.path = path;
		this.sha256 = validateSha256(sha256, "artifact");
		this.mapPath = mapPath;
		this.mapSha256 = validateSha256(mapSha256, "artifact map");
		final values = dependencies.copy();
		values.sort(compareText);
		this.dependencyValues = values;
	}

	function get_dependencies():Array<String> {
		return dependencyValues.copy();
	}

	static function validateSha256(value:String, label:String):String {
		if (value == null || !~/^[0-9a-f]{64}$/.match(value)) {
			throw "Invalid reflaxe.php " + label + " SHA-256";
		}
		return value;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

/** Canonical, content-addressed description of a per-module PHP compilation. **/
class PhpArtifactManifestWriter {
	public static function write(profile:PhpTargetProfile, generatorSourceSha256:String, buildInputsSha256:String, entrypointIdentity:String,
			entrypointPath:String, loadOrder:Array<String>, artifacts:Array<PhpCompilationArtifactRecord>):String {
		final orderedArtifacts = artifacts.copy();
		orderedArtifacts.sort((left, right) -> compareText(left.path, right.path));
		return PhpCanonicalJson.encode(object([
			field("schemaVersion", IntegerValue(1)),
			field("format", StringValue("reflaxe.php-artifact-graph.v1")),
			field("profile", object([
				field("id", StringValue(profile.value())),
				field("minimumPhpVersionId", IntegerValue(profile.minimumPhpVersionId())),
				field("minimumIntBits", IntegerValue(profile.minimumIntBits())),
				field("strictTypes", BoolValue(profile.usesStrictTypes())),
				field("nativeIntTypes", BoolValue(profile.usesNativeIntTypes()))
			])),
			field("generator", object([
				field("id", StringValue("reflaxe.php.compiler")),
				field("version", StringValue("0.0.0")),
				field("sourceSha256", StringValue(generatorSourceSha256))
			])),
			field("buildInputsSha256", StringValue(buildInputsSha256)),
			field("entrypoint", object([
				field("identity", StringValue(entrypointIdentity)),
				field("path", StringValue(entrypointPath)),
				field("method", StringValue("main"))
			])),
			field("loadOrder", ArrayValue(loadOrder.map(StringValue))),
			field("artifacts", ArrayValue(orderedArtifacts.map(artifactValue)))
		]));
	}

	static function artifactValue(artifact:PhpCompilationArtifactRecord):PhpJsonValue {
		return object([
			field("kind", StringValue(artifact.kind.value())),
			field("identity", StringValue(artifact.identity)),
			field("path", StringValue(artifact.path)),
			field("sha256", StringValue(artifact.sha256)),
			field("mapPath", StringValue(artifact.mapPath)),
			field("mapSha256", StringValue(artifact.mapSha256)),
			field("dependencies", ArrayValue(artifact.dependencies.map(StringValue)))
		]);
	}

	static function object(fields:Array<PhpJsonField>):PhpJsonValue {
		return ObjectValue(fields);
	}

	static function field(name:String, value:PhpJsonValue):PhpJsonField {
		return {name: name, value: value};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
