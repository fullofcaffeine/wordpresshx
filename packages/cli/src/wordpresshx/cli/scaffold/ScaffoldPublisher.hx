package wordpresshx.cli.scaffold;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import js.node.fs.Stats;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldFileAction;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldMode;

@:native("Error")
private extern class ScaffoldFsError extends js.lib.Error {
	final code:String;
}

private enum ScaffoldCommit {
	Created(file:ScaffoldFile);
	Updated(file:ScaffoldFile, backupPath:String);
}

/** Same-filesystem staging and exact rollback for scaffold publication. */
class ScaffoldPublisher {
	static inline final PRIVATE_DIRECTORY_MODE = 448;
	static inline final PROJECT_DIRECTORY_MODE = 493;

	public static function preflight(plan:ScaffoldPlan):Void {
		validateProjectRoot(plan);
		switch plan.mode {
			case NewProject:
				if (entryStats(plan.targetRoot) != null) {
					collision(null, "new site target already exists");
				}
			case ExistingProject:
				for (file in plan.files) {
					validateParents(plan.targetRoot, file.relativePath, true);
					final absolute = Path.resolve(plan.targetRoot, file.relativePath);
					switch file.action {
						case Create:
							if (entryStats(absolute) != null) {
								collision(file.relativePath, "scaffold-owned path already exists");
							}
						case UpdateMarker(beforeSha256):
							validateExistingFile(absolute, file.relativePath, beforeSha256);
					}
				}
		}
	}

	public static function publish(plan:ScaffoldPlan):Void {
		preflight(plan);
		switch plan.mode {
			case NewProject:
				publishNew(plan);
			case ExistingProject:
				publishExisting(plan);
		}
	}

	static function publishNew(plan:ScaffoldPlan):Void {
		final parent = Path.dirname(plan.targetRoot);
		final stageRoot = Fs.mkdtempSync(Path.join(parent, ".wordpresshx-new-"));
		Fs.chmodSync(stageRoot, PRIVATE_DIRECTORY_MODE);
		try {
			stageFiles(stageRoot, plan.files);
			preflight(plan);
			setDirectoryModes(stageRoot);
			Fs.renameSync(stageRoot, plan.targetRoot);
		} catch (failure:haxe.Exception) {
			removePrivateStage(stageRoot, parent, ".wordpresshx-new-");
			throw failure;
		}
	}

	static function publishExisting(plan:ScaffoldPlan):Void {
		final parent = Path.dirname(plan.targetRoot);
		final stageRoot = Fs.mkdtempSync(Path.join(parent, ".wordpresshx-init-"));
		final commits:Array<ScaffoldCommit> = [];
		final createdDirectories:Array<String> = [];
		Fs.chmodSync(stageRoot, PRIVATE_DIRECTORY_MODE);
		try {
			stageFiles(stageRoot, plan.files);
			preflight(plan);
			for (file in plan.files) {
				ensureDestinationDirectories(plan.targetRoot, file.relativePath, createdDirectories);
				commitFile(plan.targetRoot, stageRoot, file, commits);
			}
		} catch (failure:haxe.Exception) {
			if (!rollback(plan.targetRoot, commits, createdDirectories)) {
				throw new CliFailure("WPHX3010",
					"scaffold publication failed and exact rollback could not complete; private recovery bytes were retained beside the project", 70,
					"scaffold-rollback", null, [
						"Do not rerun init until the retained .wordpresshx-init-* directory and owned paths are inspected."
					], failure);
			}
			removePrivateStage(stageRoot, parent, ".wordpresshx-init-");
			if (Std.isOfType(failure, CliFailure)) {
				throw failure;
			}
			throw new CliFailure("WPHX3011", "scaffold publication stopped and exact rollback restored the prior tree", 5, "scaffold-publish", null, [
				"Resolve the filesystem permission or capacity failure, then rerun the complete dry-run."
			], failure);
		}
		removePrivateStage(stageRoot, parent, ".wordpresshx-init-");
	}

	static function stageFiles(stageRoot:String, files:Array<ScaffoldFile>):Void {
		for (file in files) {
			final absolute = Path.resolve(stageRoot, file.relativePath);
			ensureStageDirectory(stageRoot, Path.dirname(absolute));
			Fs.writeFileSync(absolute, file.content, {encoding: "utf8", flag: "wx", mode: file.mode});
			Fs.chmodSync(absolute, file.mode);
		}
	}

