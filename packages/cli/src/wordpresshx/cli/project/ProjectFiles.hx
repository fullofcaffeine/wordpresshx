package wordpresshx.cli.project;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;

/** Link-free, regular-file-only access to project-relative authority. **/
class ProjectFiles {
	public static function read(root:String, relative:String, label:String, stage:String = "configuration"):Buffer {
		final absolute = safeAbsolute(root, relative, label, stage);
		final stats = lstat(absolute, label, relative, stage);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			fail(label + " must be a regular non-link file", relative, stage);
		}
		return Fs.readFileSync(absolute);
	}

	public static function requireDirectory(root:String, relative:String, label:String, stage:String = "configuration"):String {
		final absolute = safeAbsolute(root, relative, label, stage);
		final stats = lstat(absolute, label, relative, stage);
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			fail(label + " must be a directory and may not be a link", relative, stage);
		}
		return absolute;
	}

	public static function discover(root:String, relativeRoot:String, extensions:Null<Array<String>>, roleLabel:String):Array<String> {
		final absoluteRoot = requireDirectory(root, relativeRoot, roleLabel);
		final result:Array<String> = [];
		walk(root, absoluteRoot, relativeRoot, extensions, result);
		result.sort(ProjectJson.compareText);
		return result;
	}

	public static function existsRegular(root:String, relative:String):Bool {
		try {
			final absolute = safeAbsolute(root, relative, "project file", "configuration");
			final stats = Fs.lstatSync(absolute);
			return stats.isFile() && !stats.isSymbolicLink();
		} catch (_:haxe.Exception) {
			return false;
		}
	}

	public static function exists(root:String, relative:String):Bool {
		return Fs.existsSync(Path.resolve(root, relative));
	}

	static function walk(root:String, absolute:String, relative:String, extensions:Null<Array<String>>, result:Array<String>):Void {
		final names = Fs.readdirSync(absolute);
		names.sort(ProjectJson.compareText);
		for (name in names) {
			final childRelative = relative + "/" + name;
			ProjectContract.relativePath(childRelative, "discovered input");
			final childAbsolute = Path.resolve(root, childRelative);
			final stats = lstat(childAbsolute, "discovered input", childRelative, "configuration");
			if (stats.isSymbolicLink()) {
				fail("symlink effective input is forbidden", childRelative, "configuration");
			}
			if (stats.isDirectory()) {
				walk(root, childAbsolute, childRelative, extensions, result);
			} else if (stats.isFile()) {
				if (extensions == null || extensions.indexOf(Path.extname(name)) >= 0) {
					result.push(childRelative);
				}
			} else {
				fail("special effective input is forbidden", childRelative, "configuration");
			}
		}
	}

	static function safeAbsolute(root:String, relative:String, label:String, stage:String):String {
		ProjectContract.relativePath(relative, label);
		var current = root;
		final segments = relative.split("/");
		for (index in 0...(segments.length - 1)) {
			current = Path.join(current, segments[index]);
			if (!Fs.existsSync(current)) {
				throw new CliFailure("WPHX1007", label + " is missing", 3, stage, relative,
					["Restore the generated bootstrap or rerun the explicit lock/scaffold command."]);
			}
			final stats = Fs.lstatSync(current);
			if (stats.isSymbolicLink() || !stats.isDirectory()) {
				fail(label + " crosses a non-directory or symbolic link", relative, stage);
			}
		}
		return Path.resolve(root, relative);
	}

	static function lstat(absolute:String, label:String, relative:String, stage:String):js.node.fs.Stats {
		try {
			return Fs.lstatSync(absolute);
		} catch (_:haxe.Exception) {
			throw new CliFailure("WPHX1007", label + " is missing", 3, stage, relative, ["Restore the file or rerun the explicit lock/scaffold command."]);
		}
	}

	static function fail<T>(message:String, relative:String, stage:String):T {
		throw new CliFailure("WPHX1008", message + ": " + relative, 3, stage, relative,
			["Replace links or special files with regular project-local files and retry."]);
	}
}
