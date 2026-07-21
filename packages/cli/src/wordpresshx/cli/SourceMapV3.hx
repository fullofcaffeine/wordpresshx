package wordpresshx.cli;

import wordpresshx.cli.SourceIndex.SourceBinding;
import wordpresshx.cli.SourceIndex.SourceCorrelationLayer;
import wordpresshx.cli.SourceIndex.SourceFileRecord;
import wordpresshx.cli.closedjson.JsonValue;

typedef SourceMapPoint = {
	final sourceFileId:String;
	final line:Int;
	final column:Int;
	final name:Null<String>;
}

private typedef DecodedSegment = {
	final generatedColumn:Int;
	final sourceIndex:Null<Int>;
	final originalLine:Null<Int>;
	final originalColumn:Null<Int>;
	final nameIndex:Null<Int>;
}

/** Strict regular Source Map v3 reader and exact same-line point lookup. */
class SourceMapV3 {
	static final BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	public final mapFileId:String;
	public final generatedFileId:String;

	final sourceIndex:SourceIndex;
	final sourceFileIds:Array<String> = [];
	final sourceRecords:Array<SourceFileRecord> = [];
	final sourceBindings:Array<Null<SourceBinding>> = [];
	final sourceContents:Array<Null<String>> = [];
	final names:Array<String> = [];
	final lines:Array<Array<DecodedSegment>> = [];

	public function new(index:SourceIndex, layer:SourceCorrelationLayer) {
		sourceIndex = index;
		mapFileId = layer.mapFileId;
		generatedFileId = layer.generatedFileId;
		final mapRecord = index.file(mapFileId);
		final generatedRecord = index.file(generatedFileId);
		final source = index.artifactContent(mapFileId, "Source Map v3 " + mapFileId);
		validateShape(SourceIndex.parseJson(source, "Source Map v3 " + mapFileId), mapRecord, generatedRecord, layer.sourceFileIds);
	}

	public function lookup(generatedLine:Int, generatedColumn:Int):Null<SourceMapPoint> {
		Contract.require(generatedLine > 0 && generatedColumn >= 0, "browser frame has an invalid generated position");
		if (generatedLine > lines.length) {
			return null;
		}
		final segments = lines[generatedLine - 1];
		var selected:Null<DecodedSegment> = null;
		for (segment in segments) {
			if (segment.generatedColumn > generatedColumn) {
				break;
			}
			selected = segment;
		}
		if (selected == null || selected.sourceIndex == null) {
			return null;
		}
		final selectedSource = requireIndex(selected.sourceIndex, "Source Map selected segment lost its source index");
		final mappedLine = requireIndex(selected.originalLine, "Source Map selected segment lost its original line");
		final mappedColumn = requireIndex(selected.originalColumn, "Source Map selected segment lost its original column");
		validateMappedPosition(sourceContents[selectedSource], mappedLine + 1, mappedColumn);
		return {
			sourceFileId: sourceFileIds[selectedSource],
			line: mappedLine + 1,
			column: mappedColumn,
			name: selected.nameIndex == null ? null : names[requireIndex(selected.nameIndex, "Source Map selected name index is invalid")]
		};
	}

	function validateShape(map:JsonValue, mapRecord:SourceFileRecord, generatedRecord:SourceFileRecord, allowedSourceIds:Array<String>):Void {
		final hasSourcesContent = Contract.has(map, "sourcesContent", "Source Map v3");
		Contract.fields(map, hasSourcesContent ? [
			"version",
			"file",
			"sourceRoot",
			"sources",
			"sourcesContent",
			"names",
			"mappings"
		] : ["version", "file", "sourceRoot", "sources", "names", "mappings"], "Source Map v3");
		Contract.require(Contract.integer(map, "version", "Source Map v3") == 3, "unsupported Source Map version");
		final file = Contract.string(map, "file", "Source Map v3");
		Contract.require(file == basename(generatedRecord.path) && file.indexOf("/") < 0 && file.indexOf("\\") < 0,
			"Source Map file does not identify its exact generated file");
		Contract.require(Contract.text(map, "sourceRoot", "Source Map v3") == "", "Source Map sourceRoot must be empty");
		validateNames(Contract.array(map, "names", "Source Map v3"));
		validateSources(Contract.array(map, "sources", "Source Map v3"), allowedSourceIds, mapRecord.path);
		validateSourcesContent(map, hasSourcesContent);
		decodeMappings(Contract.string(map, "mappings", "Source Map v3"));
	}