	static function commitFile(projectRoot:String, stageRoot:String, file:ScaffoldFile, commits:Array<ScaffoldCommit>):Void {
		validateParents(projectRoot, file.relativePath, false);
		final staged = Path.resolve(stageRoot, file.relativePath);
		final destination = Path.resolve(projectRoot, file.relativePath);
		switch file.action {
			case Create:
				if (entryStats(destination) != null) {
					collision(file.relativePath, "scaffold-owned path appeared during publication");
				}
				Fs.linkSync(staged, destination);
				commits.push(Created(file));
				Fs.unlinkSync(staged);
				Fs.chmodSync(destination, file.mode);
			case UpdateMarker(beforeSha256):
				validateExistingFile(destination, file.relativePath, beforeSha256);
				final backup = Path.resolve(stageRoot, ".backup", file.relativePath);
				ensureStageDirectory(stageRoot, Path.dirname(backup));
				Fs.renameSync(destination, backup);
				commits.push(Updated(file, backup));
				if (entryStats(destination) != null) {
					collision(file.relativePath, "hand-owned path appeared during marker publication");
				}
				Fs.linkSync(staged, destination);
				Fs.unlinkSync(staged);
				Fs.chmodSync(destination, file.mode);
		}
	}

	static function rollback(projectRoot:String, commits:Array<ScaffoldCommit>, createdDirectories:Array<String>):Bool {
		try {
			var index = commits.length;
			while (index > 0) {
				index--;
				switch commits[index] {
					case Created(file):
						removeExactPublishedFile(Path.resolve(projectRoot, file.relativePath), file);
					case Updated(file, backupPath):
						final destination = Path.resolve(projectRoot, file.relativePath);
						if (entryStats(destination) != null) {
							removeExactPublishedFile(destination, file);
						}
						final backupStats = Fs.lstatSync(backupPath);
						if (backupStats.isSymbolicLink() || !backupStats.isFile()) {
							return false;
						}
						Fs.renameSync(backupPath, destination);
				}
			}
			var directoryIndex = createdDirectories.length;
			while (directoryIndex > 0) {
				directoryIndex--;
				final absolute = createdDirectories[directoryIndex];
				final stats = entryStats(absolute);
				if (stats != null) {
					if (stats.isSymbolicLink() || !stats.isDirectory() || Fs.readdirSync(absolute).length != 0) {
						return false;
					}
					Fs.rmdirSync(absolute);
				}
			}
			return true;
		} catch (_:haxe.Exception) {
			return false;
		}
	}

	static function removeExactPublishedFile(absolute:String, file:ScaffoldFile):Void {
		final stats = entryStats(absolute);
		if (stats == null) {
			return;
		}
		if (stats.isSymbolicLink() || !stats.isFile()) {
			throw new haxe.Exception("published scaffold path changed type before rollback");
		}
		final bytes = Fs.readFileSync(absolute);
		final source = utf8(bytes, file.relativePath);
		if (Content.digest(source) != file.sha256()) {
			throw new haxe.Exception("published scaffold bytes changed before rollback");
		}
		Fs.unlinkSync(absolute);
	}

