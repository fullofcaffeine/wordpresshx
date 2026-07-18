package wordpresshx.cli;

import haxe.Json;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.SourceIndex.SourceBinding;

private typedef PhpEntry = {
	final absolutePath:String;
	final content:String;
	final map:Dynamic;
	final anchors:Map<Int, Dynamic>;
	final mappings:Map<String, Dynamic>;
}

private typedef ParsedNativeFrame = {
	final raw:String;
	final file:String;
	final line:Int;
}

/** Offline, read-only PHP native-stack correlator for one authenticated package index. **/
class PhpTraceEngine {
	static final EXCEPTION_FRAME = ~/ in (.+):([0-9]+)$/;
	static final STACK_FRAME = ~/^#[0-9]+ (.+)\(([0-9]+)\):/;

	final indexRoot:String;
	final filesById:Map<String, Dynamic>;
	final sourceBindingsByFileId:Map<String, SourceBinding>;
	final phpEntriesByPath:Map<String, PhpEntry> = [];
	final packageIdentity:Dynamic;

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		final sourceIndex = new SourceIndex(indexPath, sourceRootArguments);
		indexRoot = sourceIndex.indexRoot;
		filesById = sourceIndex.filesById;
		sourceBindingsByFileId = sourceIndex.sourceBindingsByFileId;
		packageIdentity = sourceIndex.packageIdentity;
		for (correlation in sourceIndex.correlations) {
			if (correlation.target == "php" && correlation.strategy == "php-range-map") {
				loadPhpEntry(correlation);
			}
		}
	}

	public function trace(stack:String):Dynamic {
		final nativeLines = stack.split("\n");
		if (nativeLines.length > 0 && nativeLines[nativeLines.length - 1] == "") {
			nativeLines.pop();
		}
		final frames:Array<Dynamic> = [];
		final counts:Map<String, Int> = [];
		for (line in nativeLines) {
			final parsed = parseNativeFrame(line);
			final frame = parsed == null ? nativeOnly(line) : correlate(parsed);
			frames.push(frame);
			final status:String = frame.status;
			counts.set(status, (counts.exists(status) ? counts.get(status) : 0) + 1);
		}
		final summary:Dynamic = {};
		final statuses = [for (status in counts.keys()) status];
		statuses.sort(Reflect.compare);
		for (status in statuses) {
			Reflect.setField(summary, status, counts.get(status));
		}
		return {
			schemaVersion: 1,
			command: "trace php",
			packageIdentity: packageIdentity,
			frames: frames,
			summary: summary
		};
	}

	public static function text(result:Dynamic):String {
		final lines:Array<String> = [];
		for (frame in cast(Reflect.field(result, "frames"), Array<Dynamic>)) {
			lines.push(frame.native);
			if (Reflect.hasField(frame, "frame")) {
				var annotation = "  => " + frame.status;
				if (Reflect.hasField(frame, "correlated")) {
					final correlated:Dynamic = frame.correlated;
					final source:Dynamic = correlated.source;
					annotation += " " + source.rootId + ":" + source.path + ":" + source.start.line + ":" + source.start.columnUtf8 + " semantic="
						+ correlated.semanticNodeId + " mapping=" + correlated.mappingId;
				}
				lines.push(annotation);
			}
		}
		return lines.join("\n") + "\n";
	}

	function loadPhpEntry(correlation:Dynamic):Void {
		final layer = (cast correlation.layers : Array<Dynamic>)[0];
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
		final map = parseJson(mapSource, "PHP range map");
		final validated = validatePhpMap(map, runtime, runtimeContent, cast layer.sourceFileIds);
		final absolutePath = realPath(runtimePath);
		Contract.require(!phpEntriesByPath.exists(absolutePath), "two PHP entries resolve to one native path", true);
		phpEntriesByPath.set(absolutePath, {
			absolutePath: absolutePath,
			content: runtimeContent,
			map: map,
			anchors: validated.anchors,
			mappings: validated.mappings
		});
	}

	function validatePhpMap(map:Dynamic, runtime:Dynamic, runtimeContent:String,
			sourceFileIds:Array<String>):{anchors:Map<Int, Dynamic>, mappings:Map<String, Dynamic>} {
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
		validateGenerator(Reflect.field(map, "generator"));
		validateCoordinateSystem(Reflect.field(map, "coordinateSystem"));
		validateGeneratedFile(Reflect.field(map, "generated"), runtime, runtimeContent);
		final mapSources = validateMapSources(Contract.array(map, "sources", "PHP range map"), sourceFileIds);
		final mappings = validateMappings(Contract.array(map, "mappings", "PHP range map"), runtimeContent, mapSources);
		final anchors = validateAnchors(Contract.array(map, "traceAnchors", "PHP range map"), runtimeContent, mappings);
		return {anchors: anchors, mappings: mappings};
	}

	function validateGenerator(value:Dynamic):Void {
		Contract.fields(value, ["id", "version", "sourceSha256"], "PHP map generator");
		Content.stableId(Contract.string(value, "id", "PHP map generator"), "PHP map generator ID");
		Contract.string(value, "version", "PHP map generator");
		Content.sha256(Contract.string(value, "sourceSha256", "PHP map generator"), "PHP map generator source");
	}

	function validateCoordinateSystem(value:Dynamic):Void {
		Contract.fields(value, ["byteEncoding", "byteRange", "lineBase", "columnBase", "columnEncoding"], "PHP map coordinate system");
		Contract.require(value.byteEncoding == "utf-8" && value.byteRange == "half-open" && value.lineBase == 1 && value.columnBase == 0
			&& value.columnEncoding == "utf-8-bytes",
			"unsupported PHP map coordinate system");
	}

	function validateGeneratedFile(value:Dynamic, runtime:Dynamic, content:String):Void {
		Contract.fields(value, ["path", "sha256", "byteLength", "lineCount", "encoding", "lineEndings"], "PHP map generated file");
		Contract.require(Content.safeRelativePath(Contract.string(value, "path", "PHP map generated file"), "generated PHP path") == runtime.path,
			"PHP map generated path disagrees with the source index");
		Contract.require(value.sha256 == runtime.sha256 && value.byteLength == runtime.byteLength, "PHP map/index generated-content binding mismatch");
		Contract.require(value.sha256 == Content.digest(content)
			&& value.byteLength == Content.byteLength(content)
			&& value.lineCount == Content.lineCount(content),
			"PHP map generated-content identity mismatch");
		Contract.require(value.encoding == "utf-8" && value.lineEndings == "lf" && content.indexOf("\r") < 0, "generated PHP is not LF-normalized UTF-8");
	}

	function validateMapSources(sources:Array<Dynamic>, sourceFileIds:Array<String>):Map<String, SourceBinding> {
		Contract.require(sources.length > 0, "PHP range map must bind source files");
		final indexed:Map<String, SourceBinding> = [];
		for (fileId in sourceFileIds) {
			Contract.require(sourceBindingsByFileId.exists(fileId), "PHP map source layer does not reference an indexed source file");
			final binding = sourceBindingsByFileId.get(fileId);
			final identity:Dynamic = binding.record.sourceIdentity;
			indexed.set(identity.rootId + "\x00" + identity.path + "\x00" + binding.record.sha256, binding);
		}
		final result:Map<String, SourceBinding> = [];
		var previous = "";
		for (source in sources) {
			Contract.fields(source, ["id", "rootId", "path", "kind", "sha256", "byteLength", "lineCount"], "PHP map source");
			final id = Content.stableId(Contract.string(source, "id", "PHP map source"), "PHP map source ID");
			Contract.require(previous == "" || Reflect.compare(previous, id) < 0, "PHP map source IDs must be sorted and unique");
			previous = id;
			final rootId = Content.stableId(Contract.string(source, "rootId", "PHP map source"), "PHP map source root ID");
			final path = Content.safeRelativePath(Contract.string(source, "path", "PHP map source"), "PHP map source path");
			closed(Contract.string(source, "kind", "PHP map source"), ["haxe", "native"], "PHP map source kind");
			final hash = Content.sha256(Contract.string(source, "sha256", "PHP map source"), "PHP map source");
			Contract.require(Contract.integer(source, "byteLength", "PHP map source") > 0
				&& Contract.integer(source, "lineCount", "PHP map source") > 0,
				"PHP map source dimensions must be positive");
			final key = rootId + "\x00" + path + "\x00" + hash;
			Contract.require(indexed.exists(key), "PHP map source identity disagrees with the source index");
			final binding = indexed.get(key);
			Contract.require(binding.record.byteLength == source.byteLength, "PHP map/index source byte length mismatch");
			result.set(id, binding);
		}
		Contract.require([for (_ in result.keys()) true].length == sourceFileIds.length, "PHP map/index source binding is incomplete");
		return result;
	}

	function validateMappings(values:Array<Dynamic>, generatedContent:String, sources:Map<String, SourceBinding>):Map<String, Dynamic> {
		Contract.require(values.length > 0, "PHP range map must contain mappings");
		final result:Map<String, Dynamic> = [];
		var previousStart = -1;
		var previousEnd = -1;
		var previousId = "";
		for (mapping in values) {
			Contract.fields(mapping, ["id", "generatedSpan", "nodeKind", "structuralDepth", "origin"], "PHP mapping");
			final id = Content.stableId(Contract.string(mapping, "id", "PHP mapping"), "PHP mapping ID");
			Content.validateSpan(mapping.generatedSpan, generatedContent, Content.byteLength(generatedContent), "PHP mapping " + id + " generated span");
			final start:Int = mapping.generatedSpan.startByte;
			final end:Int = mapping.generatedSpan.endByte;
			Contract.require(previousStart < start
				|| (previousStart == start && (previousEnd < end || (previousEnd == end && Reflect.compare(previousId, id) < 0))),
				"PHP mappings are not in deterministic generated-span order");
			previousStart = start;
			previousEnd = end;
			previousId = id;
			closed(Contract.string(mapping, "nodeKind", "PHP mapping"), [
				"file",
				"declaration",
				"member",
				"statement",
				"expression",
				"markup",
				"adapter",
				"compiler-generated"
			], "PHP mapping node kind");
			Contract.require(Contract.integer(mapping, "structuralDepth", "PHP mapping") >= 0, "PHP mapping structural depth is negative");
			validateOrigin(mapping.origin, sources, id);
			Contract.require(!result.exists(id), "duplicate PHP mapping ID", true);
			result.set(id, mapping);
		}
		for (leftIndex in 0...values.length) {
			final left = values[leftIndex];
			for (rightIndex in leftIndex + 1...values.length) {
				final right = values[rightIndex];
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
		return result;
	}

	function validateOrigin(origin:Dynamic, sources:Map<String, SourceBinding>, mappingId:String):Void {
		final kind = Contract.string(origin, "kind", "PHP mapping origin");
		if (kind == "haxe-source" || kind == "native-source") {
			Contract.fields(origin, ["kind", "sourceId", "sourceSpan", "semanticNodeId"], "PHP mapping origin");
			final sourceId = Content.stableId(Contract.string(origin, "sourceId", "PHP mapping origin"), "PHP mapping source ID");
			Content.stableId(Contract.string(origin, "semanticNodeId", "PHP mapping origin"), "PHP semantic node ID");
			Contract.require(sources.exists(sourceId), "PHP mapping " + mappingId + " references an unknown source");
			final binding = sources.get(sourceId);
			final expectedKind = kind == "haxe-source" ? "haxe" : "native";
			final mapSourceKind:String = Reflect.field(binding.record, "language") == "haxe" ? "haxe" : "native";
			Contract.require(mapSourceKind == expectedKind, "PHP mapping source kind mismatch");
			Content.validateSpan(origin.sourceSpan, binding.content, binding.record.byteLength, "PHP mapping " + mappingId + " source span");
		} else if (kind == "compiler-generated") {
			final hasParent = Reflect.hasField(origin, "parentSemanticNodeId");
			Contract.fields(origin, hasParent ? ["kind", "reasonClass", "reasonId", "parentSemanticNodeId"] : ["kind", "reasonClass", "reasonId"],
				"PHP compiler origin");
			closed(Contract.string(origin, "reasonClass", "PHP compiler origin"), [
				"file-prologue",
				"file-epilogue",
				"namespace-declaration",
				"import-declaration",
				"compiler-helper",
				"runtime-support",
				"formatting",
				"target-adapter",
				"other-reviewed"
			], "PHP compiler reason class");
			Content.stableId(Contract.string(origin, "reasonId", "PHP compiler origin"), "PHP compiler reason ID");
			if (hasParent) {
				Content.stableId(Contract.string(origin, "parentSemanticNodeId", "PHP compiler origin"), "PHP parent semantic node ID");
			}
		} else {
			Contract.fail("unsupported PHP mapping origin kind: " + kind);
		}
	}

	function validateAnchors(values:Array<Dynamic>, generatedContent:String, mappings:Map<String, Dynamic>):Map<Int, Dynamic> {
		final result:Map<Int, Dynamic> = [];
		var previous = 0;
		for (anchor in values) {
			Contract.fields(anchor, ["generatedLine", "mappingId", "selection"], "PHP trace anchor");
			final line = Contract.integer(anchor, "generatedLine", "PHP trace anchor");
			final mappingId = Content.stableId(Contract.string(anchor, "mappingId", "PHP trace anchor"), "PHP trace-anchor mapping ID");
			Contract.require(anchor.selection == "emitter-runtime-line", "unsupported PHP trace-anchor selection");
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

	function correlate(frame:ParsedNativeFrame):Dynamic {
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
		final origin:Dynamic = mapping.origin;
		if (origin.kind != "haxe-source" && origin.kind != "native-source") {
			return parsedResult(frame, "native-unmapped");
		}
		final source = sourceRecordByMapId(entry.map, origin.sourceId);
		final result = parsedResult(frame, "mapped-trace-anchor");
		Reflect.setField(result, "correlated", {
			mappingId: mapping.id,
			semanticNodeId: origin.semanticNodeId,
			nodeKind: mapping.nodeKind,
			source: {
				rootId: source.rootId,
				path: source.path,
				start: origin.sourceSpan.start,
				end: origin.sourceSpan.end
			}
		});
		return result;
	}

	function sourceRecordByMapId(map:Dynamic, sourceId:String):Dynamic {
		for (source in cast(map.sources, Array<Dynamic>)) {
			if (source.id == sourceId) {
				return source;
			}
		}
		return Contract.fail("mapped PHP origin lost its source record");
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

	function nativeOnly(raw:String):Dynamic {
		return {native: raw, status: "native-unmapped"};
	}

	function parsedResult(frame:ParsedNativeFrame, status:String):Dynamic {
		return {native: frame.raw, status: status, frame: {file: frame.file, line: frame.line}};
	}

	function normalizeNativePath(value:String):String {
		final resolved = Path.isAbsolute(value) ? Path.normalize(value) : Path.resolve(value);
		return Fs.existsSync(resolved) ? realPath(resolved) : resolved;
	}

	function validateBoundFile(record:Dynamic, content:String, label:String):Void {
		Contract.require(record.sha256 == Content.digest(content), label + " SHA-256 mismatch");
		Contract.require(record.byteLength == Content.byteLength(content), label + " byte-length mismatch");
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
		if (currentLine == line) {
			return {startByte: startByte, endByte: bytes.length};
		}
		return Contract.fail("PHP trace anchor line is out of bounds");
	}

	function safeResolve(root:String, relative:String, label:String):String {
		Content.safeRelativePath(relative, label + " path");
		final absoluteRoot = Path.resolve(root);
		final resolved = Path.resolve(absoluteRoot, relative);
		final back = Path.relative(absoluteRoot, resolved);
		Contract.require(back.length > 0 && !Path.isAbsolute(back) && back != ".." && !StringTools.startsWith(back, "../"), label + " escapes its root");
		return resolved;
	}

	function existingFile(path:String, label:String):String {
		final resolved = Path.resolve(path);
		Contract.require(Fs.existsSync(resolved) && Fs.statSync(resolved).isFile(), label + " does not exist: " + path);
		return resolved;
	}

	function realPath(path:String):String {
		return Path.normalize(Fs.realpathSync(path));
	}

	function readUtf8(path:String, label:String):String {
		final value:String = cast Fs.readFileSync(path, "utf8");
		Contract.require(value.indexOf("\x00") < 0, label + " contains a NUL byte");
		return value;
	}

	function parseJson(source:String, label:String):Dynamic {
		try {
			return Contract.object(Json.parse(source), label);
		} catch (failure:TraceFailure) {
			throw failure;
		} catch (_:Dynamic) {
			return Contract.fail(label + " is not valid JSON");
		}
	}

	function closed(value:String, allowed:Array<String>, label:String):String {
		Contract.require(allowed.indexOf(value) >= 0, "unsupported " + label + ": " + value);
		return value;
	}
}
