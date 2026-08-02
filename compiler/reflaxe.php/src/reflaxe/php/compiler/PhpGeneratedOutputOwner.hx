package reflaxe.php.compiler;

import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

private typedef PhpOwnedFileRecord = {
	final path:String;
	final sha256:String;
	final byteLength:Int;
}

/** One fully rendered file admitted to the compiler-owned publication transaction. **/
class PhpOwnedGeneratedFile {
	public final path:String;
	public final content:String;
	public final sha256:String;
	public final byteLength:Int;

	public function new(path:String, content:String) {
		this.path = PhpGeneratedOutputOwner.validateRelativePath(path);
		if (content == null) {
			throw "reflaxe.php generated content cannot be null";
		}
		this.content = content;
		final bytes = Bytes.ofString(content);
		this.sha256 = Sha256.make(bytes).toHex().toLowerCase();
		this.byteLength = bytes.length;
	}
}

/** Exact hash ownership with preflighted staging, rollback, and manifest-last publication. **/
class PhpGeneratedOutputOwner {
	public static final MANIFEST_PATH = ".reflaxe.php-owned-files.v1";
	static final HEADER = "reflaxe.php-owned-files.v1";
	static final SHA256 = ~/^[0-9a-f]{64}$/;

	final outputRoot:String;
	final fault:Null<(checkpoint:String) -> Void>;

	public function new(outputRoot:String, ?fault:(checkpoint:String) -> Void) {
		if (outputRoot == null || StringTools.trim(outputRoot).length == 0) {
			throw "reflaxe.php output root cannot be empty";
		}
		this.outputRoot = Path.normalize(FileSystem.absolutePath(outputRoot));
		this.fault = fault;
	}

	public function publish(files:Array<PhpOwnedGeneratedFile>):Void {
		final planned = indexPlanned(files);
		final previousManifest = readPreviousManifest();
		preflight(planned, previousManifest);
		final manifestPath = absolutePath(MANIFEST_PATH);
		final previousManifestContent = FileSystem.exists(manifestPath)
			&& !FileSystem.isDirectory(manifestPath) ? File.getContent(manifestPath) : null;
		if (!FileSystem.exists(outputRoot)) {
			FileSystem.createDirectory(outputRoot);
		}

		final previousContents = snapshotPrevious(previousManifest);
		final stagedPaths:Array<String> = [];
		try {
			for (file in files) {
				final stagePath = stageAbsolutePath(file);
				ensureParent(stagePath);
				if (FileSystem.exists(stagePath)) {
					throw "reflaxe.php staging collision for " + file.path;
				}
				File.saveContent(stagePath, file.content);
				if (digestFile(stagePath) != file.sha256) {
					throw "reflaxe.php staged bytes failed verification for " + file.path;
				}
				stagedPaths.push(stagePath);
			}
			for (file in files) {
				final target = absolutePath(file.path);
				final stage = stageAbsolutePath(file);
				ensureParent(target);
				if (!FileSystem.exists(target) || digestFile(target) != file.sha256) {
					File.saveContent(target, File.getContent(stage));
				}
			}
			for (record in previousManifest) {
				if (!planned.exists(record.path)) {
					final stale = absolutePath(record.path);
					if (FileSystem.exists(stale)) {
						FileSystem.deleteFile(stale);
					}
				}
			}
			checkpoint("after-artifacts");
			writeManifest(files);
			checkpoint("after-manifest");
		} catch (failure:haxe.Exception) {
			rollback(planned, previousContents);
			rollbackManifest(previousManifestContent);
			cleanupStages(stagedPaths);
			throw failure;
		}
		cleanupStages(stagedPaths);
	}

	function checkpoint(name:String):Void {
		if (fault != null) {
			fault(name);
		}
	}

	function rollbackManifest(previous:Null<String>):Void {
		final manifest = absolutePath(MANIFEST_PATH);
		if (previous == null) {
			if (FileSystem.exists(manifest) && !FileSystem.isDirectory(manifest)) {
				FileSystem.deleteFile(manifest);
			}
		} else {
			ensureParent(manifest);
			File.saveContent(manifest, previous);
		}
	}

	static public function validateRelativePath(value:String):String {
		if (value == null || value.length == 0 || value.indexOf("\x00") >= 0 || value.indexOf("\t") >= 0 || value.indexOf("\n") >= 0) {
			throw "reflaxe.php generated path is invalid";
		}
		final normalized = value.split("\\").join("/");
		if (StringTools.startsWith(normalized, "/") || normalized.indexOf(":") >= 0) {
			throw "reflaxe.php generated path must be relative: " + value;
		}
		for (segment in normalized.split("/")) {
			if (segment.length == 0 || segment == "." || segment == "..") {
				throw "reflaxe.php generated path contains an unsafe segment: " + value;
			}
		}
		if (normalized == MANIFEST_PATH || StringTools.endsWith(normalized, ".reflaxe-php-stage")) {
			throw "reflaxe.php generated path uses a reserved owner path: " + value;
		}
		return normalized;
	}

	function indexPlanned(files:Array<PhpOwnedGeneratedFile>):Map<String, PhpOwnedGeneratedFile> {
		final result = new Map<String, PhpOwnedGeneratedFile>();
		for (file in files) {
			if (result.exists(file.path)) {
				throw "Duplicate reflaxe.php generated path: " + file.path;
			}
			result.set(file.path, file);
		}
		return result;
	}

