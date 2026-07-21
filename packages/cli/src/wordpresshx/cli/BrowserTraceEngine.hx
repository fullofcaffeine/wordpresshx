package wordpresshx.cli;

import js.Syntax;
import wordpresshx.cli.SourceIndex.AvailableSourceCorrelation;
import wordpresshx.cli.SourceIndex.SourceFileRecord;
import wordpresshx.cli.SourceIndex.SourcePackageIdentity;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

private extern class NodeUrl {
	public function new(value:String);
	public final protocol:String;
	public final username:String;
	public final password:String;
	public final pathname:String;
}

private typedef ParsedBrowserFrame = {
	final raw:String;
	final url:String;
	final path:String;
	final line:Int;
	final column:Int;
}

private typedef BrowserEntry = {
	final correlation:AvailableSourceCorrelation;
	final runtime:SourceFileRecord;
	final runtimeContent:String;
	final first:SourceMapV3;
	final second:Null<SourceMapV3>;
}

typedef BrowserRuntimeFrame = {
	final url:String;
	final path:String;
	final line:Int;
	final column:Int;
}

typedef BrowserLayerPoint = {
	final mapFileId:String;
	final generatedFileId:String;
	final sourceFileId:String;
	final line:Int;
	final column:Int;
}

typedef BrowserCorrelatedSource = {
	final rootId:String;
	final path:String;
	final line:Int;
	final column:Int;
}

typedef BrowserCorrelatedFrame = {
	final correlationId:String;
	final source:BrowserCorrelatedSource;
	final layers:Array<BrowserLayerPoint>;
}

typedef BrowserTraceFrame = {
	final native:String;
	final status:String;
	final frame:Null<BrowserRuntimeFrame>;
	final correlated:Null<BrowserCorrelatedFrame>;
}

typedef BrowserSummaryEntry = {
	final status:String;
	final count:Int;
}

typedef BrowserTraceResult = {
	final schemaVersion:Int;
	final command:String;
	final packageIdentity:SourcePackageIdentity;
	final frames:Array<BrowserTraceFrame>;
	final summary:Array<BrowserSummaryEntry>;
}

/** Offline, read-only browser-stack correlator for authenticated Source Map v3 layers. */
class BrowserTraceEngine {
	static final URL_POSITION = ~/^(https?:\/\/.*):([0-9]+):([0-9]+)$/;

