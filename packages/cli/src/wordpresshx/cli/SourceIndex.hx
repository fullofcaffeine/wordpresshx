package wordpresshx.cli;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.closedjson.JsonDocument;
import wordpresshx.cli.closedjson.JsonDocument.JsonDocumentError;
import wordpresshx.cli.closedjson.JsonValue;

typedef SourcePackageIdentity = {
	final id:String;
	final version:String;
	final profileId:String;
}

typedef SourceRetention = {
	final profile:String;
	final indexDistribution:String;
	final mapsInProduction:Bool;
	final inlineMapsInProduction:Bool;
	final sourceContentPolicy:String;
	final machinePathsAllowed:Bool;
	final developmentHandler:String;
	final secretScanRequiredForShipping:Bool;
}

typedef SourceRootRecord = {
	final id:String;
	final kind:String;
	final resolution:String;
	final contentDistribution:String;
	final packagePath:Null<String>;
}

typedef SourceIdentity = {
	final rootId:String;
	final path:String;
}

typedef SourceFileRecord = {
	final id:String;
	final path:String;
	final role:String;
	final language:String;
	final sha256:String;
	final byteLength:Int;
	final distribution:String;
	final sourceIdentity:Null<SourceIdentity>;
}

typedef SourceBinding = {
	final record:SourceFileRecord;
	final root:SourceRootRecord;
	final content:Null<String>;
}

typedef SourceCorrelationLayer = {
	final order:Int;
	final mapFileId:String;
	final format:String;
	final generatedFileId:String;
	final generatedLanguage:String;
	final sourceLanguage:String;
	final sourceFileIds:Array<String>;
}

typedef AvailableSourceCorrelation = {
	final id:String;
	final entryFileId:String;
	final target:String;
	final strategy:String;
	final status:String;
	final layers:Array<SourceCorrelationLayer>;
	final proofReceiptIds:Array<String>;
}

typedef UnavailableSourceCorrelation = {
	final id:String;
	final entryFileId:String;
	final target:String;
	final strategy:String;
	final status:String;
	final reason:String;
	final proofReceiptIds:Array<String>;
}

enum SourceCorrelation {
	AvailableCorrelation(value:AvailableSourceCorrelation);
	UnavailableCorrelation(value:UnavailableSourceCorrelation);
}

private typedef SourceIndexHeader = {
	final packageIdentity:SourcePackageIdentity;
	final retention:SourceRetention;
}

/**
	Authenticated, closed-contract view of one package source-correlation index.

	Target-specific trace engines share this loader so PHP ranges and browser
	Source Map v3 layers enforce the same file identities, roots, retention, and
	layer-continuity rules.
**/
class SourceIndex {
	public final indexPath:String;
	public final indexRoot:String;
	public final filesById:Map<String, SourceFileRecord> = [];
	public final filesByPath:Map<String, SourceFileRecord> = [];
	public final rootsById:Map<String, SourceRootRecord> = [];
	public final sourceBindingsByFileId:Map<String, SourceBinding> = [];
	public final correlations:Array<SourceCorrelation> = [];
	public final packageIdentity:SourcePackageIdentity;
	public final retention:SourceRetention;

