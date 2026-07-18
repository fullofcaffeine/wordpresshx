package wordpresshx.cli;

import haxe.Json;
import js.node.Fs;
import js.node.Path;

typedef SourceBinding = {
	final record:Dynamic;
	final root:Dynamic;
	final content:Null<String>;
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
	public final filesById:Map<String, Dynamic> = [];
	public final filesByPath:Map<String, Dynamic> = [];
	public final rootsById:Map<String, Dynamic> = [];
	public final sourceBindingsByFileId:Map<String, SourceBinding> = [];
	public final correlations:Array<Dynamic> = [];
	public var packageIdentity(default, null):Dynamic;
	public var retention(default, null):Dynamic;

	final sourceRootArguments:Map<String, String>;

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		this.indexPath = existingFile(indexPath, "source index");
		this.indexRoot = Path.dirname(this.indexPath);
		this.sourceRootArguments = sourceRootArguments;
		load();
	}

	public function file(fileId:String):Dynamic {
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
		Contract.require(!Reflect.hasField(record, "sourceIdentity"), label + " unexpectedly names an external source");
		Contract.require(record.distribution != "external", label + " is not present beside the source index");
		return safeResolve(indexRoot, record.path, label);
	}

	public function artifactContent(fileId:String, label:String):String {
		final record = file(fileId);
		final content = readUtf8(existingFile(artifactPath(fileId, label), label), label);
		validateBoundFile(record, content, label);
		return content;
	}

	function load():Void {
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
		validatePackage(Reflect.field(index, "package"));
		validateRetention(Reflect.field(index, "retention"));
		validateRoots(Contract.array(index, "sourceRoots", "source index"));
		final files = Contract.array(index, "files", "source index");
		validateFiles(files);
		Contract.require(Content.digest(CanonicalJson.encode(files)) == Content.sha256(Contract.string(index, "artifactSetSha256", "source index"),
			"source-index artifact set"),
			"source-index artifact-set digest mismatch");
		for (correlation in Contract.array(index, "correlations", "source index")) {
			correlations.push(correlation);
		}
		validateCorrelations();
	}

	function validatePackage(value:Dynamic):Void {
		Contract.fields(value, ["id", "version", "profileId"], "source index package");
		final id = Content.stableId(Contract.string(value, "id", "source index package"), "package ID");
		final version = Contract.string(value, "version", "source index package");
		final profileId = Content.stableId(Contract.string(value, "profileId", "source index package"), "profile ID");
		packageIdentity = {id: id, version: version, profileId: profileId};
	}

	function validateRetention(value:Dynamic):Void {
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
		closed(Contract.string(value, "profile", "source index retention"), ["development", "debug-companion", "production-evidence"], "retention profile");
		closed(Contract.string(value, "indexDistribution", "source index retention"), ["debug-companion", "local-only"], "index distribution");
		closed(Contract.string(value, "sourceContentPolicy", "source index retention"), ["omitted", "allowlisted-debug-only"], "source content policy");
		closed(Contract.string(value, "developmentHandler", "source index retention"), ["disabled", "opt-in-augment-only"], "development handler");
		Contract.require(!Contract.boolean(value, "mapsInProduction", "source index retention"), "source maps cannot be retained in production");
		Contract.require(!Contract.boolean(value, "inlineMapsInProduction", "source index retention"), "inline maps cannot be retained in production");
		Contract.require(!Contract.boolean(value, "machinePathsAllowed", "source index retention"), "machine paths cannot be admitted by the index");
		Contract.require(Contract.boolean(value, "secretScanRequiredForShipping", "source index retention"),
			"shipping source-correlation data requires secret scanning");
		retention = value;
	}

	function validateRoots(roots:Array<Dynamic>):Void {
		Contract.require(roots.length > 0, "source index must declare at least one source root");
		var previous = "";
		for (root in roots) {
			final hasPackagePath = Reflect.hasField(root, "packagePath");
			Contract.fields(root,
				hasPackagePath ? ["id", "kind", "resolution", "contentDistribution", "packagePath"] : ["id", "kind", "resolution", "contentDistribution"],
				"source root");
			final id = Content.stableId(Contract.string(root, "id", "source root"), "source root ID");
			Contract.require(previous == "" || Reflect.compare(previous, id) < 0, "source root IDs must be sorted and unique");
			previous = id;
			closed(Contract.string(root, "kind", "source root"), ["project", "dependency", "haxe-stdlib", "native"], "source root kind");
			final resolution = closed(Contract.string(root, "resolution", "source root"), ["cli-root-argument", "debug-companion-relative", "not-resolvable"],
				"source root resolution");
			closed(Contract.string(root, "contentDistribution", "source root"), ["external", "debug-companion", "local-only"],
				"source root content distribution");
			Contract.require((resolution == "debug-companion-relative") == hasPackagePath,
				"only a debug-companion-relative source root must declare packagePath");
			if (hasPackagePath) {
				Content.safeRelativePath(Contract.string(root, "packagePath", "source root"), "source root packagePath");
			}
			Contract.require(!rootsById.exists(id), "duplicate source root ID", true);
			rootsById.set(id, root);
		}
		for (id in sourceRootArguments.keys()) {
			if (!rootsById.exists(id)) {
				throw new TraceFailure("unknown --source-root ID: " + id, 2);
			}
		}
	}

	function validateFiles(files:Array<Dynamic>):Void {
		Contract.require(files.length > 0, "source index must inventory files");
		var previousId = "";
		for (record in files) {
			final hasSourceIdentity = Reflect.hasField(record, "sourceIdentity");
			Contract.fields(record, hasSourceIdentity ? [
				"id",
				"path",
				"role",
				"language",
				"sha256",
				"byteLength",
				"distribution",
				"sourceIdentity"
			] : ["id", "path", "role", "language", "sha256", "byteLength", "distribution"], "source-index file");
			final id = Content.stableId(Contract.string(record, "id", "source-index file"), "source-index file ID");
			Contract.require(previousId == "" || Reflect.compare(previousId, id) < 0, "source-index file IDs must be sorted and unique");
			previousId = id;
			final path = Content.safeRelativePath(Contract.string(record, "path", "source-index file"), "source-index file path");
			Contract.require(!filesByPath.exists(path), "source-index file paths must be unique", true);
			closed(Contract.string(record, "role", "source-index file"), ["runtime", "generated-source", "source-map", "source"], "file role");
			closed(Contract.string(record, "language", "source-index file"), ["php", "javascript", "typescript", "tsx", "haxe", "json"], "file language");
			Content.sha256(Contract.string(record, "sha256", "source-index file"), "source-index file");
			Contract.require(Contract.integer(record, "byteLength", "source-index file") > 0, "source-index file byte length must be positive");
			closed(Contract.string(record, "distribution", "source-index file"), ["production", "debug-companion", "local-only", "external"],
				"file distribution");
			Contract.require(!filesById.exists(id), "duplicate source-index file ID", true);
			filesById.set(id, record);
			filesByPath.set(path, record);
			if (hasSourceIdentity) {
				Contract.require(record.role == "source", "only a source file may declare sourceIdentity");
				bindSource(id, record, Reflect.field(record, "sourceIdentity"));
			} else {
				Contract.require(record.role != "source", "a source file must declare sourceIdentity");
				validateIndexedArtifact(record);
			}
		}
	}

	function bindSource(fileId:String, record:Dynamic, identity:Dynamic):Void {
		Contract.fields(identity, ["rootId", "path"], "source identity");
		final rootId = Content.stableId(Contract.string(identity, "rootId", "source identity"), "source identity root ID");
		final sourcePath = Content.safeRelativePath(Contract.string(identity, "path", "source identity"), "source identity path");
		Contract.require(rootsById.exists(rootId), "source identity references an unknown root");
		final root = rootsById.get(rootId);
		final resolution:String = root.resolution;
		var content:Null<String> = null;
		var resolved:Null<String> = null;
		if (sourceRootArguments.exists(rootId)) {
			resolved = safeResolve(sourceRootArguments.get(rootId), sourcePath, "source root " + rootId);
		} else if (resolution == "debug-companion-relative") {
			final packagePath = Content.safeRelativePath(root.packagePath, "source root packagePath");
			Contract.require(record.path == packagePath + "/" + sourcePath, "debug-companion source path contradicts its logical root");
			resolved = safeResolve(indexRoot, record.path, "debug-companion source");
		}
		if (resolved != null) {
			content = readUtf8(existingFile(resolved, "source " + fileId), "source " + fileId);
			validateBoundFile(record, content, "source " + fileId);
		}
		sourceBindingsByFileId.set(fileId, {record: record, root: root, content: content});
	}

	function validateIndexedArtifact(record:Dynamic):Void {
		if (record.distribution == "external") {
			return;
		}
		final content = readUtf8(existingFile(safeResolve(indexRoot, record.path, "indexed artifact"), "indexed artifact " + record.id),
			"indexed artifact " + record.id);
		validateBoundFile(record, content, "indexed artifact " + record.id);
	}

	function validateCorrelations():Void {
		Contract.require(correlations.length > 0, "source index must declare correlations");
		var previous = "";
		final entryCorrelations:Map<String, Bool> = [];
		for (correlation in correlations) {
			final strategy = Contract.string(correlation, "strategy", "correlation");
			if (strategy == "unavailable") {
				Contract.fields(correlation, ["id", "entryFileId", "target", "strategy", "status", "reason", "proofReceiptIds"], "correlation");
				Contract.require(Contract.string(correlation, "status", "correlation") == "unavailable", "unavailable correlation has an invalid status");
				closed(Contract.string(correlation, "reason", "correlation"), [
					"map-not-emitted",
					"composition-unproven",
					"unsupported-toolchain",
					"retention-policy"
				], "unavailable reason");
			} else {
				Contract.fields(correlation, ["id", "entryFileId", "target", "strategy", "status", "layers", "proofReceiptIds"], "correlation");
				closed(Contract.string(correlation, "status", "correlation"), ["schema-only", "bounded-local", "hosted-runtime"], "correlation status");
				validateLayers(correlation, Contract.array(correlation, "layers", "correlation"));
			}
			final id = Content.stableId(Contract.string(correlation, "id", "correlation"), "correlation ID");
			Contract.require(previous == "" || Reflect.compare(previous, id) < 0, "correlation IDs must be sorted and unique");
			previous = id;
			final target = closed(Contract.string(correlation, "target", "correlation"), ["php", "browser"], "correlation target");
			final entryFileId = Content.stableId(Contract.string(correlation, "entryFileId", "correlation"), "correlation entry file ID");
			Contract.require(filesById.exists(entryFileId)
				&& filesById.get(entryFileId).role == "runtime", "correlation entry is not an indexed runtime file");
			validateReceiptIds(Contract.array(correlation, "proofReceiptIds", "correlation"));
			final entryKey = target + "\x00" + entryFileId;
			Contract.require(!entryCorrelations.exists(entryKey), "multiple correlations target one exact runtime file", true);
			entryCorrelations.set(entryKey, true);
		}
	}

	function validateLayers(correlation:Dynamic, layers:Array<Dynamic>):Void {
		final strategy:String = correlation.strategy;
		final expectedLength = strategy == "browser-two-stage-v3" ? 2 : 1;
		Contract.require((strategy == "php-range-map" || strategy == "browser-composed-v3" || strategy == "browser-two-stage-v3")
			&& layers.length == expectedLength,
			"correlation strategy has an invalid layer count");
		for (index in 0...layers.length) {
			final layer = layers[index];
			Contract.fields(layer, [
				"order",
				"mapFileId",
				"format",
				"generatedFileId",
				"generatedLanguage",
				"sourceLanguage",
				"sourceFileIds"
			], "correlation layer");
			Contract.require(Contract.integer(layer, "order", "correlation layer") == index, "correlation layer order is not contiguous");
			final mapFileId = Content.stableId(Contract.string(layer, "mapFileId", "correlation layer"), "correlation layer map file ID");
			final generatedFileId = Content.stableId(Contract.string(layer, "generatedFileId", "correlation layer"), "correlation layer generated file ID");
			Contract.require(filesById.exists(mapFileId) && filesById.exists(generatedFileId), "correlation layer references an unknown file ID");
			final mapRecord = filesById.get(mapFileId);
			final generatedRecord = filesById.get(generatedFileId);
			Contract.require(mapRecord.role == "source-map" && mapRecord.language == "json", "correlation map file shape is invalid");
			final format = closed(Contract.string(layer, "format", "correlation layer"), ["wordpresshx.php-haxe-range-map.v1", "source-map-v3"], "map format");
			final generatedLanguage = closed(Contract.string(layer, "generatedLanguage", "correlation layer"), ["php", "javascript", "typescript", "tsx"],
				"generated language");
			final sourceLanguage = closed(Contract.string(layer, "sourceLanguage", "correlation layer"), ["haxe", "typescript", "tsx"], "source language");
			Contract.require(generatedRecord.language == generatedLanguage, "correlation generated language contradicts its indexed file");
			final sources = Contract.array(layer, "sourceFileIds", "correlation layer");
			Contract.require(sources.length > 0, "correlation layer must bind source files");
			final seen:Map<String, Bool> = [];
			for (sourceIdValue in sources) {
				Contract.require(Std.isOfType(sourceIdValue, String), "correlation source file ID must be a string");
				final sourceId = Content.stableId(sourceIdValue, "correlation source file ID");
				Contract.require(filesById.exists(sourceId) && !seen.exists(sourceId), "correlation layer has an unknown or duplicate source file ID");
				final sourceRecord = filesById.get(sourceId);
				Contract.require(sourceRecord.language == sourceLanguage, "correlation source language contradicts its indexed file");
				Contract.require(sourceLanguage == "haxe" ? sourceRecord.role == "source" : sourceRecord.role == "generated-source",
					"correlation layer source has an invalid file role");
				seen.set(sourceId, true);
			}
			if (index == 0) {
				Contract.require(generatedFileId == correlation.entryFileId && generatedRecord.role == "runtime",
					"first correlation layer must bind the exact runtime entry");
			} else {
				final previousSources:Array<Dynamic> = cast layers[index - 1].sourceFileIds;
				Contract.require(previousSources.indexOf(generatedFileId) >= 0 && generatedRecord.role == "generated-source",
					"correlation layer continuity is invalid");
			}
			if (strategy == "php-range-map") {
				Contract.require(correlation.target == "php"
					&& format == "wordpresshx.php-haxe-range-map.v1"
					&& generatedLanguage == "php"
					&& sourceLanguage == "haxe",
					"PHP correlation layer shape is invalid");
			} else if (strategy == "browser-composed-v3") {
				Contract.require(correlation.target == "browser" && format == "source-map-v3" && generatedLanguage == "javascript" && sourceLanguage == "haxe",
					"composed browser correlation layer shape is invalid");
			} else if (index == 0) {
				Contract.require(correlation.target == "browser"
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
		}
	}

	function validateReceiptIds(values:Array<Dynamic>):Void {
		var previous = "";
		for (value in values) {
			Contract.require(Std.isOfType(value, String), "proof receipt ID must be a string");
			final id = Content.stableId(value, "proof receipt ID");
			Contract.require(previous == "" || Reflect.compare(previous, id) < 0, "proof receipt IDs must be sorted and unique");
			previous = id;
		}
	}

	public static function safeResolve(root:String, relative:String, label:String):String {
		Content.safeRelativePath(relative, label + " path");
		final absoluteRoot = Path.resolve(root);
		final resolved = Path.resolve(absoluteRoot, relative);
		final back = Path.relative(absoluteRoot, resolved);
		Contract.require(back.length > 0 && !Path.isAbsolute(back) && back != ".." && !StringTools.startsWith(back, "../"), label + " escapes its root");
		return resolved;
	}

	public static function validateBoundFile(record:Dynamic, content:String, label:String):Void {
		Contract.require(record.sha256 == Content.digest(content), label + " SHA-256 mismatch");
		Contract.require(record.byteLength == Content.byteLength(content), label + " byte-length mismatch");
	}

	public static function existingFile(path:String, label:String):String {
		final resolved = Path.resolve(path);
		Contract.require(Fs.existsSync(resolved) && Fs.statSync(resolved).isFile(), label + " does not exist: " + path);
		return resolved;
	}

	public static function readUtf8(path:String, label:String):String {
		final value:String = cast Fs.readFileSync(path, "utf8");
		Contract.require(value.indexOf("\x00") < 0, label + " contains a NUL byte");
		return value;
	}

	public static function parseJson(source:String, label:String):Dynamic {
		try {
			return Contract.object(Json.parse(source), label);
		} catch (failure:TraceFailure) {
			throw failure;
		} catch (_:Dynamic) {
			return Contract.fail(label + " is not valid JSON");
		}
	}

	static function closed(value:String, allowed:Array<String>, label:String):String {
		Contract.require(allowed.indexOf(value) >= 0, "unsupported " + label + ": " + value);
		return value;
	}
}
