package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import reflaxe.php.ir.PhpSourceFile;
import reflaxe.php.ir.PhpStableId;
import reflaxe.php.map.PhpCanonicalJson;
import reflaxe.php.map.PhpCanonicalJson.PhpJsonField;
import reflaxe.php.map.PhpCanonicalJson.PhpJsonValue;
import reflaxe.php.print.PhpRenderedFile;

private typedef SourceIndexFile = {
	final id:String;
	final value:PhpJsonValue;
}

/** Deterministic one-entry PHP package index for an exact native artifact and external map. **/
class WordPressPhpSourceIndexWriter {
	final sdkVersion:String;
	final packageId:String;
	final packageVersion:String;
	final profileId:String;
	final buildInputsSha256:String;
	final retentionProfile:String;
	final indexDistribution:String;
	final sourceResolution:String;
	final sourceDistribution:String;
	final sourcePackagePath:Null<String>;

	public function new(sdkVersion:String, packageId:String, packageVersion:String, profileId:String, buildInputsSha256:String, retentionProfile:String,
			indexDistribution:String, sourceResolution:String, sourceDistribution:String, ?sourcePackagePath:String) {
		this.sdkVersion = nonEmpty(sdkVersion, "SDK version");
		this.packageId = PhpStableId.validate(packageId, "source-index package ID");
		this.packageVersion = nonEmpty(packageVersion, "package version");
		this.profileId = PhpStableId.validate(profileId, "source-index profile ID");
		this.buildInputsSha256 = sha256(buildInputsSha256, "source-index build inputs");
		this.retentionProfile = closed(retentionProfile, ["development", "debug-companion", "production-evidence"], "retention profile");
		this.indexDistribution = closed(indexDistribution, ["debug-companion", "local-only"], "index distribution");
		this.sourceResolution = closed(sourceResolution, ["cli-root-argument", "debug-companion-relative"], "source resolution");
		this.sourceDistribution = closed(sourceDistribution, ["debug-companion", "local-only", "external"], "source distribution");
		if (sourceResolution == "debug-companion-relative" && sourcePackagePath == null) {
			throw "A debug-companion-relative source root requires a package path";
		}
		if (sourceResolution != "debug-companion-relative" && sourcePackagePath != null) {
			throw "Only a debug-companion-relative source root may have a package path";
		}
		this.sourcePackagePath = sourcePackagePath;
	}

