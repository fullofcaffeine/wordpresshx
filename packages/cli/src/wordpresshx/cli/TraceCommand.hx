package wordpresshx.cli;

import js.node.Fs;
import js.node.Path;

/** Preserved SDK-025/034 trace surface behind the final wphx dispatcher. **/
class TraceCommand {
	public static function run(arguments:Array<String>, executable:String = "wphx"):Void {
		if (arguments.length < 3 || arguments[0] != "trace" || (arguments[1] != "php" && arguments[1] != "browser")) {
			usage(executable);
		}
		final target = arguments[1];
		final stackPath = existingFile(arguments[2], "stack file");
		var indexPath:Null<String> = null;
		var outputFormat = "text";
		final sourceRoots:Map<String, String> = [];
		var index = 3;
		while (index < arguments.length) {
			final option = arguments[index];
			if (index + 1 >= arguments.length) {
				throw new TraceFailure("missing value for " + option, 2);
			}
			final value = arguments[index + 1];
			switch (option) {
				case "--index":
					if (indexPath != null) {
						throw new TraceFailure("--index may be supplied only once", 2);
					}
					indexPath = value;
				case "--format":
					if (value != "text" && value != "json") {
						throw new TraceFailure("--format must be text or json", 2);
					}
					outputFormat = value;
				case "--source-root":
					final separator = value.indexOf("=");
					if (separator <= 0 || separator == value.length - 1) {
						throw new TraceFailure("--source-root must use <id>=<path>", 2);
					}
					final id = value.substr(0, separator);
					try {
						Content.stableId(id, "source-root argument ID");
					} catch (failure:TraceFailure) {
						throw new TraceFailure(failure.message, 2);
					}
					if (sourceRoots.exists(id)) {
						throw new TraceFailure("duplicate --source-root ID: " + id, 2);
					}
					final root = Path.resolve(value.substr(separator + 1));
					if (!Fs.existsSync(root) || !Fs.statSync(root).isDirectory()) {
						throw new TraceFailure("source root is not a directory: " + value.substr(separator + 1), 2);
					}
					sourceRoots.set(id, root);
				case _:
					throw new TraceFailure("unknown trace option: " + option, 2);
			}
			index += 2;
		}
		if (indexPath == null) {
			throw new TraceFailure("trace " + target + " requires --index <source-index>", 2);
		}
		final stack = Fs.readFileSync(stackPath).toString("utf8");
		if (StringTools.trim(stack).length == 0) {
			throw new TraceFailure("stack file is empty", 2);
		}
		final resolvedIndex = existingFile(indexPath, "source index");
		if (target == "php") {
			final result = new PhpTraceEngine(resolvedIndex, sourceRoots).trace(stack);
			NodeGlobals.process()
				.stdout.write(outputFormat == "json" ? CanonicalJson.encode(PhpTraceEngine.json(result)) + "\n" : PhpTraceEngine.text(result));
			return;
		}
		final result = new BrowserTraceEngine(resolvedIndex, sourceRoots).trace(stack);
		NodeGlobals.process()
			.stdout.write(outputFormat == "json" ? CanonicalJson.encode(BrowserTraceEngine.json(result)) + "\n" : BrowserTraceEngine.text(result));
	}

	static function existingFile(path:String, label:String):String {
		final resolved = Path.resolve(path);
		if (!Fs.existsSync(resolved) || !Fs.statSync(resolved).isFile()) {
			throw new TraceFailure(label + " does not exist: " + path, 2);
		}
		return resolved;
	}

	static function usage<T>(executable:String):T {
		throw new TraceFailure("usage: "
			+ executable
			+ " trace <php|browser> <stack-file> --index <source-index> [--source-root <id>=<path>] [--format text|json]", 2);
	}
}