	static function validateProjectRoot(plan:ScaffoldPlan):Void {
		final root = switch plan.mode {
			case NewProject: Path.dirname(plan.targetRoot);
			case ExistingProject: plan.targetRoot;
		};
		final stats = entryStats(root);
		if (stats == null) {
			throw new CliFailure("WPHX3006", "scaffold root disappeared before publication", 5, "scaffold-preflight");
		}
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			throw new CliFailure("WPHX3006", "scaffold root must remain a real directory", 5, "scaffold-preflight");
		}
	}

	static function validateParents(root:String, relativePath:String, missingAllowed:Bool):Void {
		var current = root;
		final segments = relativePath.split("/");
		for (index in 0...(segments.length - 1)) {
			current = Path.join(current, segments[index]);
			final stats = entryStats(current);
			if (stats == null) {
				if (missingAllowed) {
					return;
				}
				throw new CliFailure("WPHX3006", "scaffold destination parent is missing during publication", 5, "scaffold-publish", relativePath);
			}
			if (stats.isSymbolicLink() || !stats.isDirectory()) {
				throw new CliFailure("WPHX3006", "scaffold path crosses a link or non-directory", 5, "scaffold-preflight", relativePath, [
					"Replace the conflicting path with a real project-local directory, then rerun the dry-run."
				]);
			}
		}
	}

	static function validateExistingFile(absolute:String, relativePath:String, beforeSha256:String):Void {
		final stats = entryStats(absolute);
		if (stats == null) {
			throw new CliFailure("WPHX3009", "hand-owned marker file disappeared before publication", 5, "scaffold-preflight", relativePath);
		}
		if (stats.isSymbolicLink() || !stats.isFile()) {
			throw new CliFailure("WPHX3006", "hand-owned marker path must remain a regular non-link file", 5, "scaffold-preflight", relativePath);
		}
		final source = utf8(Fs.readFileSync(absolute), relativePath);
		if (Content.digest(source) != beforeSha256) {
			throw new CliFailure("WPHX3009", "hand-owned marker file changed after planning", 5, "scaffold-preflight", relativePath,
				["Review the current file and rerun the command to produce a new plan."]);
		}
	}

	static function utf8(bytes:Buffer, relativePath:String):String {
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			throw new CliFailure("WPHX3005", "scaffold text input is not valid UTF-8", 5, "scaffold-preflight", relativePath);
		}
		return source;
	}

	static function ensureDestinationDirectories(root:String, relativePath:String, created:Array<String>):Void {
		var current = root;
		final segments = relativePath.split("/");
		for (index in 0...(segments.length - 1)) {
			current = Path.join(current, segments[index]);
			final stats = entryStats(current);
			if (stats != null) {
				if (stats.isSymbolicLink() || !stats.isDirectory()) {
					throw new CliFailure("WPHX3006", "scaffold path crosses a link or non-directory", 5, "scaffold-publish", relativePath);
				}
			} else {
				Fs.mkdirSync(current, PROJECT_DIRECTORY_MODE);
				created.push(current);
			}
		}
	}

	static function ensureStageDirectory(stageRoot:String, absolute:String):Void {
		if (absolute == stageRoot || entryStats(absolute) != null) {
			return;
		}
		ensureStageDirectory(stageRoot, Path.dirname(absolute));
		Fs.mkdirSync(absolute, PRIVATE_DIRECTORY_MODE);
	}

	static function setDirectoryModes(absolute:String):Void {
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			throw new CliFailure("WPHX3006", "private scaffold stage changed type before publication", 70, "scaffold-publish");
		}
		for (name in Fs.readdirSync(absolute)) {
			final child = Path.join(absolute, name);
			final childStats = Fs.lstatSync(child);
			if (childStats.isDirectory() && !childStats.isSymbolicLink()) {
				setDirectoryModes(child);
			} else if (childStats.isSymbolicLink() || !childStats.isFile()) {
				throw new CliFailure("WPHX3006", "private scaffold stage contains a link or special file", 70, "scaffold-publish");
			}
		}
		Fs.chmodSync(absolute, PROJECT_DIRECTORY_MODE);
	}

	static function removePrivateStage(stageRoot:String, expectedParent:String, expectedPrefix:String):Void {
		if (Path.dirname(stageRoot) != expectedParent
			|| !StringTools.startsWith(Path.basename(stageRoot), expectedPrefix)
			|| entryStats(stageRoot) == null) {
			return;
		}
		removeTree(stageRoot);
	}

	static function removeTree(absolute:String):Void {
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(absolute);
			return;
		}
		if (!stats.isDirectory()) {
			throw new haxe.Exception("private scaffold stage contains a special file");
		}
		final names = Fs.readdirSync(absolute);
		names.sort((left, right) -> left < right ? -1 : left > right ? 1 : 0);
		for (name in names) {
			removeTree(Path.join(absolute, name));
		}
		Fs.rmdirSync(absolute);
	}

	static function collision(relativePath:Null<String>, message:String):Void {
		throw new CliFailure("WPHX3007", message, 5, "scaffold-preflight", relativePath, [
			"Choose a new project directory or move the conflicting path; scaffolding never overwrites it."
		]);
	}

	static function entryStats(absolute:String):Null<Stats> {
		try {
			return Fs.lstatSync(absolute);
		} catch (failure:ScaffoldFsError) {
			if (failure.code == "ENOENT") {
				return null;
			}
			throw failure;
		}
	}
}
