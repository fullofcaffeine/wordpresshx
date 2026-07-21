package wordpresshx.cli.project;

import js.node.Fs;
import js.node.Path;
import js.node.fs.FSWatcher;
import js.node.fs.FSWatcher.FSWatcherEvent;
import js.node.fs.Stats;
import wordpresshx.cli.closedjson.JsonValue;

private typedef WatchRule = {
	final path:String;
	final includes:Array<String>;
	final recursive:Bool;
}

/** Non-recursive portable subscriptions derived from the authenticated effective graph. **/
class WatchGraph {
	final root:String;
	final onChange:String->Void;
	final onProblem:String->Void;
	final watchers:Map<String, FSWatcher> = [];
	final pollers:Map<String, Stats->Stats->Void> = [];
	var rules:Array<WatchRule> = [];
	var restartFiles:Array<String> = [];
	var ignored:Array<String> = [];
	var closed = false;

	public function new(root:String, onChange:String->Void, onProblem:String->Void) {
		this.root = root;
		this.onChange = onChange;
		this.onProblem = onProblem;
	}

	public function refresh(context:ProjectContext):Void {
		if (closed) {
			return;
		}
		rules = readRules(context.effectiveInputs);
		restartFiles = readRestartFiles(context.effectiveInputs);
		ignored = strings(context.effectiveInputs, "ignoredRoots", "effective inputs");
		ignored.sort(ProjectJson.compareText);
		final desired = desiredSubscriptions();
		final removals:Array<String> = [];
		for (absolute => _ in watchers) {
			if (!desired.exists(absolute)) {
				removals.push(absolute);
			}
		}
		removals.sort(ProjectJson.compareText);
		for (absolute in removals) {
			final watcher = watchers.get(absolute);
			if (watcher != null) {
				watcher.close();
			}
			watchers.remove(absolute);
		}

		final additions:Array<String> = [];
		for (absolute => _ in desired) {
			if (!watchers.exists(absolute)) {
				additions.push(absolute);
			}
		}
		additions.sort(ProjectJson.compareText);
		for (absolute in additions) {
			addWatcher(absolute);
		}
		refreshPollers();
	}

	public function close():Void {
		if (closed) {
			return;
		}
		closed = true;
		final paths = [for (absolute in watchers.keys()) absolute];
		paths.sort(ProjectJson.compareText);
		for (absolute in paths) {
			final watcher = watchers.get(absolute);
			if (watcher != null) {
				watcher.close();
			}
		}
		watchers.clear();
		final polledPaths = [for (absolute in pollers.keys()) absolute];
		polledPaths.sort(ProjectJson.compareText);
		for (absolute in polledPaths) {
			final listener = pollers.get(absolute);
			if (listener != null) {
				Fs.unwatchFile(absolute, listener);
			}
		}
		pollers.clear();
	}

	function refreshPollers():Void {
		final desired:Map<String, String> = [];
		for (relative in restartFiles) {
			final absolute = Path.resolve(root, relative);
			try {
				final stats = Fs.lstatSync(absolute);
				if (!stats.isSymbolicLink() && stats.isFile()) {
					desired.set(absolute, relative);
				}
			} catch (_:haxe.Exception) {}
		}
		final removals:Array<String> = [];
		for (absolute => _ in pollers) {
			if (!desired.exists(absolute)) {
				removals.push(absolute);
			}
		}
		for (absolute in removals) {
			final listener = pollers.get(absolute);
			if (listener != null) {
				Fs.unwatchFile(absolute, listener);
			}
			pollers.remove(absolute);
		}
		for (absolute => relative in desired) {
			if (pollers.exists(absolute)) {
				continue;
			}
			final listener = (current:Stats, previous:Stats) -> {
				final contentIdentityChanged = current.size != previous.size
					|| current.mtime.getTime() != previous.mtime.getTime()
					|| current.ctime.getTime() != previous.ctime.getTime()
					|| current.ino != previous.ino;
				if (!closed && contentIdentityChanged && !isIgnored(relative)) {
					onChange(relative);
				}
			};
			Fs.watchFile(absolute, {persistent: true, interval: 200}, listener);
			pollers.set(absolute, listener);
		}
	}

	function addWatcher(absolute:String):Void {
		try {
			final stats = Fs.lstatSync(absolute);
			if (stats.isSymbolicLink() || (!stats.isDirectory() && !stats.isFile())) {
				return;
			}
			final exactFile = stats.isFile() ? Path.relative(root, absolute).split("\\").join("/") : null;
			final watcher = Fs.watch(absolute, {persistent: true, recursive: false}, (event, filename) -> {
				if (closed) {
					return;
				}
				final candidate = exactFile == null ? changedPath(absolute, filename) : exactFile;
				if (candidate != null && isRelevant(candidate)) {
					onChange(candidate);
				}
			});
			watcher.on(FSWatcherEvent.Error, error -> {
				watcher.close();
				watchers.remove(absolute);
				onProblem(error.message);
			});
			watchers.set(absolute, watcher);
		} catch (failure:haxe.Exception) {
			onProblem("could not subscribe to an effective-input directory");
		}
	}

	function changedPath(directory:String, filename:String):Null<String> {
		if (filename == null || filename.length == 0) {
			return "wordpress-hx.json";
		}
		final absolute = Path.resolve(directory, filename);
		var relative = Path.relative(root, absolute).split("\\").join("/");
		if (relative.length == 0 || relative == "." || StringTools.startsWith(relative, "../") || relative == "..") {
			return "wordpress-hx.json";
		}
		try {
			return ProjectContract.relativePath(relative, "watch event path");
		} catch (_:haxe.Exception) {
			return null;
		}
	}

