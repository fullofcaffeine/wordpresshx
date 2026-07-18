package wordpresshx.cli;

import js.node.Fs;
import js.node.Path;

/** Haxe-authored WordPressHx SDK CLI entry point, emitted as ESM by Genes. **/
class Main {
	static function main():Void {
		final nodeProcess = NodeGlobals.process();
		try {
			run(nodeProcess.argv.slice(2));
		} catch (failure:TraceFailure) {
			nodeProcess.stderr.write("wphx-sdk: " + failure.message + "\n");
			nodeProcess.exit(failure.exitCode);
		} catch (failure:Dynamic) {
			nodeProcess.stderr.write("wphx-sdk: unexpected trace failure: " + Std.string(failure) + "\n");
			nodeProcess.exit(3);
		}
	}

	static function run(arguments:Array<String>):Void {
		if (arguments.length < 2 || arguments[0] != "trace") {
			usage();
		}
		if (arguments[1] == "browser") {
			throw new TraceFailure("browser trace correlation is owned by SDK-034 and is not available in this build", 2);
		}
		if (arguments[1] != "php" || arguments.length < 3) {
			usage();
		}
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
			throw new TraceFailure("trace php requires --index <source-index>", 2);
		}
		final stack:String = cast Fs.readFileSync(stackPath, "utf8");
		if (StringTools.trim(stack).length == 0) {
			throw new TraceFailure("stack file is empty", 2);
		}
		final resolvedIndex = existingFile(indexPath, "source index");
		final result = new PhpTraceEngine(resolvedIndex, sourceRoots).trace(stack);
		NodeGlobals.process().stdout.write(outputFormat == "json" ? CanonicalJson.encode(result) + "\n" : PhpTraceEngine.text(result));
	}

	static function existingFile(path:String, label:String):String {
		final resolved = Path.resolve(path);
		if (!Fs.existsSync(resolved) || !Fs.statSync(resolved).isFile()) {
			throw new TraceFailure(label + " does not exist: " + path, 2);
		}
		return resolved;
	}

	static function usage():Dynamic {
		throw new TraceFailure("usage: wphx-sdk trace php <stack-file> --index <source-index> [--source-root <id>=<path>] [--format text|json]", 2);
	}
}