	function validateNames(values:Array<JsonValue>):Void {
		for (index in 0...values.length) {
			final value = Contract.stringValue(values[index], "Source Map name");
			Contract.require(!hasControl(value), "Source Map name must be a non-empty safe string");
			names.push(value);
		}
	}

	function validateSources(values:Array<JsonValue>, allowedSourceIds:Array<String>, mapPath:String):Void {
		Contract.require(values.length > 0
			&& values.length == allowedSourceIds.length, "Source Map source inventory disagrees with its correlation layer");
		final allowed:Map<String, Bool> = [];
		for (value in allowedSourceIds) {
			final id = Content.stableId(value, "Source Map layer source file ID");
			Contract.require(!allowed.exists(id), "Source Map layer has duplicate source file IDs", true);
			allowed.set(id, true);
		}
		final seen:Map<String, Bool> = [];
		for (index in 0...values.length) {
			final sourceReference = Contract.stringValue(values[index], "Source Map source");
			final logicalPath = resolveLogical(mapPath, sourceReference);
			Contract.require(sourceIndex.filesByPath.exists(logicalPath), "Source Map source is not an indexed logical file: " + logicalPath);
			final record = sourceIndex.filesByPath.get(logicalPath);
			Contract.require(allowed.exists(record.id), "Source Map source is outside its admitted layer");
			Contract.require(!seen.exists(record.id), "Source Map resolves two sources to one indexed file", true);
			seen.set(record.id, true);
			sourceFileIds.push(record.id);
			sourceRecords.push(record);
			if (record.role == "source") {
				Contract.require(sourceIndex.sourceBindingsByFileId.exists(record.id), "Source Map source is not bound to a declared logical root");
				final binding = sourceIndex.sourceBinding(record.id);
				sourceBindings.push(binding);
				sourceContents.push(binding.content);
			} else {
				sourceBindings.push(null);
				sourceContents.push(sourceIndex.artifactContent(record.id, "Source Map generated source " + record.id));
			}
		}
		Contract.require([for (_ in seen.keys()) true].length == allowedSourceIds.length, "Source Map source binding is incomplete");
	}

	function validateSourcesContent(map:JsonValue, present:Bool):Void {
		if (!present) {
			return;
		}
		Contract.require(sourceIndex.retention.sourceContentPolicy == "allowlisted-debug-only",
			"Source Map embedded source content contradicts retention policy");
		final values = Contract.array(map, "sourcesContent", "Source Map v3");
		Contract.require(values.length == sourceRecords.length, "Source Map sourcesContent length differs from sources");
		for (index in 0...values.length) {
			switch values[index] {
				case NullValue:
				case StringValue(content):
					final record = sourceRecords[index];
					Contract.require(record.distribution == "debug-companion", "embedded source content is not allowlisted for the debug companion");
					SourceIndex.validateBoundFile(record, content, "Source Map embedded source " + record.id);
				case _:
					Contract.fail("Source Map embedded source content must be a string or null");
			}
		}
	}

