package wordpresshx.cli;

import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.Content.ContentPosition;
import wordpresshx.cli.Content.ContentSpan;
import wordpresshx.cli.SourceIndex.AvailableSourceCorrelation;
import wordpresshx.cli.SourceIndex.SourceBinding;
import wordpresshx.cli.SourceIndex.SourceFileRecord;
import wordpresshx.cli.SourceIndex.SourcePackageIdentity;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

private typedef PhpMapSource = {
	final id:String;
	final rootId:String;
	final path:String;
	final kind:String;
	final sha256:String;
	final byteLength:Int;
	final lineCount:Int;
}

private typedef PhpSourceOrigin = {
	final kind:String;
	final sourceId:String;
	final sourceSpan:ContentSpan;
	final semanticNodeId:String;
}

private typedef PhpCompilerOrigin = {
	final reasonClass:String;
	final reasonId:String;
	final parentSemanticNodeId:Null<String>;
}

private enum PhpMappingOrigin {
	SourceOrigin(value:PhpSourceOrigin);
	CompilerOrigin(value:PhpCompilerOrigin);
}

private typedef PhpMapping = {
	final id:String;
	final generatedSpan:ContentSpan;
	final nodeKind:String;
	final structuralDepth:Int;
	final origin:PhpMappingOrigin;
}

private typedef PhpEntry = {
	final absolutePath:String;
	final content:String;
	final sourcesById:Map<String, PhpMapSource>;
	final anchors:Map<Int, PhpMapping>;
}

private typedef ParsedNativeFrame = {
	final raw:String;
	final file:String;
	final line:Int;
}

typedef PhpRuntimeFrame = {
	final file:String;
	final line:Int;
}

typedef PhpCorrelatedSource = {
	final rootId:String;
	final path:String;
	final start:ContentPosition;
	final end:ContentPosition;
}

typedef PhpCorrelatedFrame = {
	final mappingId:String;
	final semanticNodeId:String;
	final nodeKind:String;
	final source:PhpCorrelatedSource;
}

typedef PhpTraceFrame = {
	final native:String;
	final status:String;
	final frame:Null<PhpRuntimeFrame>;
	final correlated:Null<PhpCorrelatedFrame>;
}

typedef TraceSummaryEntry = {
	final status:String;
	final count:Int;
}

typedef PhpTraceResult = {
	final schemaVersion:Int;
	final command:String;
	final packageIdentity:SourcePackageIdentity;
	final frames:Array<PhpTraceFrame>;
	final summary:Array<TraceSummaryEntry>;
}

private typedef ValidatedPhpSources = {
	final byId:Map<String, PhpMapSource>;
	final bindings:Map<String, SourceBinding>;
}

private typedef ValidatedPhpMappings = {
	final ordered:Array<PhpMapping>;
	final byId:Map<String, PhpMapping>;
}

/** Offline, read-only PHP native-stack correlator for one authenticated package index. */
class PhpTraceEngine {
	static final EXCEPTION_FRAME = ~/ in (.+):([0-9]+)$/;
	static final STACK_FRAME = ~/^#[0-9]+ (.+)\(([0-9]+)\):/;