	final sourceRootArguments:Map<String, String>;

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		this.indexPath = existingFile(indexPath, "source index");
		this.indexRoot = Path.dirname(this.indexPath);
		this.sourceRootArguments = sourceRootArguments;
		final header = load();
		packageIdentity = header.packageIdentity;
		retention = header.retention;
	}

	public function file(fileId:String):SourceFileRecord {
		Content.stableId(fileId, "source-index file ID");
		Contract.require(filesById.exists(fileId), "unknown source-index file ID: " + fileId);
		return filesById.get(fileId);
	}

	public function sourceBinding(fileId:String):SourceBinding {
		Contract.require(sourceBindingsByFileId.exists(fileId), "source-index file is not a bound source: " + fileId);
		return sourceBindingsByFileId.get(fileId);
	}

	public function artifactPath(fileId:String, label:String):String {
		final record = file(fileId);
		Contract.require(record.sourceIdentity == null, label + " unexpectedly names an external source");
		Contract.require(record.distribution != "external", label + " is not present beside the source index");
		return safeResolve(indexRoot, record.path, label);
	}

	public function artifactContent(fileId:String, label:String):String {
		final record = file(fileId);
		final content = readUtf8(existingFile(artifactPath(fileId, label), label), label);
		validateBoundFile(record, content, label);
		return content;
	}

	function load():SourceIndexHeader {
		final indexSource = readUtf8(indexPath, "source index");
		final index = parseJson(indexSource, "source index");
		Contract.fields(index, [
			"schemaVersion",
			"format",
			"sdkVersion",
			"buildInputsSha256",
			"package",
			"retention",
			"sourceRoots",
			"files",
			"artifactSetSha256",
			"correlations"
		], "source index");
		Contract.require(Contract.integer(index, "schemaVersion", "source index") == 1, "unsupported source-index schema version");
		Contract.require(Contract.string(index, "format", "source index") == "wordpresshx.source-correlation-index.v1", "unsupported source-index format");
		Contract.string(index, "sdkVersion", "source index");
		Content.sha256(Contract.string(index, "buildInputsSha256", "source index"), "source-index build inputs");
		final packageIdentity = validatePackage(Contract.fieldValue(index, "package", "source index"));
		final retention = validateRetention(Contract.fieldValue(index, "retention", "source index"));
		validateRoots(Contract.array(index, "sourceRoots", "source index"));
		final files = Contract.array(index, "files", "source index");
		validateFiles(files);
		Contract.require(Content.digest(CanonicalJson.encode(ArrayValue(files))) == Content.sha256(Contract.string(index, "artifactSetSha256",
			"source index"), "source-index artifact set"),
			"source-index artifact-set digest mismatch");
		validateCorrelations(Contract.array(index, "correlations", "source index"));
		return {packageIdentity: packageIdentity, retention: retention};
	}

	function validatePackage(value:JsonValue):SourcePackageIdentity {
		Contract.fields(value, ["id", "version", "profileId"], "source index package");
		return {
			id: Content.stableId(Contract.string(value, "id", "source index package"), "package ID"),
			version: Contract.string(value, "version", "source index package"),
			profileId: Content.stableId(Contract.string(value, "profileId", "source index package"), "profile ID")
		};
	}

	function validateRetention(value:JsonValue):SourceRetention {
		Contract.fields(value, [
			"profile",
			"indexDistribution",
			"mapsInProduction",
			"inlineMapsInProduction",
			"sourceContentPolicy",
			"machinePathsAllowed",
			"developmentHandler",
			"secretScanRequiredForShipping"
		], "source index retention");
		final result:SourceRetention = {
			profile: closed(Contract.string(value, "profile", "source index retention"), ["development", "debug-companion", "production-evidence"],
				"retention profile"),
			indexDistribution: closed(Contract.string(value, "indexDistribution", "source index retention"), ["debug-companion", "local-only"],
				"index distribution"),
			mapsInProduction: Contract.boolean(value, "mapsInProduction", "source index retention"),
			inlineMapsInProduction: Contract.boolean(value, "inlineMapsInProduction", "source index retention"),
			sourceContentPolicy: closed(Contract.string(value, "sourceContentPolicy", "source index retention"), ["omitted", "allowlisted-debug-only"],
				"source content policy"),
			machinePathsAllowed: Contract.boolean(value, "machinePathsAllowed", "source index retention"),
			developmentHandler: closed(Contract.string(value, "developmentHandler", "source index retention"), ["disabled", "opt-in-augment-only"],
				"development handler"),
			secretScanRequiredForShipping: Contract.boolean(value, "secretScanRequiredForShipping", "source index retention")
		};
		Contract.require(!result.mapsInProduction, "source maps cannot be retained in production");
		Contract.require(!result.inlineMapsInProduction, "inline maps cannot be retained in production");
		Contract.require(!result.machinePathsAllowed, "machine paths cannot be admitted by the index");
		Contract.require(result.secretScanRequiredForShipping, "shipping source-correlation data requires secret scanning");
		return result;
	}

	function validateRoots(values:Array<JsonValue>):Void {
		Contract.require(values.length > 0, "source index must declare at least one source root");
		var previous = "";
		for (value in values) {
			final hasPackagePath = Contract.has(value, "packagePath", "source root");
			Contract.fields(value,
				hasPackagePath ? ["id", "kind", "resolution", "contentDistribution", "packagePath"] : ["id", "kind", "resolution", "contentDistribution"],
				"source root");
			final id = Content.stableId(Contract.string(value, "id", "source root"), "source root ID");
			Contract.require(previous == "" || Content.compareText(previous, id) < 0, "source root IDs must be sorted and unique");
			previous = id;
			final resolution = closed(Contract.string(value, "resolution", "source root"),
				["cli-root-argument", "debug-companion-relative", "not-resolvable"], "source root resolution");
			final packagePath = hasPackagePath ? Content.safeRelativePath(Contract.string(value, "packagePath", "source root"),
				"source root packagePath") : null;
			Contract.require((resolution == "debug-companion-relative") == hasPackagePath,
				"only a debug-companion-relative source root must declare packagePath");
			final root:SourceRootRecord = {
				id: id,
				kind: closed(Contract.string(value, "kind", "source root"), ["project", "dependency", "haxe-stdlib", "native"], "source root kind"),
				resolution: resolution,
				contentDistribution: closed(Contract.string(value, "contentDistribution", "source root"), ["external", "debug-companion", "local-only"],
					"source root content distribution"),
				packagePath: packagePath
			};
			Contract.require(!rootsById.exists(id), "duplicate source root ID", true);
			rootsById.set(id, root);
		}
		for (id in sourceRootArguments.keys()) {
			if (!rootsById.exists(id)) {
				throw new TraceFailure("unknown --source-root ID: " + id, 2);
			}
		}
	}

	function validateFiles(values:Array<JsonValue>):Void {
		Contract.require(values.length > 0, "source index must inventory files");
		var previousId = "";
		for (value in values) {
			final hasSourceIdentity = Contract.has(value, "sourceIdentity", "source-index file");
			Contract.fields(value, hasSourceIdentity ? [
				"id",
				"path",
				"role",
				"language",
				"sha256",
				"byteLength",
				"distribution",
				"sourceIdentity"
			] : ["id", "path", "role", "language", "sha256", "byteLength", "distribution"], "source-index file");
			final id = Content.stableId(Contract.string(value, "id", "source-index file"), "source-index file ID");
			Contract.require(previousId == "" || Content.compareText(previousId, id) < 0, "source-index file IDs must be sorted and unique");
			previousId = id;
			final path = Content.safeRelativePath(Contract.string(value, "path", "source-index file"), "source-index file path");
			Contract.require(!filesByPath.exists(path), "source-index file paths must be unique", true);
			final role = closed(Contract.string(value, "role", "source-index file"), ["runtime", "generated-source", "source-map", "source"], "file role");
			final sourceIdentity = hasSourceIdentity ? validateSourceIdentity(Contract.fieldValue(value, "sourceIdentity", "source-index file")) : null;
			final record:SourceFileRecord = {
				id: id,
				path: path,
				role: role,
				language: closed(Contract.string(value, "language", "source-index file"), ["php", "javascript", "typescript", "tsx", "haxe", "json"],
					"file language"),
				sha256: Content.sha256(Contract.string(value, "sha256", "source-index file"), "source-index file"),
				byteLength: Contract.integer(value, "byteLength", "source-index file"),
				distribution: closed(Contract.string(value, "distribution", "source-index file"), ["production", "debug-companion", "local-only", "external"],
					"file distribution"),
				sourceIdentity: sourceIdentity
			};
			Contract.require(record.byteLength > 0, "source-index file byte length must be positive");
			Contract.require(!filesById.exists(id), "duplicate source-index file ID", true);
			filesById.set(id, record);
			filesByPath.set(path, record);
			if (sourceIdentity != null) {
				Contract.require(role == "source", "only a source file may declare sourceIdentity");
				bindSource(record, sourceIdentity);
			} else {
				Contract.require(role != "source", "a source file must declare sourceIdentity");
				validateIndexedArtifact(record);
			}
		}
	}

	function validateSourceIdentity(value:JsonValue):SourceIdentity {
		Contract.fields(value, ["rootId", "path"], "source identity");
		return {
			rootId: Content.stableId(Contract.string(value, "rootId", "source identity"), "source identity root ID"),
			path: Content.safeRelativePath(Contract.string(value, "path", "source identity"), "source identity path")
		};
	}

	function bindSource(record:SourceFileRecord, identity:SourceIdentity):Void {
		Contract.require(rootsById.exists(identity.rootId), "source identity references an unknown root");
		final root = rootsById.get(identity.rootId);
		var content:Null<String> = null;
		var resolved:Null<String> = null;
		if (sourceRootArguments.exists(identity.rootId)) {
			resolved = safeResolve(sourceRootArguments.get(identity.rootId), identity.path, "source root " + identity.rootId);
		} else if (root.resolution == "debug-companion-relative") {
			final packagePath = root.packagePath;
			Contract.require(packagePath != null, "debug-companion source root lost packagePath");
			Contract.require(record.path == packagePath + "/" + identity.path, "debug-companion source path contradicts its logical root");
			resolved = safeResolve(indexRoot, record.path, "debug-companion source");
		}
		if (resolved != null) {
			content = readUtf8(existingFile(resolved, "source " + record.id), "source " + record.id);
			validateBoundFile(record, content, "source " + record.id);
		}
		sourceBindingsByFileId.set(record.id, {record: record, root: root, content: content});
	}

	function validateIndexedArtifact(record:SourceFileRecord):Void {
		if (record.distribution == "external") {
			return;
		}
		final content = readUtf8(existingFile(safeResolve(indexRoot, record.path, "indexed artifact"), "indexed artifact " + record.id),
			"indexed artifact " + record.id);
		validateBoundFile(record, content, "indexed artifact " + record.id);
	}

	function validateCorrelations(values:Array<JsonValue>):Void {
		Contract.require(values.length > 0, "source index must declare correlations");
		var previous = "";
		final entryCorrelations:Map<String, Bool> = [];
		for (value in values) {
			final strategy = Contract.string(value, "strategy", "correlation");
			final id = Content.stableId(Contract.string(value, "id", "correlation"), "correlation ID");
			Contract.require(previous == "" || Content.compareText(previous, id) < 0, "correlation IDs must be sorted and unique");
			previous = id;
			final target = closed(Contract.string(value, "target", "correlation"), ["php", "browser"], "correlation target");
			final entryFileId = Content.stableId(Contract.string(value, "entryFileId", "correlation"), "correlation entry file ID");
			Contract.require(filesById.exists(entryFileId)
				&& filesById.get(entryFileId).role == "runtime", "correlation entry is not an indexed runtime file");
			final receiptIds = validateReceiptIds(Contract.array(value, "proofReceiptIds", "correlation"));
			if (strategy == "unavailable") {
				Contract.fields(value, ["id", "entryFileId", "target", "strategy", "status", "reason", "proofReceiptIds"], "correlation");
				final status = Contract.string(value, "status", "correlation");
				Contract.require(status == "unavailable", "unavailable correlation has an invalid status");
				correlations.push(UnavailableCorrelation({
					id: id,
					entryFileId: entryFileId,
					target: target,
					strategy: strategy,
					status: status,
					reason: closed(Contract.string(value, "reason", "correlation"), [
						"map-not-emitted",
						"composition-unproven",
						"unsupported-toolchain",
						"retention-policy"
					], "unavailable reason"),
					proofReceiptIds: receiptIds
				}));
			} else {
				Contract.fields(value, ["id", "entryFileId", "target", "strategy", "status", "layers", "proofReceiptIds"], "correlation");
				final status = closed(Contract.string(value, "status", "correlation"), ["schema-only", "bounded-local", "hosted-runtime"],
					"correlation status");
				correlations.push(AvailableCorrelation({
					id: id,
					entryFileId: entryFileId,
					target: target,
					strategy: strategy,
					status: status,
					layers: validateLayers(strategy, target, entryFileId, Contract.array(value, "layers", "correlation")),
					proofReceiptIds: receiptIds
				}));
			}
			final entryKey = target + "\x00" + entryFileId;
			Contract.require(!entryCorrelations.exists(entryKey), "multiple correlations target one exact runtime file", true);
			entryCorrelations.set(entryKey, true);
		}
	}

	function validateLayers(strategy:String, target:String, entryFileId:String, values:Array<JsonValue>):Array<SourceCorrelationLayer> {
		final expectedLength = strategy == "browser-two-stage-v3" ? 2 : 1;
		Contract.require((strategy == "php-range-map" || strategy == "browser-composed-v3" || strategy == "browser-two-stage-v3")
			&& values.length == expectedLength,
			"correlation strategy has an invalid layer count");
		final layers:Array<SourceCorrelationLayer> = [];
		for (index in 0...values.length) {
			final value = values[index];
			Contract.fields(value, [
				"order",
				"mapFileId",
				"format",
				"generatedFileId",
				"generatedLanguage",
				"sourceLanguage",
				"sourceFileIds"
			], "correlation layer");
			Contract.require(Contract.integer(value, "order", "correlation layer") == index, "correlation layer order is not contiguous");
			final mapFileId = Content.stableId(Contract.string(value, "mapFileId", "correlation layer"), "correlation layer map file ID");
			final generatedFileId = Content.stableId(Contract.string(value, "generatedFileId", "correlation layer"), "correlation layer generated file ID");
			Contract.require(filesById.exists(mapFileId) && filesById.exists(generatedFileId), "correlation layer references an unknown file ID");
			final mapRecord = filesById.get(mapFileId);
			final generatedRecord = filesById.get(generatedFileId);
			Contract.require(mapRecord.role == "source-map" && mapRecord.language == "json", "correlation map file shape is invalid");
			final format = closed(Contract.string(value, "format", "correlation layer"), ["wordpresshx.php-haxe-range-map.v1", "source-map-v3"], "map format");
			final generatedLanguage = closed(Contract.string(value, "generatedLanguage", "correlation layer"), ["php", "javascript", "typescript", "tsx"],
				"generated language");
			final sourceLanguage = closed(Contract.string(value, "sourceLanguage", "correlation layer"), ["haxe", "typescript", "tsx"], "source language");
			Contract.require(generatedRecord.language == generatedLanguage, "correlation generated language contradicts its indexed file");
			final sourceFileIds = Contract.strings(value, "sourceFileIds", "correlation layer");
			Contract.require(sourceFileIds.length > 0, "correlation layer must bind source files");
			final seen:Map<String, Bool> = [];
			for (sourceIdValue in sourceFileIds) {
				final sourceId = Content.stableId(sourceIdValue, "correlation source file ID");
				Contract.require(filesById.exists(sourceId) && !seen.exists(sourceId), "correlation layer has an unknown or duplicate source file ID");
				final sourceRecord = filesById.get(sourceId);
				Contract.require(sourceRecord.language == sourceLanguage, "correlation source language contradicts its indexed file");
				Contract.require(sourceLanguage == "haxe" ? sourceRecord.role == "source" : sourceRecord.role == "generated-source",
					"correlation layer source has an invalid file role");
				seen.set(sourceId, true);
			}
			if (index == 0) {
				Contract.require(generatedFileId == entryFileId && generatedRecord.role == "runtime",
					"first correlation layer must bind the exact runtime entry");
			} else {
				Contract.require(layers[index - 1].sourceFileIds.indexOf(generatedFileId) >= 0
					&& generatedRecord.role == "generated-source",
					"correlation layer continuity is invalid");
			}
			if (strategy == "php-range-map") {
				Contract.require(target == "php"
					&& format == "wordpresshx.php-haxe-range-map.v1"
					&& generatedLanguage == "php"
					&& sourceLanguage == "haxe",
					"PHP correlation layer shape is invalid");
			} else if (strategy == "browser-composed-v3") {
				Contract.require(target == "browser" && format == "source-map-v3" && generatedLanguage == "javascript" && sourceLanguage == "haxe",
					"composed browser correlation layer shape is invalid");
			} else if (index == 0) {
				Contract.require(target == "browser"
					&& format == "source-map-v3"
					&& generatedLanguage == "javascript"
					&& (sourceLanguage == "typescript" || sourceLanguage == "tsx"),
					"first two-stage browser correlation layer shape is invalid");
			} else {
				Contract.require(format == "source-map-v3"
					&& (generatedLanguage == "typescript" || generatedLanguage == "tsx")
					&& generatedLanguage == layers[0].sourceLanguage
					&& sourceLanguage == "haxe",
					"second two-stage browser correlation layer shape is invalid");
			}
			layers.push({
				order: index,
				mapFileId: mapFileId,
				format: format,
				generatedFileId: generatedFileId,
				generatedLanguage: generatedLanguage,
				sourceLanguage: sourceLanguage,
				sourceFileIds: sourceFileIds
			});
		}
		return layers;
	}

	function validateReceiptIds(values:Array<JsonValue>):Array<String> {
		final result:Array<String> = [];
		var previous = "";
		for (index in 0...values.length) {
			final id = Content.stableId(Contract.stringValue(values[index], "proof receipt ID"), "proof receipt ID");
			Contract.require(previous == "" || Content.compareText(previous, id) < 0, "proof receipt IDs must be sorted and unique");
			previous = id;
			result.push(id);
		}
		return result;
	}

	public static function safeResolve(root:String, relative:String, label:String):String {
		Content.safeRelativePath(relative, label + " path");
		final absoluteRoot = Path.resolve(root);
		final resolved = Path.resolve(absoluteRoot, relative);
		final back = Path.relative(absoluteRoot, resolved);
		Contract.require(back.length > 0 && !Path.isAbsolute(back) && back != ".." && !StringTools.startsWith(back, "../"), label + " escapes its root");
		return resolved;
	}

	public static function validateBoundFile(record:SourceFileRecord, content:String, label:String):Void {
		Contract.require(record.sha256 == Content.digest(content), label + " SHA-256 mismatch");
		Contract.require(record.byteLength == Content.byteLength(content), label + " byte-length mismatch");
	}

	public static function existingFile(path:String, label:String):String {
		final resolved = Path.resolve(path);
		Contract.require(Fs.existsSync(resolved) && Fs.statSync(resolved).isFile(), label + " does not exist: " + path);
		return resolved;
	}

	public static function readUtf8(path:String, label:String):String {
		final bytes = Fs.readFileSync(path);
		final value = bytes.toString("utf8");
		Contract.require(Buffer.compareBuffers(bytes, Buffer.from(value, "utf8")) == 0, label + " is not valid UTF-8");
		Contract.require(value.indexOf("\x00") < 0, label + " contains a NUL byte");
		return value;
	}

	public static function parseJson(source:String, label:String):JsonValue {
		try {
			return JsonDocument.parse(Buffer.from(source, "utf8"), label, "trace-json");
		} catch (_:JsonDocumentError) {
			return Contract.fail(label + " is not valid JSON");
		}
	}

	static function closed(value:String, allowed:Array<String>, label:String):String {
		Contract.require(allowed.indexOf(value) >= 0, "unsupported " + label + ": " + value);
		return value;
	}
}