	final sourceIndex:SourceIndex;
	final entriesByPath:Map<String, BrowserEntry> = [];

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		sourceIndex = new SourceIndex(indexPath, sourceRootArguments);
		for (correlation in sourceIndex.correlations) {
			switch correlation {
				case AvailableCorrelation(value) if (value.target == "browser"):
					final runtime = sourceIndex.file(value.entryFileId);
					Contract.require(!entriesByPath.exists(runtime.path), "multiple browser correlations resolve to one runtime path", true);
					entriesByPath.set(runtime.path, {
						correlation: value,
						runtime: runtime,
						runtimeContent: sourceIndex.artifactContent(runtime.id, "browser runtime entry " + runtime.id),
						first: new SourceMapV3(sourceIndex, value.layers[0]),
						second: value.layers.length == 2 ? new SourceMapV3(sourceIndex, value.layers[1]) : null
					});
				case _:
			}
		}
	}

	public function trace(stack:String):BrowserTraceResult {
		final nativeLines = stack.split("\n");
		if (nativeLines.length > 0 && nativeLines[nativeLines.length - 1] == "") {
			nativeLines.pop();
		}
		final frames:Array<BrowserTraceFrame> = [];
		final counts:Map<String, Int> = [];
		for (line in nativeLines) {
			final parsed = parseFrame(line);
			final frame = parsed == null ? nativeOnly(line) : correlate(parsed);
			frames.push(frame);
			counts.set(frame.status, (counts.exists(frame.status) ? counts.get(frame.status) : 0) + 1);
		}
		final statuses = [for (status in counts.keys()) status];
		statuses.sort(Content.compareText);
		return {
			schemaVersion: 1,
			command: "trace browser",
			packageIdentity: sourceIndex.packageIdentity,
			frames: frames,
			summary: [for (status in statuses) {status: status, count: counts.get(status)}]
		};
	}

	public static function text(result:BrowserTraceResult):String {
		final lines:Array<String> = [];
		for (frame in result.frames) {
			lines.push(frame.native);
			if (frame.frame != null) {
				var annotation = "  => " + frame.status;
				if (frame.correlated != null) {
					final correlated = frame.correlated;
					final source = correlated.source;
					annotation += " " + source.rootId + ":" + source.path + ":" + source.line + ":" + source.column + " correlation="
						+ correlated.correlationId;
				}
				lines.push(annotation);
			}
		}
		return lines.join("\n") + "\n";
	}

	public static function json(result:BrowserTraceResult):JsonValue {
		return object([
			field("schemaVersion", number(result.schemaVersion)),
			field("command", textValue(result.command)),
			field("packageIdentity", packageJson(result.packageIdentity)),
			field("frames", ArrayValue(result.frames.map(frameJson))),
			field("summary", ObjectValue([for (entry in result.summary) field(entry.status, number(entry.count))]))
		]);
	}

	function correlate(frame:ParsedBrowserFrame):BrowserTraceFrame {
		if (!entriesByPath.exists(frame.path)) {
			return parsedResult(frame, "unmapped-no-layer");
		}
		final entry = entriesByPath.get(frame.path);
		validateRuntimePosition(entry.runtimeContent, frame.line, frame.column);
		final first = entry.first.lookup(frame.line, frame.column - 1);
		if (first == null) {
			return parsedResult(frame, "unmapped-no-layer");
		}
		final layers:Array<BrowserLayerPoint> = [
			{
				mapFileId: entry.first.mapFileId,
				generatedFileId: entry.first.generatedFileId,
				sourceFileId: first.sourceFileId,
				line: first.line,
				column: first.column
			}
		];
		var point = first;
		var status = "mapped-composed";
		if (entry.second != null) {
			if (first.sourceFileId != entry.second.generatedFileId) {
				return parsedResult(frame, "unmapped-no-layer");
			}
			final second = entry.second.lookup(first.line, first.column);
			if (second == null) {
				return parsedResult(frame, "unmapped-no-layer");
			}
			layers.push({
				mapFileId: entry.second.mapFileId,
				generatedFileId: entry.second.generatedFileId,
				sourceFileId: second.sourceFileId,
				line: second.line,
				column: second.column
			});
			point = second;
			status = "mapped-two-stage";
		}
		final source = sourceIndex.sourceBinding(point.sourceFileId);
		final identity = source.record.sourceIdentity;
		Contract.require(identity != null, "mapped browser source lost its source identity");
		return {
			native: frame.raw,
			status: status,
			frame: {
				url: frame.url,
				path: frame.path,
				line: frame.line,
				column: frame.column
			},
			correlated: {
				correlationId: entry.correlation.id,
				source: {
					rootId: identity.rootId,
					path: identity.path,
					line: point.line,
					column: point.column
				},
				layers: layers
			}
		};
	}

	function parseFrame(raw:String):Null<ParsedBrowserFrame> {
		final trimmed = StringTools.trim(raw);
		if (!StringTools.startsWith(trimmed, "at ")) {
			return null;
		}
		var location = trimmed.substr(3);
		if (StringTools.endsWith(location, ")")) {
			final open = location.lastIndexOf("(");
			if (open < 0) {
				return null;
			}
			location = location.substr(open + 1, location.length - open - 2);
		}
		if (!URL_POSITION.match(location)) {
			return null;
		}
		final line = Std.parseInt(URL_POSITION.matched(2));
		final column = Std.parseInt(URL_POSITION.matched(3));
		if (line == null || column == null || line <= 0 || column <= 0) {
			return null;
		}
		final url = URL_POSITION.matched(1);
		final path = logicalUrlPath(url);
		return path == null ? null : {
			raw: raw,
			url: url,
			path: path,
			line: line,
			column: column
		};
	}

	function logicalUrlPath(value:String):Null<String> {
		try {
			final parsed:NodeUrl = Syntax.code("new URL({0})", value);
			if ((parsed.protocol != "http:" && parsed.protocol != "https:") || parsed.username != "" || parsed.password != "") {
				return null;
			}
			final decoded:String = Syntax.code("decodeURIComponent({0})", parsed.pathname);
			if (!StringTools.startsWith(decoded, "/") || StringTools.startsWith(decoded, "//")) {
				return null;
			}
			return Content.safeRelativePath(decoded.substr(1), "browser frame URL path");
		} catch (_:haxe.Exception) {
			return null;
		}
	}

	function validateRuntimePosition(content:String, line:Int, column:Int):Void {
		final runtimeLines = content.split("\n");
		if (runtimeLines.length > 0 && runtimeLines[runtimeLines.length - 1] == "") {
			runtimeLines.pop();
		}
		if (line <= 0 || line > runtimeLines.length || column <= 0 || column > runtimeLines[line - 1].length + 1) {
			throw new TraceFailure("browser frame position exceeds authenticated generated content", 2);
		}
	}

	function nativeOnly(raw:String):BrowserTraceFrame {
		return {
			native: raw,
			status: "native-unmapped",
			frame: null,
			correlated: null
		};
	}

	function parsedResult(frame:ParsedBrowserFrame, status:String):BrowserTraceFrame {
		return {
			native: frame.raw,
			status: status,
			frame: {
				url: frame.url,
				path: frame.path,
				line: frame.line,
				column: frame.column
			},
			correlated: null
		};
	}

	static function frameJson(frame:BrowserTraceFrame):JsonValue {
		final fields:Array<JsonField> = [
			field("native", textValue(frame.native)),
			field("status", textValue(frame.status))
		];
		if (frame.frame != null) {
			fields.push(field("frame", object([
				field("url", textValue(frame.frame.url)),
				field("path", textValue(frame.frame.path)),
				field("line", number(frame.frame.line)),
				field("column", number(frame.frame.column))
			])));
		}
		if (frame.correlated != null) {
			final correlated = frame.correlated;
			fields.push(field("correlated", object([
				field("correlationId", textValue(correlated.correlationId)),
				field("source", object([
					field("rootId", textValue(correlated.source.rootId)),
					field("path", textValue(correlated.source.path)),
					field("line", number(correlated.source.line)),
					field("column", number(correlated.source.column))
				])),
				field("layers", ArrayValue(correlated.layers.map(layerJson)))
			])));
		}
		return object(fields);
	}

	static function layerJson(value:BrowserLayerPoint):JsonValue {
		return object([
			field("mapFileId", textValue(value.mapFileId)),
			field("generatedFileId", textValue(value.generatedFileId)),
			field("sourceFileId", textValue(value.sourceFileId)),
			field("line", number(value.line)),
			field("column", number(value.column))
		]);
	}

	static function packageJson(value:SourcePackageIdentity):JsonValue {
		return object([
			field("id", textValue(value.id)),
			field("version", textValue(value.version)),
			field("profileId", textValue(value.profileId))
		]);
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