	final indexRoot:String;
	final filesById:Map<String, SourceFileRecord>;
	final sourceBindingsByFileId:Map<String, SourceBinding>;
	final phpEntriesByPath:Map<String, PhpEntry> = [];
	final packageIdentity:SourcePackageIdentity;

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		final sourceIndex = new SourceIndex(indexPath, sourceRootArguments);
		indexRoot = sourceIndex.indexRoot;
		filesById = sourceIndex.filesById;
		sourceBindingsByFileId = sourceIndex.sourceBindingsByFileId;
		packageIdentity = sourceIndex.packageIdentity;
		for (correlation in sourceIndex.correlations) {
			switch correlation {
				case AvailableCorrelation(value) if (value.target == "php" && value.strategy == "php-range-map"):
					loadPhpEntry(value);
				case _:
			}
		}
	}

	public function trace(stack:String):PhpTraceResult {
		final nativeLines = stack.split("\n");
		if (nativeLines.length > 0 && nativeLines[nativeLines.length - 1] == "") {
			nativeLines.pop();
		}
		final frames:Array<PhpTraceFrame> = [];
		final counts:Map<String, Int> = [];
		for (line in nativeLines) {
			final parsed = parseNativeFrame(line);
			final frame = parsed == null ? nativeOnly(line) : correlate(parsed);
			frames.push(frame);
			counts.set(frame.status, (counts.exists(frame.status) ? counts.get(frame.status) : 0) + 1);
		}
		final statuses = [for (status in counts.keys()) status];
		statuses.sort(Content.compareText);
		return {
			schemaVersion: 1,
			command: "trace php",
			packageIdentity: packageIdentity,
			frames: frames,
			summary: [for (status in statuses) {status: status, count: counts.get(status)}]
		};
	}

	public static function text(result:PhpTraceResult):String {
		final lines:Array<String> = [];
		for (frame in result.frames) {
			lines.push(frame.native);
			if (frame.frame != null) {
				var annotation = "  => " + frame.status;
				if (frame.correlated != null) {
					final correlated = frame.correlated;
					final source = correlated.source;
					annotation += " " + source.rootId + ":" + source.path + ":" + source.start.line + ":" + source.start.columnUtf8 + " semantic="
						+ correlated.semanticNodeId + " mapping=" + correlated.mappingId;
				}
				lines.push(annotation);
			}
		}
		return lines.join("\n") + "\n";
	}

	public static function json(result:PhpTraceResult):JsonValue {
		return object([
			field("schemaVersion", number(result.schemaVersion)),
			field("command", textValue(result.command)),
			field("packageIdentity", packageJson(result.packageIdentity)),
			field("frames", ArrayValue(result.frames.map(frameJson))),
			field("summary", ObjectValue([for (entry in result.summary) field(entry.status, number(entry.count))]))
		]);
	}

	function loadPhpEntry(correlation:AvailableSourceCorrelation):Void {
		final layer = correlation.layers[0];
		Contract.require(layer.format == "wordpresshx.php-haxe-range-map.v1"
			&& layer.generatedLanguage == "php"
			&& layer.sourceLanguage == "haxe",
			"PHP correlation layer shape is invalid");
		final runtime = filesById.get(correlation.entryFileId);
		Contract.require(layer.generatedFileId == correlation.entryFileId
			&& runtime.language == "php", "PHP correlation entry binding is invalid");
		final mapRecord = filesById.get(layer.mapFileId);
		Contract.require(mapRecord.role == "source-map" && mapRecord.language == "json", "PHP correlation map binding is invalid");
		final runtimePath = safeResolve(indexRoot, runtime.path, "PHP runtime entry");
		final runtimeContent = readUtf8(existingFile(runtimePath, "PHP runtime entry"), "PHP runtime entry");
		validateBoundFile(runtime, runtimeContent, "PHP runtime entry");
		final mapPath = safeResolve(indexRoot, mapRecord.path, "PHP range map");
		final mapSource = readUtf8(existingFile(mapPath, "PHP range map"), "PHP range map");
		validateBoundFile(mapRecord, mapSource, "PHP range map");
		final validated = validatePhpMap(parseJson(mapSource, "PHP range map"), runtime, runtimeContent, layer.sourceFileIds);
		final absolutePath = realPath(runtimePath);
		Contract.require(!phpEntriesByPath.exists(absolutePath), "two PHP entries resolve to one native path", true);
		phpEntriesByPath.set(absolutePath, {
			absolutePath: absolutePath,
			content: runtimeContent,
			sourcesById: validated.sources,
			anchors: validated.anchors
		});
	}

	function validatePhpMap(map:JsonValue, runtime:SourceFileRecord, runtimeContent:String,
			sourceFileIds:Array<String>):{sources:Map<String, PhpMapSource>, anchors:Map<Int, PhpMapping>} {
		Contract.fields(map, [
			"schemaVersion",
			"format",
			"generator",
			"buildInputsSha256",
			"coordinateSystem",
			"generated",
			"sources",
			"mappings",
			"traceAnchors"
		], "PHP range map");
		Contract.require(Contract.integer(map, "schemaVersion", "PHP range map") == 1
			&& Contract.string(map, "format", "PHP range map") == "wordpresshx.php-haxe-range-map.v1",
			"unsupported PHP range-map contract");
		Content.sha256(Contract.string(map, "buildInputsSha256", "PHP range map"), "PHP map build inputs");
		validateGenerator(Contract.fieldValue(map, "generator", "PHP range map"));
		validateCoordinateSystem(Contract.fieldValue(map, "coordinateSystem", "PHP range map"));
		validateGeneratedFile(Contract.fieldValue(map, "generated", "PHP range map"), runtime, runtimeContent);
		final sources = validateMapSources(Contract.array(map, "sources", "PHP range map"), sourceFileIds);
		final mappings = validateMappings(Contract.array(map, "mappings", "PHP range map"), runtimeContent, sources.bindings);
		final anchors = validateAnchors(Contract.array(map, "traceAnchors", "PHP range map"), runtimeContent, mappings.byId);
		return {sources: sources.byId, anchors: anchors};
	}

	function validateGenerator(value:JsonValue):Void {
		Contract.fields(value, ["id", "version", "sourceSha256"], "PHP map generator");
		Content.stableId(Contract.string(value, "id", "PHP map generator"), "PHP map generator ID");
		Contract.string(value, "version", "PHP map generator");
		Content.sha256(Contract.string(value, "sourceSha256", "PHP map generator"), "PHP map generator source");
	}

	function validateCoordinateSystem(value:JsonValue):Void {
		Contract.fields(value, ["byteEncoding", "byteRange", "lineBase", "columnBase", "columnEncoding"], "PHP map coordinate system");
		Contract.require(Contract.string(value, "byteEncoding", "PHP map coordinate system") == "utf-8"
			&& Contract.string(value, "byteRange", "PHP map coordinate system") == "half-open"
			&& Contract.integer(value, "lineBase", "PHP map coordinate system") == 1
			&& Contract.integer(value, "columnBase", "PHP map coordinate system") == 0
			&& Contract.string(value, "columnEncoding", "PHP map coordinate system") == "utf-8-bytes",
			"unsupported PHP map coordinate system");
	}

	function validateGeneratedFile(value:JsonValue, runtime:SourceFileRecord, content:String):Void {
		Contract.fields(value, ["path", "sha256", "byteLength", "lineCount", "encoding", "lineEndings"], "PHP map generated file");
		final path = Content.safeRelativePath(Contract.string(value, "path", "PHP map generated file"), "generated PHP path");
		final sha256 = Content.sha256(Contract.string(value, "sha256", "PHP map generated file"), "generated PHP");
		final byteLength = Contract.integer(value, "byteLength", "PHP map generated file");
		Contract.require(path == runtime.path, "PHP map generated path disagrees with the source index");
		Contract.require(sha256 == runtime.sha256 && byteLength == runtime.byteLength, "PHP map/index generated-content binding mismatch");
		Contract.require(sha256 == Content.digest(content)
			&& byteLength == Content.byteLength(content)
			&& Contract.integer(value, "lineCount", "PHP map generated file") == Content.lineCount(content),
			"PHP map generated-content identity mismatch");
		Contract.require(Contract.string(value, "encoding", "PHP map generated file") == "utf-8"
			&& Contract.string(value, "lineEndings", "PHP map generated file") == "lf"
			&& content.indexOf("\r") < 0,
			"generated PHP is not LF-normalized UTF-8");
	}

	function validateMapSources(values:Array<JsonValue>, sourceFileIds:Array<String>):ValidatedPhpSources {
		Contract.require(values.length > 0, "PHP range map must bind source files");
		final indexed:Map<String, SourceBinding> = [];
		for (fileId in sourceFileIds) {
			Contract.require(sourceBindingsByFileId.exists(fileId), "PHP map source layer does not reference an indexed source file");
			final binding = sourceBindingsByFileId.get(fileId);
			final identity = binding.record.sourceIdentity;
			Contract.require(identity != null, "PHP map source lost its source identity");
			indexed.set(identity.rootId + "\x00" + identity.path + "\x00" + binding.record.sha256, binding);
		}
		final sourcesById:Map<String, PhpMapSource> = [];
		final bindings:Map<String, SourceBinding> = [];
		var previous = "";
		for (value in values) {
			Contract.fields(value, ["id", "rootId", "path", "kind", "sha256", "byteLength", "lineCount"], "PHP map source");
			final source:PhpMapSource = {
				id: Content.stableId(Contract.string(value, "id", "PHP map source"), "PHP map source ID"),
				rootId: Content.stableId(Contract.string(value, "rootId", "PHP map source"), "PHP map source root ID"),
				path: Content.safeRelativePath(Contract.string(value, "path", "PHP map source"), "PHP map source path"),
				kind: closed(Contract.string(value, "kind", "PHP map source"), ["haxe", "native"], "PHP map source kind"),
				sha256: Content.sha256(Contract.string(value, "sha256", "PHP map source"), "PHP map source"),
				byteLength: Contract.integer(value, "byteLength", "PHP map source"),
				lineCount: Contract.integer(value, "lineCount", "PHP map source")
			};
			Contract.require(previous == ""
				|| Content.compareText(previous, source.id) < 0, "PHP map source IDs must be sorted and unique");
			previous = source.id;
			Contract.require(source.byteLength > 0 && source.lineCount > 0, "PHP map source dimensions must be positive");
			final key = source.rootId + "\x00" + source.path + "\x00" + source.sha256;
			Contract.require(indexed.exists(key), "PHP map source identity disagrees with the source index");
			final binding = indexed.get(key);
			Contract.require(binding.record.byteLength == source.byteLength, "PHP map/index source byte length mismatch");
			sourcesById.set(source.id, source);
			bindings.set(source.id, binding);
		}
		Contract.require([for (_ in sourcesById.keys()) true].length == sourceFileIds.length, "PHP map/index source binding is incomplete");
		return {byId: sourcesById, bindings: bindings};
	}

	function validateMappings(values:Array<JsonValue>, generatedContent:String, sources:Map<String, SourceBinding>):ValidatedPhpMappings {
		Contract.require(values.length > 0, "PHP range map must contain mappings");
		final ordered:Array<PhpMapping> = [];
		final byId:Map<String, PhpMapping> = [];
		var previousStart = -1;
		var previousEnd = -1;
		var previousId = "";
		for (value in values) {
			Contract.fields(value, ["id", "generatedSpan", "nodeKind", "structuralDepth", "origin"], "PHP mapping");
			final id = Content.stableId(Contract.string(value, "id", "PHP mapping"), "PHP mapping ID");
			final generatedSpan = Content.validateSpan(Contract.fieldValue(value, "generatedSpan", "PHP mapping"), generatedContent,
				Content.byteLength(generatedContent), "PHP mapping " + id + " generated span");
			Contract.require(previousStart < generatedSpan.startByte
				|| (previousStart == generatedSpan.startByte
					&& (previousEnd < generatedSpan.endByte
						|| (previousEnd == generatedSpan.endByte && Content.compareText(previousId, id) < 0))),
				"PHP mappings are not in deterministic generated-span order");
			previousStart = generatedSpan.startByte;
			previousEnd = generatedSpan.endByte;
			previousId = id;
			final mapping:PhpMapping = {
				id: id,
				generatedSpan: generatedSpan,
				nodeKind: closed(Contract.string(value, "nodeKind", "PHP mapping"), [
					"file",
					"declaration",
					"member",
					"statement",
					"expression",
					"markup",
					"adapter",
					"compiler-generated"
				],
					"PHP mapping node kind"),
				structuralDepth: Contract.integer(value, "structuralDepth", "PHP mapping"),
				origin: validateOrigin(Contract.fieldValue(value, "origin", "PHP mapping"), sources, id)
			};
			Contract.require(mapping.structuralDepth >= 0, "PHP mapping structural depth is negative");
			Contract.require(!byId.exists(id), "duplicate PHP mapping ID", true);
			ordered.push(mapping);
			byId.set(id, mapping);
		}
		for (leftIndex in 0...ordered.length) {
			final left = ordered[leftIndex];
			for (rightIndex in leftIndex + 1...ordered.length) {
				final right = ordered[rightIndex];
				if (right.generatedSpan.startByte >= left.generatedSpan.endByte) {
					break;
				}
				final leftContains = left.generatedSpan.startByte <= right.generatedSpan.startByte
					&& left.generatedSpan.endByte >= right.generatedSpan.endByte;
				final rightContains = right.generatedSpan.startByte <= left.generatedSpan.startByte
					&& right.generatedSpan.endByte >= left.generatedSpan.endByte;
				Contract.require(leftContains || rightContains, "PHP mappings contain a crossing overlap");
				Contract.require(left.generatedSpan.startByte != right.generatedSpan.startByte
					|| left.generatedSpan.endByte != right.generatedSpan.endByte
					|| left.structuralDepth != right.structuralDepth,
					"PHP mappings contain an ambiguous equal-span tie", true);
			}
		}
		return {ordered: ordered, byId: byId};
	}

	function validateOrigin(value:JsonValue, sources:Map<String, SourceBinding>, mappingId:String):PhpMappingOrigin {
		final kind = Contract.string(value, "kind", "PHP mapping origin");
		if (kind == "haxe-source" || kind == "native-source") {
			Contract.fields(value, ["kind", "sourceId", "sourceSpan", "semanticNodeId"], "PHP mapping origin");
			final sourceId = Content.stableId(Contract.string(value, "sourceId", "PHP mapping origin"), "PHP mapping source ID");
			final semanticNodeId = Content.stableId(Contract.string(value, "semanticNodeId", "PHP mapping origin"), "PHP semantic node ID");
			Contract.require(sources.exists(sourceId), "PHP mapping " + mappingId + " references an unknown source");
			final binding = sources.get(sourceId);
			final expectedKind = kind == "haxe-source" ? "haxe" : "native";
			final mapSourceKind = binding.record.language == "haxe" ? "haxe" : "native";
			Contract.require(mapSourceKind == expectedKind, "PHP mapping source kind mismatch");
			return SourceOrigin({
				kind: kind,
				sourceId: sourceId,
				sourceSpan: Content.validateSpan(Contract.fieldValue(value, "sourceSpan", "PHP mapping origin"), binding.content, binding.record.byteLength,
					"PHP mapping " + mappingId + " source span"),
				semanticNodeId: semanticNodeId
			});
		}
		if (kind == "compiler-generated") {
			final hasParent = Contract.has(value, "parentSemanticNodeId", "PHP compiler origin");
			Contract.fields(value, hasParent ? ["kind", "reasonClass", "reasonId", "parentSemanticNodeId"] : ["kind", "reasonClass", "reasonId"],
				"PHP compiler origin");
			return CompilerOrigin({
				reasonClass: closed(Contract.string(value, "reasonClass", "PHP compiler origin"), [
					"file-prologue",
					"file-epilogue",
					"namespace-declaration",
					"import-declaration",
					"compiler-helper",
					"runtime-support",
					"formatting",
					"target-adapter",
					"other-reviewed"
				],
					"PHP compiler reason class"),
				reasonId: Content.stableId(Contract.string(value, "reasonId", "PHP compiler origin"), "PHP compiler reason ID"),
				parentSemanticNodeId: hasParent ? Content.stableId(Contract.string(value, "parentSemanticNodeId", "PHP compiler origin"),
					"PHP parent semantic node ID") : null
			});
		}
		return Contract.fail("unsupported PHP mapping origin kind: " + kind);
	}

	function validateAnchors(values:Array<JsonValue>, generatedContent:String, mappings:Map<String, PhpMapping>):Map<Int, PhpMapping> {
		final result:Map<Int, PhpMapping> = [];
		var previous = 0;
		for (value in values) {
			Contract.fields(value, ["generatedLine", "mappingId", "selection"], "PHP trace anchor");
			final line = Contract.integer(value, "generatedLine", "PHP trace anchor");
			final mappingId = Content.stableId(Contract.string(value, "mappingId", "PHP trace anchor"), "PHP trace-anchor mapping ID");
			Contract.require(Contract.string(value, "selection", "PHP trace anchor") == "emitter-runtime-line", "unsupported PHP trace-anchor selection");
			Contract.require(line > previous, "PHP trace anchors must have sorted unique lines", line == previous);
			previous = line;
			Contract.require(mappings.exists(mappingId), "PHP trace anchor references an unknown mapping");
			final mapping = mappings.get(mappingId);
			final interval = lineInterval(generatedContent, line);
			Contract.require(mapping.generatedSpan.startByte < interval.endByte && interval.startByte < mapping.generatedSpan.endByte,
				"PHP trace anchor does not intersect its mapping");
			result.set(line, mapping);
		}
		return result;
	}

	function correlate(frame:ParsedNativeFrame):PhpTraceFrame {
		final nativePath = normalizeNativePath(frame.file);
		if (!phpEntriesByPath.exists(nativePath)) {
			return parsedResult(frame, "unmapped-no-layer");
		}
		final entry = phpEntriesByPath.get(nativePath);
		if (frame.line <= 0 || frame.line > Content.lineCount(entry.content)) {
			throw new TraceFailure("native PHP frame line exceeds authenticated generated content", 2);
		}
		if (!entry.anchors.exists(frame.line)) {
			return parsedResult(frame, "unmapped-no-anchor");
		}
		final mapping = entry.anchors.get(frame.line);
		return switch mapping.origin {
			case CompilerOrigin(_): parsedResult(frame, "native-unmapped");
			case SourceOrigin(origin):
				Contract.require(entry.sourcesById.exists(origin.sourceId), "mapped PHP origin lost its source record");
				final source = entry.sourcesById.get(origin.sourceId);
				{
					native: frame.raw,
					status: "mapped-trace-anchor",
					frame: {file: frame.file, line: frame.line},
					correlated: {
						mappingId: mapping.id,
						semanticNodeId: origin.semanticNodeId,
						nodeKind: mapping.nodeKind,
						source: {
							rootId: source.rootId,
							path: source.path,
							start: origin.sourceSpan.start,
							end: origin.sourceSpan.end
						}
					}
				};
		};
	}

	function parseNativeFrame(raw:String):Null<ParsedNativeFrame> {
		for (pattern in [EXCEPTION_FRAME, STACK_FRAME]) {
			if (pattern.match(raw)) {
				final line = Std.parseInt(pattern.matched(2));
				if (line != null && line > 0) {
					return {raw: raw, file: pattern.matched(1), line: line};
				}
			}
		}
		return null;
	}

	function nativeOnly(raw:String):PhpTraceFrame {
		return {
			native: raw,
			status: "native-unmapped",
			frame: null,
			correlated: null
		};
	}

	function parsedResult(frame:ParsedNativeFrame, status:String):PhpTraceFrame {
		return {
			native: frame.raw,
			status: status,
			frame: {file: frame.file, line: frame.line},
			correlated: null
		};
	}

	function normalizeNativePath(value:String):String {
		final resolved = Path.isAbsolute(value) ? Path.normalize(value) : Path.resolve(value);
		return Fs.existsSync(resolved) ? realPath(resolved) : resolved;
	}

	function validateBoundFile(record:SourceFileRecord, content:String, label:String):Void {
		SourceIndex.validateBoundFile(record, content, label);
	}

	function lineInterval(content:String, line:Int):{startByte:Int, endByte:Int} {
		final bytes = haxe.io.Bytes.ofString(content);
		var currentLine = 1;
		var startByte = 0;
		for (index in 0...bytes.length) {
			if (currentLine == line && bytes.get(index) == 0x0a) {
				return {startByte: startByte, endByte: index + 1};
			}
			if (bytes.get(index) == 0x0a) {
				currentLine++;
				startByte = index + 1;
			}
		}
		return currentLine == line ? {startByte: startByte, endByte: bytes.length} : Contract.fail("PHP trace anchor line is out of bounds");
	}

	function safeResolve(root:String, relative:String, label:String):String {
		return SourceIndex.safeResolve(root, relative, label);
	}

	function existingFile(path:String, label:String):String {
		return SourceIndex.existingFile(path, label);
	}

	function realPath(path:String):String {
		return Path.normalize(Fs.realpathSync(path));
	}

	function readUtf8(path:String, label:String):String {
		return SourceIndex.readUtf8(path, label);
	}

	function parseJson(source:String, label:String):JsonValue {
		return SourceIndex.parseJson(source, label);
	}

	function closed(value:String, allowed:Array<String>, label:String):String {
		Contract.require(allowed.indexOf(value) >= 0, "unsupported " + label + ": " + value);
		return value;
	}

	static function frameJson(frame:PhpTraceFrame):JsonValue {
		final fields:Array<JsonField> = [
			field("native", textValue(frame.native)),
			field("status", textValue(frame.status))
		];
		if (frame.frame != null) {
			fields.push(field("frame", object([
				field("file", textValue(frame.frame.file)),
				field("line", number(frame.frame.line))
			])));
		}
		if (frame.correlated != null) {
			final correlated = frame.correlated;
			fields.push(field("correlated", object([
				field("mappingId", textValue(correlated.mappingId)),
				field("semanticNodeId", textValue(correlated.semanticNodeId)),
				field("nodeKind", textValue(correlated.nodeKind)),
				field("source", object([
					field("rootId", textValue(correlated.source.rootId)),
					field("path", textValue(correlated.source.path)),
					field("start", positionJson(correlated.source.start)),
					field("end", positionJson(correlated.source.end))
				]))
			])));
		}
		return object(fields);
	}

	static function packageJson(value:SourcePackageIdentity):JsonValue {
		return object([
			field("id", textValue(value.id)),
			field("version", textValue(value.version)),
			field("profileId", textValue(value.profileId))
		]);
	}

	static function positionJson(value:ContentPosition):JsonValue {
		return object([field("line", number(value.line)), field("columnUtf8", number(value.columnUtf8))]);
	}

	static inline function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	static inline function object(fields:Array<JsonField>):JsonValue {
		return ObjectValue(fields);
	}

	static inline function textValue(value:String):JsonValue {
		return StringValue(value);
	}

	static inline function number(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}
}
