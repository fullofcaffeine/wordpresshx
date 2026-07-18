package wordpresshx.cli;

import js.Syntax;

private typedef ParsedBrowserFrame = {
	final raw:String;
	final url:String;
	final path:String;
	final line:Int;
	final column:Int;
}

private typedef BrowserEntry = {
	final correlation:Dynamic;
	final runtime:Dynamic;
	final runtimeContent:String;
	final first:SourceMapV3;
	final second:Null<SourceMapV3>;
}

/** Offline, read-only browser-stack correlator for authenticated Source Map v3 layers. **/
class BrowserTraceEngine {
	static final URL_POSITION = ~/^(https?:\/\/.*):([0-9]+):([0-9]+)$/;

	final sourceIndex:SourceIndex;
	final entriesByPath:Map<String, BrowserEntry> = [];

	public function new(indexPath:String, sourceRootArguments:Map<String, String>) {
		sourceIndex = new SourceIndex(indexPath, sourceRootArguments);
		for (correlation in sourceIndex.correlations) {
			if (correlation.target != "browser" || correlation.strategy == "unavailable") {
				continue;
			}
			final runtime = sourceIndex.file(correlation.entryFileId);
			Contract.require(!entriesByPath.exists(runtime.path), "multiple browser correlations resolve to one runtime path", true);
			final layers:Array<Dynamic> = cast correlation.layers;
			entriesByPath.set(runtime.path, {
				correlation: correlation,
				runtime: runtime,
				runtimeContent: sourceIndex.artifactContent(runtime.id, "browser runtime entry " + runtime.id),
				first: new SourceMapV3(sourceIndex, layers[0]),
				second: layers.length == 2 ? new SourceMapV3(sourceIndex, layers[1]) : null
			});
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
			final parsed = parseFrame(line);
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
			command: "trace browser",
			packageIdentity: sourceIndex.packageIdentity,
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
					annotation += " " + source.rootId + ":" + source.path + ":" + source.line + ":" + source.column + " correlation="
						+ correlated.correlationId;
				}
				lines.push(annotation);
			}
		}
		return lines.join("\n") + "\n";
	}

	function correlate(frame:ParsedBrowserFrame):Dynamic {
		if (!entriesByPath.exists(frame.path)) {
			return parsedResult(frame, "unmapped-no-layer");
		}
		final entry = entriesByPath.get(frame.path);
		validateRuntimePosition(entry.runtimeContent, frame.line, frame.column);
		final first = entry.first.lookup(frame.line, frame.column - 1);
		if (first == null) {
			return parsedResult(frame, "unmapped-no-layer");
		}
		final layers:Array<Dynamic> = [
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
		final identity:Dynamic = source.record.sourceIdentity;
		final result = parsedResult(frame, status);
		Reflect.setField(result, "correlated", {
			correlationId: entry.correlation.id,
			source: {
				rootId: identity.rootId,
				path: identity.path,
				line: point.line,
				column: point.column
			},
			layers: layers
		});
		return result;
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
		if (path == null) {
			return null;
		}
		return {
			raw: raw,
			url: url,
			path: path,
			line: line,
			column: column
		};
	}

	function logicalUrlPath(value:String):Null<String> {
		try {
			final parsed:Dynamic = Syntax.code("new URL({0})", value);
			if ((parsed.protocol != "http:" && parsed.protocol != "https:") || parsed.username != "" || parsed.password != "") {
				return null;
			}
			final decoded:String = cast Syntax.code("decodeURIComponent({0})", parsed.pathname);
			if (!StringTools.startsWith(decoded, "/") || StringTools.startsWith(decoded, "//")) {
				return null;
			}
			return Content.safeRelativePath(decoded.substr(1), "browser frame URL path");
		} catch (_:Dynamic) {
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

	function nativeOnly(raw:String):Dynamic {
		return {native: raw, status: "native-unmapped"};
	}

	function parsedResult(frame:ParsedBrowserFrame, status:String):Dynamic {
		return {
			native: frame.raw,
			status: status,
			frame: {
				url: frame.url,
				path: frame.path,
				line: frame.line,
				column: frame.column
			}
		};
	}
}
