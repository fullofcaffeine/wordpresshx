package wordpresshx.cli.project;

import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipContract;

/** Enforce native-runtime access modes on the exact emitted plugin tree. */
class PluginArtifactPermissions {
	public static inline final DIRECTORY_MODE = 493; // 0755
	public static inline final FILE_MODE = 420; // 0644
	static inline final MODE_MASK = 511; // 0777

	public static function enforce(projectRoot:String, pluginBase:String, files:Array<PluginEmittedFile>):Void {
		OwnershipContract.relative(pluginBase, "generated plugin root");
		final directories = directoryInventory(pluginBase, files);
		for (relative in directories) {
			normalize(projectRoot, relative, true, DIRECTORY_MODE);
		}
		final emitted = files.copy();
		emitted.sort((left, right) -> compareText(left.relativePath, right.relativePath));
		for (file in emitted) {
			OwnershipContract.relative(file.relativePath, "generated plugin file");
			normalize(projectRoot, pluginBase + "/" + file.relativePath, false, FILE_MODE);
		}
	}

	static function directoryInventory(pluginBase:String, files:Array<PluginEmittedFile>):Array<String> {
		final unique = new Map<String, Bool>();
		unique.set(pluginBase, true);
		for (file in files) {
			OwnershipContract.relative(file.relativePath, "generated plugin file");
			final segments = file.relativePath.split("/");
			var current = pluginBase;
			for (index in 0...(segments.length - 1)) {
				current += "/" + segments[index];
				unique.set(current, true);
			}
		}
		final result = [for (relative in unique.keys()) relative];
		result.sort(compareText);
		return result;
	}

	static function normalize(projectRoot:String, relative:String, directory:Bool, mode:Int):Void {
		OwnershipContract.relative(relative, directory ? "generated plugin directory" : "generated plugin file");
		final absolute = Path.resolve(projectRoot, relative);
		if (!Fs.existsSync(absolute)) {
			fail("generated plugin publication omitted an expected " + (directory ? "directory" : "file"), relative);
		}
		final before = Fs.lstatSync(absolute);
		if (before.isSymbolicLink() || (directory ? !before.isDirectory() : !before.isFile())) {
			fail("generated plugin publication contains a link or special filesystem entry", relative);
		}
		Fs.chmodSync(absolute, mode);
		final after = Fs.lstatSync(absolute);
		if (after.isSymbolicLink() || (directory ? !after.isDirectory() : !after.isFile()) || (after.mode & MODE_MASK) != mode) {
			fail("generated plugin publication could not establish its native-runtime access mode", relative);
		}
	}

	static function fail(message:String, relative:String):Void {
		throw new CliFailure("WPHX3310", message, 5, "ownership-publish", relative, [
			"Restore a regular project-local generated path on a filesystem that supports 0755 directories and 0644 files, then rebuild."
		]);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