	function decodeMappings(value:String):Void {
		var previousSource = 0;
		var previousOriginalLine = 0;
		var previousOriginalColumn = 0;
		var previousName = 0;
		var mappedCount = 0;
		final referencedSources:Map<Int, Bool> = [];
		for (lineValue in value.split(";")) {
			final decodedLine:Array<DecodedSegment> = [];
			var generatedColumn = 0;
			if (lineValue.length > 0) {
				for (segmentValue in lineValue.split(",")) {
					Contract.require(segmentValue.length > 0, "Source Map mappings contain an empty segment");
					final fields = decodeVlqSegment(segmentValue);
					Contract.require(fields.length == 1 || fields.length == 4 || fields.length == 5, "Source Map segment has an unsupported field count");
					Contract.require(fields[0] >= 0, "Source Map generated-column delta is negative");
					generatedColumn += fields[0];
					Contract.require(generatedColumn >= 0, "Source Map generated column overflowed");
					if (fields.length == 1) {
						decodedLine.push({
							generatedColumn: generatedColumn,
							sourceIndex: null,
							originalLine: null,
							originalColumn: null,
							nameIndex: null
						});
						continue;
					}
					previousSource += fields[1];
					previousOriginalLine += fields[2];
					previousOriginalColumn += fields[3];
					Contract.require(previousSource >= 0 && previousSource < sourceFileIds.length, "Source Map segment references an unknown source");
					Contract.require(previousOriginalLine >= 0 && previousOriginalColumn >= 0, "Source Map segment has a negative original position");
					var nameIndex:Null<Int> = null;
					if (fields.length == 5) {
						previousName += fields[4];
						Contract.require(previousName >= 0 && previousName < names.length, "Source Map segment references an unknown name");
						nameIndex = previousName;
					}
					decodedLine.push({
						generatedColumn: generatedColumn,
						sourceIndex: previousSource,
						originalLine: previousOriginalLine,
						originalColumn: previousOriginalColumn,
						nameIndex: nameIndex
					});
					mappedCount++;
					referencedSources.set(previousSource, true);
				}
			}
			lines.push(decodedLine);
		}
		Contract.require(mappedCount > 0, "Source Map contains no mapped segments");
		Contract.require([for (_ in referencedSources.keys()) true].length == sourceFileIds.length, "Source Map silently inventories an unreferenced source");
	}

	function decodeVlqSegment(value:String):Array<Int> {
		final result:Array<Int> = [];
		var offset = 0;
		while (offset < value.length) {
			var accumulated = 0.0;
			var shift = 0;
			var continued = true;
			while (continued) {
				Contract.require(offset < value.length, "Source Map VLQ value is unterminated");
				final digit = BASE64.indexOf(value.charAt(offset));
				Contract.require(digit >= 0, "Source Map VLQ contains a non-base64 character");
				offset++;
				continued = (digit & 32) != 0;
				accumulated += (digit & 31) * Math.pow(2, shift);
				shift += 5;
				Contract.require(shift <= 35 && accumulated <= 2147483647.0, "Source Map VLQ value exceeds the supported integer range");
			}
			final raw = Std.int(accumulated);
			final magnitude = raw >> 1;
			result.push((raw & 1) == 1 ? -magnitude : magnitude);
		}
		return result;
	}

	function validateMappedPosition(content:Null<String>, line:Int, column:Int):Void {
		if (content == null) {
			return;
		}
		final sourceLines = content.split("\n");
		if (sourceLines.length > 0 && sourceLines[sourceLines.length - 1] == "") {
			sourceLines.pop();
		}
		Contract.require(line > 0 && line <= sourceLines.length && column >= 0 && column <= sourceLines[line - 1].length,
			"Source Map position exceeds authenticated source content");
	}

	static function resolveLogical(mapPath:String, sourceReference:String):String {
		Contract.require(sourceReference.length > 0
			&& !StringTools.startsWith(sourceReference, "/")
			&& sourceReference.indexOf("\\") < 0
			&& sourceReference.indexOf(":") < 0
			&& !hasControl(sourceReference),
			"Source Map source is not a safe relative POSIX reference");
		final parts = mapPath.split("/");
		parts.pop();
		for (part in sourceReference.split("/")) {
			Contract.require(part.length > 0, "Source Map source contains an empty path segment");
			if (part == ".") {
				continue;
			}
			if (part == "..") {
				Contract.require(parts.length > 0, "Source Map source escapes the artifact namespace");
				parts.pop();
			} else {
				parts.push(part);
			}
		}
		return Content.safeRelativePath(parts.join("/"), "resolved Source Map source");
	}

	static function requireIndex(value:Null<Int>, message:String):Int {
		if (value == null) {
			return Contract.fail(message);
		}
		return value;
	}

	static function basename(value:String):String {
		final parts = value.split("/");
		return parts[parts.length - 1];
	}

	static function hasControl(value:String):Bool {
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code < 32 || code == 127) {
				return true;
			}
		}
		return false;
	}
}
