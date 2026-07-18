package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import reflaxe.php.ir.PhpSourceFile;
import reflaxe.php.ir.PhpStableId;
import reflaxe.php.map.PhpCanonicalJson;
import reflaxe.php.print.PhpRenderedFile;

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
		final files:Array<Dynamic> = [
			{
				id: mapId,
				path: mapPath,
				role: "source-map",
				language: "json",
				sha256: digest(mapSource),
				byteLength: Bytes.ofString(mapSource).length,
				distribution: indexDistribution
			},
			{
				id: runtimeId,
				path: rendered.path,
				role: "runtime",
				language: "php",
				sha256: digest(rendered.source),
				byteLength: Bytes.ofString(rendered.source).length,
				distribution: "production"
			},
			{
				id: sourceId,
				path: sourcePath,
				role: "source",
				language: "haxe",
				sha256: source.sha256,
				byteLength: source.byteLength,
				distribution: sourceDistribution,
				sourceIdentity: {
					rootId: source.rootId,
					path: source.path
				}
			}
		];
		files.sort((left, right) -> Reflect.compare(left.id, right.id));
		final receipts = proofReceiptIds.copy();
		for (receipt in receipts) {
			PhpStableId.validate(receipt, "proof receipt ID");
		}
		receipts.sort(Reflect.compare);
		for (index in 1...receipts.length) {
			if (receipts[index - 1] == receipts[index]) {
				throw "Duplicate PHP source-index proof receipt: " + receipts[index];
			}
		}
		final sourceRoot:Dynamic = {
			id: source.rootId,
			kind: "project",
			resolution: sourceResolution,
			contentDistribution: sourceDistribution
		};
		if (sourcePackagePath != null) {
			Reflect.setField(sourceRoot, "packagePath", sourcePackagePath);
		}
		final document:Dynamic = {
			schemaVersion: 1,
			format: "wordpresshx.source-correlation-index.v1",
			sdkVersion: sdkVersion,
			buildInputsSha256: buildInputsSha256,
			retention: {
				profile: retentionProfile,
				indexDistribution: indexDistribution,
				mapsInProduction: false,
				inlineMapsInProduction: false,
				sourceContentPolicy: sourceContentPolicy,
				machinePathsAllowed: false,
				developmentHandler: "disabled",
				secretScanRequiredForShipping: true
			},
			sourceRoots: [sourceRoot],
			files: files,
			artifactSetSha256: digest(PhpCanonicalJson.encodeInline(files)),
			correlations: [
				{
					id: "correlation:" + stableEntryId,
					entryFileId: runtimeId,
					target: "php",
					strategy: "php-range-map",
					status: "bounded-local",
					layers: [
						{
							order: 0,
							mapFileId: mapId,
							format: "wordpresshx.php-haxe-range-map.v1",
							generatedFileId: runtimeId,
							generatedLanguage: "php",
							sourceLanguage: "haxe",
							sourceFileIds: [sourceId]
						}
					],
					proofReceiptIds: receipts
				}
			]
		};
		Reflect.setField(document, "package", {id: packageId, version: packageVersion, profileId: profileId});
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
}