	function readPreviousManifest():Array<PhpOwnedFileRecord> {
		final manifest = absolutePath(MANIFEST_PATH);
		if (!FileSystem.exists(manifest)) {
			return [];
		}
		if (FileSystem.isDirectory(manifest)) {
			throw "reflaxe.php ownership manifest path is a directory";
		}
		final lines = File.getContent(manifest).split("\n");
		if (lines.length < 2 || lines[0] != HEADER || lines[lines.length - 1] != "") {
			throw "reflaxe.php ownership manifest is malformed";
		}
		final result:Array<PhpOwnedFileRecord> = [];
		final seen = new Map<String, Bool>();
		for (lineIndex in 1...lines.length - 1) {
			final fields = lines[lineIndex].split("\t");
			if (fields.length != 3 || !SHA256.match(fields[0])) {
				throw "reflaxe.php ownership manifest record is malformed";
			}
			final byteLength = Std.parseInt(fields[1]);
			final path = validateRelativePath(fields[2]);
			if (byteLength == null || byteLength < 0 || seen.exists(path)) {
				throw "reflaxe.php ownership manifest record is invalid";
			}
			seen.set(path, true);
			result.push({path: path, sha256: fields[0], byteLength: byteLength});
		}
		final sorted = result.copy();
		sorted.sort(compareRecords);
		for (index in 0...result.length) {
			if (result[index].path != sorted[index].path) {
				throw "reflaxe.php ownership manifest records are not canonical";
			}
		}
		return result;
	}

	function preflight(planned:Map<String, PhpOwnedGeneratedFile>, previous:Array<PhpOwnedFileRecord>):Void {
		final previousByPath = new Map<String, PhpOwnedFileRecord>();
		for (record in previous) {
			previousByPath.set(record.path, record);
		}
		for (file in planned) {
			final target = absolutePath(file.path);
			if (!FileSystem.exists(target)) {
				continue;
			}
			if (FileSystem.isDirectory(target)) {
				throw "reflaxe.php generated destination is a directory: " + file.path;
			}
			final previousRecord = previousByPath.get(file.path);
			if (previousRecord == null) {
				throw "reflaxe.php refuses to overwrite an unowned file: " + file.path;
			}
			if (digestFile(target) != previousRecord.sha256 || File.getBytes(target).length != previousRecord.byteLength) {
				throw "reflaxe.php owned file was modified: " + file.path;
			}
		}
		for (record in previous) {
			if (planned.exists(record.path)) {
				continue;
			}
			final stale = absolutePath(record.path);
			if (FileSystem.exists(stale)
				&& (FileSystem.isDirectory(stale)
					|| digestFile(stale) != record.sha256
					|| File.getBytes(stale).length != record.byteLength)) {
				throw "reflaxe.php stale owned file was modified: " + record.path;
			}
		}
	}

	function snapshotPrevious(previous:Array<PhpOwnedFileRecord>):Map<String, String> {
		final result = new Map<String, String>();
		for (record in previous) {
			final target = absolutePath(record.path);
			if (FileSystem.exists(target) && !FileSystem.isDirectory(target)) {
				result.set(record.path, File.getContent(target));
			}
		}
		return result;
	}

	function rollback(planned:Map<String, PhpOwnedGeneratedFile>, previousContents:Map<String, String>):Void {
		for (file in planned) {
			final target = absolutePath(file.path);
			final previous = previousContents.get(file.path);
			if (previous == null) {
				if (FileSystem.exists(target) && !FileSystem.isDirectory(target)) {
					FileSystem.deleteFile(target);
				}
			} else {
				ensureParent(target);
				File.saveContent(target, previous);
			}
		}
		for (path => content in previousContents) {
			final target = absolutePath(path);
			if (!FileSystem.exists(target)) {
				ensureParent(target);
				File.saveContent(target, content);
			}
		}
	}

	function writeManifest(files:Array<PhpOwnedGeneratedFile>):Void {
		final ordered = files.copy();
		ordered.sort((left, right) -> compareText(left.path, right.path));
		final lines = [HEADER];
		for (file in ordered) {
			lines.push(file.sha256 + "\t" + file.byteLength + "\t" + file.path);
		}
		final manifest = absolutePath(MANIFEST_PATH);
		ensureParent(manifest);
		File.saveContent(manifest, lines.join("\n") + "\n");
	}

	function cleanupStages(stagedPaths:Array<String>):Void {
		for (stage in stagedPaths) {
			if (FileSystem.exists(stage) && !FileSystem.isDirectory(stage)) {
				FileSystem.deleteFile(stage);
			}
		}
	}

	function stageAbsolutePath(file:PhpOwnedGeneratedFile):String {
		return absolutePath(file.path + "." + file.sha256.substr(0, 16) + ".reflaxe-php-stage");
	}

	function absolutePath(relative:String):String {
		return Path.join([outputRoot, relative]);
	}

	static function ensureParent(path:String):Void {
		final parent = Path.directory(path);
		if (!FileSystem.exists(parent)) {
			FileSystem.createDirectory(parent);
		}
	}

	static function digestFile(path:String):String {
		return Sha256.make(File.getBytes(path)).toHex().toLowerCase();
	}

	static function compareRecords(left:PhpOwnedFileRecord, right:PhpOwnedFileRecord):Int {
		return compareText(left.path, right.path);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
