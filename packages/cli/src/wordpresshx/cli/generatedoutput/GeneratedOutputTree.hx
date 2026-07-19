package wordpresshx.cli.generatedoutput;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import js.node.fs.Stats;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.scaffold.ScaffoldJson;

@:native("Error")
private extern class GeneratedOutputFsError extends js.lib.Error {
	final code:String;
}

/** Link-free exact file snapshot and confined clone cleanup. */
class GeneratedOutputTree {
	public final files:Array<GeneratedOutputFile>;
	public final treeDigest:String;

	public static function scan(projectRoot:String, roots:Array<GeneratedOutputRoot>):GeneratedOutputTree {
		final files:Array<GeneratedOutputFile> = [];
		for (root in roots) {
			final absolute = confined(projectRoot, root.path);
			final stats = entryStats(absolute);
			if (stats == null || stats.isSymbolicLink() || !stats.isDirectory()) {
				fail("selected generated-output root is missing or is not a regular directory", root.path);
			}
			walk(projectRoot, absolute, root.path, files);
		}
		files.sort(compareFile);
		return new GeneratedOutputTree(files, digestFiles(files));
	}

	public static function compare(expected:GeneratedOutputTree, actual:GeneratedOutputTree):Void {
		if (expected.files.length != actual.files.length) {
			fail("fresh regeneration produced a different selected-root path count", GeneratedOutputPolicy.PATH);
		}
		for (index in 0...expected.files.length) {
			final left = expected.files[index];
			final right = actual.files[index];
			if (left.path != right.path) {
				fail("fresh regeneration produced a different selected-root path set", left.path);
			}
			if (left.sizeBytes != right.sizeBytes || left.sha256 != right.sha256 || Buffer.compareBuffers(left.bytes, right.bytes) != 0) {
				fail("fresh regeneration differs in size, digest, or bytes", left.path);
			}
		}
		if (expected.treeDigest != actual.treeDigest) {
			fail("fresh regeneration tree digest differs", GeneratedOutputPolicy.PATH);
		}
	}

	public function requireExactPaths(expected:Array<String>):Void {
		final actual = [for (file in files) file.path];
		expected.sort(compareText);
		if (actual.join("\n") != expected.join("\n")) {
			fail("selected generated roots contain missing, extra, or unowned files", GeneratedOutputPolicy.PATH);
		}
	}

	public function filesBelow(path:String):Array<GeneratedOutputFile> {
		return [
			for (file in files)
				if (file.path == path || StringTools.startsWith(file.path, path + "/")) file
		];
	}

	public static function removeSelectedRoots(projectRoot:String, roots:Array<GeneratedOutputRoot>):Void {
		for (root in roots) {
			final absolute = confined(projectRoot, root.path);
			final stats = entryStats(absolute);
			if (stats != null) {
				removeTree(absolute);
			}
		}
	}

	static function walk(projectRoot:String, absolute:String, relative:String, files:Array<GeneratedOutputFile>):Void {
		if (relative.indexOf("/.wphx-transactions") >= 0 || StringTools.endsWith(relative, "/.wphx-transactions")) {
			fail("ownership transaction state may not enter committed generated output", relative);
		}
		final names = Fs.readdirSync(absolute);
		names.sort(compareText);
		for (name in names) {
			final childRelative = relative + "/" + name;
			final childAbsolute = confined(projectRoot, childRelative);
			final stats = Fs.lstatSync(childAbsolute);
			if (stats.isSymbolicLink()) {
				fail("selected generated output contains a link", childRelative);
			}
			if (stats.isDirectory()) {
				walk(projectRoot, childAbsolute, childRelative, files);
			} else if (stats.isFile()) {
				final bytes = Fs.readFileSync(childAbsolute);
				files.push(new GeneratedOutputFile(childRelative, bytes.length, OwnershipJson.digest(bytes), bytes));
			} else {
				fail("selected generated output contains a special file", childRelative);
			}
		}
	}

	public static function digestFiles(files:Array<GeneratedOutputFile>):String {
		return CanonicalJson.digest(ScaffoldJson.array([
			for (file in files)
				ScaffoldJson.object([
					ScaffoldJson.field("path", ScaffoldJson.text(file.path)),
					ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256)),
					ScaffoldJson.field("sizeBytes", ScaffoldJson.number(file.sizeBytes))
				])
		]));
	}

	static function confined(projectRoot:String, relative:String):String {
		final absolute = Path.resolve(projectRoot, relative);
		final back = Path.relative(projectRoot, absolute).split(Path.sep).join("/");
		if (back.length == 0 || back == ".." || StringTools.startsWith(back, "../") || Path.isAbsolute(back)) {
			fail("generated-output path escaped the project", relative);
		}
		var current = projectRoot;
		final segments = relative.split("/");
		for (index in 0...segments.length) {
			current = Path.join(current, segments[index]);
			final stats = entryStats(current);
			if (stats == null) {
				break;
			}
			if (stats.isSymbolicLink() || (index < segments.length - 1 && !stats.isDirectory())) {
				fail("generated-output path crosses a link or non-directory", relative);
			}
		}
		return absolute;
	}

	static function removeTree(absolute:String):Void {
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(absolute);
			return;
		}
		if (!stats.isDirectory()) {
			throw new haxe.Exception("private regeneration clone contains a special file");
		}
		final names = Fs.readdirSync(absolute);
		names.sort(compareText);
		for (name in names) {
			removeTree(Path.join(absolute, name));
		}
		Fs.rmdirSync(absolute);
	}

	static function entryStats(absolute:String):Null<Stats> {
		try {
			return Fs.lstatSync(absolute);
		} catch (failure:GeneratedOutputFsError) {
			if (failure.code == "ENOENT") {
				return null;
			}
			throw failure;
		}
	}

	static function compareFile(left:GeneratedOutputFile, right:GeneratedOutputFile):Int {
		return compareText(left.path, right.path);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function fail<T>(message:String, relative:String):T {
		throw new CliFailure("WPHX3414", message, 5, "generated-output-compare", relative, [
			"Change Haxe, the generator, or exact locks and regenerate; do not patch committed generated bytes."
		]);
	}

	function new(files:Array<GeneratedOutputFile>, treeDigest:String) {
		this.files = files;
		this.treeDigest = treeDigest;
	}
}