	public function write(entryId:String, rendered:PhpRenderedFile, mapSource:String, source:PhpSourceFile, proofReceiptIds:Array<String>):String {
		final stableEntryId = PhpStableId.validate(entryId, "source-index entry ID");
		if (rendered == null || mapSource == null || source == null || proofReceiptIds == null) {
			throw "PHP source-index writer requires exact entry, map, source, and receipts";
		}
		final runtimeId = "file:runtime:" + stableEntryId;
		final mapId = "file:map:" + stableEntryId;
		final sourceId = "file:source:" + source.id;
		final mapPath = rendered.path + ".haxe-map.json";
		final sourcePath = sourcePackagePath == null ? "external/project/" + source.path : sourcePackagePath + "/" + source.path;
		final sourceContentPolicy = sourceDistribution == "debug-companion" ? "allowlisted-debug-only" : "omitted";
		final files:Array<SourceIndexFile> = [
			{
				id: mapId,
				value: object([
					field("id", text(mapId)),
					field("path", text(mapPath)),
					field("role", text("source-map")),
					field("language", text("json")),
					field("sha256", text(digest(mapSource))),
					field("byteLength", integer(Bytes.ofString(mapSource).length)),
					field("distribution", text(indexDistribution))
				])
			},
			{
				id: runtimeId,
				value: object([
					field("id", text(runtimeId)),
					field("path", text(rendered.path)),
					field("role", text("runtime")),
					field("language", text("php")),
					field("sha256", text(digest(rendered.source))),
					field("byteLength", integer(Bytes.ofString(rendered.source).length)),
					field("distribution", text("production"))
				])
			},
			{
				id: sourceId,
				value: object([
					field("id", text(sourceId)),
					field("path", text(sourcePath)),
					field("role", text("source")),
					field("language", text("haxe")),
					field("sha256", text(source.sha256)),
					field("byteLength", integer(source.byteLength)),
					field("distribution", text(sourceDistribution)),
					field("sourceIdentity", object([field("rootId", text(source.rootId)), field("path", text(source.path))]))
				])
			}
		];
		files.sort((left, right) -> compareText(left.id, right.id));
		final fileValues = [for (file in files) file.value];
		final receipts = proofReceiptIds.copy();
		for (receipt in receipts) {
			PhpStableId.validate(receipt, "proof receipt ID");
		}
		receipts.sort(compareText);
		for (index in 1...receipts.length) {
			if (receipts[index - 1] == receipts[index]) {
				throw "Duplicate PHP source-index proof receipt: " + receipts[index];
			}
		}
		final sourceRootFields:Array<PhpJsonField> = [
			field("id", text(source.rootId)),
			field("kind", text("project")),
			field("resolution", text(sourceResolution)),
			field("contentDistribution", text(sourceDistribution))
		];
		if (sourcePackagePath != null) {
			sourceRootFields.push(field("packagePath", text(sourcePackagePath)));
		}
		final document = object([
			field("schemaVersion", integer(1)),
			field("format", text("wordpresshx.source-correlation-index.v1")),
			field("sdkVersion", text(sdkVersion)),
			field("buildInputsSha256", text(buildInputsSha256)),
			field("retention",
				object([
					field("profile", text(retentionProfile)),
					field("indexDistribution", text(indexDistribution)),
					field("mapsInProduction", boolean(false)),
					field("inlineMapsInProduction", boolean(false)),
					field("sourceContentPolicy", text(sourceContentPolicy)),
					field("machinePathsAllowed", boolean(false)),
					field("developmentHandler", text("disabled")),
					field("secretScanRequiredForShipping", boolean(true))
				])),
			field("sourceRoots", array([object(sourceRootFields)])),
			field("files", array(fileValues)),
			field("artifactSetSha256", text(digest(PhpCanonicalJson.encodeInline(array(fileValues))))),
			field("correlations", array([
				object([
					field("id", text("correlation:" + stableEntryId)),
					field("entryFileId", text(runtimeId)),
					field("target", text("php")),
					field("strategy", text("php-range-map")),
					field("status", text("bounded-local")),
					field("layers", array([
						object([
							field("order", integer(0)),
							field("mapFileId", text(mapId)),
							field("format", text("wordpresshx.php-haxe-range-map.v1")),
							field("generatedFileId", text(runtimeId)),
							field("generatedLanguage", text("php")),
							field("sourceLanguage", text("haxe")),
							field("sourceFileIds", array([text(sourceId)]))
						])
					])),
					field("proofReceiptIds", array(receipts.map(text)))
				])
			])),
			field("package", object([
				field("id", text(packageId)),
				field("version", text(packageVersion)),
				field("profileId", text(profileId))
			]))
		]);
		return PhpCanonicalJson.encode(document);
	}

	static function digest(value:String):String {
		return Sha256.make(Bytes.ofString(value)).toHex().toLowerCase();
	}

	static function sha256(value:String, label:String):String {
		if (value == null || !~/^[0-9a-f]{64}$/.match(value)) {
			throw "Invalid " + label + " SHA-256";
		}
		return value;
	}

	static function nonEmpty(value:String, label:String):String {
		if (value == null || value.length == 0 || value.length > 512 || value.indexOf("\x00") != -1) {
			throw "Invalid PHP source-index " + label;
		}
		return value;
	}

	static function closed(value:String, allowed:Array<String>, label:String):String {
		if (allowed.indexOf(value) < 0) {
			throw "Unsupported PHP source-index " + label + ": " + value;
		}
		return value;
	}

	static inline function field(name:String, value:PhpJsonValue):PhpJsonField {
		return {name: name, value: value};
	}

	static inline function object(fields:Array<PhpJsonField>):PhpJsonValue {
		return ObjectValue(fields);
	}

	static inline function array(values:Array<PhpJsonValue>):PhpJsonValue {
		return ArrayValue(values);
	}

	static inline function text(value:String):PhpJsonValue {
		return StringValue(value);
	}

	static inline function integer(value:Int):PhpJsonValue {
		return IntegerValue(value);
	}

	static inline function boolean(value:Bool):PhpJsonValue {
		return BoolValue(value);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