	function isRelevant(candidate:String):Bool {
		if (isIgnored(candidate)) {
			return false;
		}
		if (restartFiles.indexOf(candidate) != -1) {
			return true;
		}
		for (rule in rules) {
			if (rule.recursive) {
				if (rule.path == "."
					|| candidate == rule.path
					|| ProjectContract.nested(rule.path, candidate)
					|| ProjectContract.nested(candidate, rule.path)) {
					return true;
				}
				continue;
			}
			for (include in rule.includes) {
				final exact = rule.path == "." ? include : rule.path + "/" + include;
				if (candidate == exact || ProjectContract.nested(candidate, exact)) {
					return true;
				}
			}
		}
		return false;
	}

	function desiredSubscriptions():Map<String, Bool> {
		final result:Map<String, Bool> = [];
		for (relative in restartFiles) {
			addExistingFile(relative, result);
			addNearestDirectory(Path.dirname(relative).split("\\").join("/"), result);
		}
		for (rule in rules) {
			if (rule.recursive) {
				collectDirectories(rule.path, result);
			} else {
				addNearestDirectory(rule.path, result);
				for (include in rule.includes) {
					final parent = Path.dirname(include).split("\\").join("/");
					final exact = rule.path == "." ? include : rule.path + "/" + include;
					addExistingFile(exact, result);
					if (parent != ".") {
						addNearestDirectory(rule.path == "." ? parent : rule.path + "/" + parent, result);
					}
				}
			}
		}
		return result;
	}

	function addExistingFile(relative:String, result:Map<String, Bool>):Void {
		final absolute = Path.resolve(root, relative);
		try {
			final stats = Fs.lstatSync(absolute);
			if (!stats.isSymbolicLink() && stats.isFile()) {
				result.set(absolute, true);
			}
		} catch (_:haxe.Exception) {}
	}

	function collectDirectories(relative:String, result:Map<String, Bool>):Void {
		if (relative != "." && isIgnored(relative)) {
			return;
		}
		final absolute = relative == "." ? root : Path.resolve(root, relative);
		if (!Fs.existsSync(absolute)) {
			addNearestDirectory(relative, result);
			return;
		}
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			addNearestDirectory(Path.dirname(relative).split("\\").join("/"), result);
			return;
		}
		result.set(absolute, true);
		final names = Fs.readdirSync(absolute);
		names.sort(ProjectJson.compareText);
		for (name in names) {
			final childRelative = relative == "." ? name : relative + "/" + name;
			if (isIgnored(childRelative)) {
				continue;
			}
			final childAbsolute = Path.resolve(root, childRelative);
			try {
				final childStats = Fs.lstatSync(childAbsolute);
				if (!childStats.isSymbolicLink() && childStats.isDirectory()) {
					collectDirectories(childRelative, result);
				}
			} catch (_:haxe.Exception) {}
		}
	}

	function addNearestDirectory(relative:String, result:Map<String, Bool>):Void {
		var candidate = relative == "." ? root : Path.resolve(root, relative);
		while (candidate != root && !Fs.existsSync(candidate)) {
			candidate = Path.dirname(candidate);
		}
		if (!StringTools.startsWith(candidate + Path.sep, root + Path.sep) && candidate != root) {
			return;
		}
		try {
			final stats = Fs.lstatSync(candidate);
			if (!stats.isSymbolicLink() && stats.isDirectory()) {
				result.set(candidate, true);
			}
		} catch (_:haxe.Exception) {}
	}

	function isIgnored(relative:String):Bool {
		for (candidate in ignored) {
			if (relative == candidate || ProjectContract.nested(candidate, relative)) {
				return true;
			}
		}
		return false;
	}

	static function readRules(effectiveInputs:JsonValue):Array<WatchRule> {
		final result:Array<WatchRule> = [];
		for (value in ProjectContract.array(effectiveInputs, "discoveryRoots", "effective inputs")) {
			final path = ProjectContract.string(value, "path", "discovery root");
			final includes = strings(value, "includes", "discovery root");
			var recursive = false;
			for (include in includes) {
				if (StringTools.startsWith(include, "**/")) {
					recursive = true;
				}
			}
			result.push({path: path, includes: includes, recursive: recursive});
		}
		result.sort((left, right) -> ProjectJson.compareText(left.path, right.path));
		return result;
	}

	static function readRestartFiles(effectiveInputs:JsonValue):Array<String> {
		final compileServer = ProjectContract.fieldObject(effectiveInputs, "compileServer", "effective inputs");
		final roles = strings(compileServer, "restartFileRoles", "effective inputs.compileServer");
		final result:Array<String> = [];
		for (value in ProjectContract.array(effectiveInputs, "files", "effective inputs")) {
			final role = ProjectContract.string(value, "role", "effective input file");
			if (roles.indexOf(role) != -1) {
				result.push(ProjectContract.string(value, "path", "effective input file"));
			}
		}
		result.sort(ProjectJson.compareText);
		return result;
	}

	static function strings(value:JsonValue, name:String, label:String):Array<String> {
		return ProjectContract.sortedUniqueStrings(ProjectContract.array(value, name, label), label + "." + name, (item, _) -> item);
	}
}
