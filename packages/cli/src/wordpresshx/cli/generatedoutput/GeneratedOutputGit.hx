package wordpresshx.cli.generatedoutput;

import js.node.ChildProcess;
import js.node.ChildProcess.ChildProcessSpawnSyncResult;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.project.ProjectFiles;

/** Git HEAD boundary for reviewable committed-output verification. */
class GeneratedOutputGit {
	static inline final TEMPORARY_PREFIX = "wordpresshx-generated-output-check-";

	public final repositoryRoot:String;
	public final projectRoot:String;
	public final projectPrefix:String;
	public final head:String;

	public static function open(project:GeneratedOutputProject):GeneratedOutputGit {
		final projectRoot = project.context.bootstrap.root;
		final repositoryRoot = Path.resolve(run(projectRoot, ["rev-parse", "--show-toplevel"], "discover Git repository"));
		final relative = Path.relative(repositoryRoot, projectRoot).split(Path.sep).join("/");
		if (relative == ".." || StringTools.startsWith(relative, "../") || Path.isAbsolute(relative)) {
			fail("project root is outside its Git repository", "wordpress-hx.json");
		}
		final prefix = relative.length == 0 ? "" : relative;
		final head = run(repositoryRoot, ["rev-parse", "--verify", "HEAD"], "resolve Git HEAD");
		if (!~/^[0-9a-f]{40,64}$/.match(head)) {
			fail("Git HEAD is not an immutable object identity", "wordpress-hx.json");
		}
		return new GeneratedOutputGit(repositoryRoot, projectRoot, prefix, head);
	}

	public function requireClean():Void {
		if (run(repositoryRoot, ["status", "--porcelain=v1", "--untracked-files=all"], "inspect Git status").length != 0) {
			fail("generated-output verification requires a clean Git working tree", "wordpress-hx.json");
		}
		if (run(repositoryRoot, ["rev-parse", "--verify", "HEAD"], "recheck Git HEAD") != head) {
			fail("Git HEAD changed during generated-output verification", "wordpress-hx.json");
		}
	}

	public function validateAuthorityTracked(project:GeneratedOutputProject):Void {
		final bootstrap = project.context.bootstrap;
		final required = [
			".gitignore",
			".haxerc",
			"wordpress-hx.json",
			bootstrap.lockPath,
			bootstrap.packageManifestPath,
			bootstrap.packageLockPath
		];
		for (path in ProjectFiles.discover(bootstrap.root, ".wphx/bootstrap", [".hxml"], "Haxe bootstrap root")) {
			required.push(path);
		}
		for (root in bootstrap.sourceRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, [".hx", ".hxx"], "source root")) {
				required.push(path);
			}
		}
		for (root in bootstrap.testRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, [".hx", ".hxx"], "test root")) {
				required.push(path);
			}
		}
		for (root in bootstrap.assetRoots) {
			for (path in ProjectFiles.discover(bootstrap.root, root, null, "asset root")) {
				required.push(path);
			}
		}
		requireTracked(required, "Haxe source, exact locks, bootstrap, and assets must remain committed authority");
	}

	public function validateCommittedProjection(project:GeneratedOutputProject, policy:GeneratedOutputPolicy, tree:GeneratedOutputTree):Void {
		final required = [GeneratedOutputPolicy.PATH, ".gitignore"];
		for (file in tree.files) {
			required.push(file.path);
		}
		requireTracked(required, "policy, marker, manifest, and every selected generated file must be committed");
		final tracked = trackedFiles();
		if (!tracked.exists(policy.workflowPath)) {
			fail("generated-output CI workflow must be committed", policy.workflowPath);
		}
		for (root in project.unselectedRoots(policy.roots)) {
			if (containsAtOrBelow(tracked, repositoryPath(root.path))) {
				fail("configured output outside the explicit policy is tracked", root.path);
			}
		}
		if (containsAtOrBelow(tracked, repositoryPath(project.context.bootstrap.distributionRoot))) {
			fail("release and distribution output must remain outside committed-output mode", project.context.bootstrap.distributionRoot);
		}
	}

	public function projectRepositoryPath(relative:String):String {
		return repositoryPath(relative);
	}

	public function cloneAtHead():GeneratedOutputClone {
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), TEMPORARY_PREFIX));
		final cloneRoot = Path.join(temporaryRoot, "repository");
		try {
			run(repositoryRoot, ["clone", "--no-hardlinks", "--quiet", repositoryRoot, cloneRoot], "create clean local clone");
			run(cloneRoot, ["checkout", "--detach", "--quiet", head], "select immutable source commit");
			if (run(cloneRoot, ["rev-parse", "--verify", "HEAD"], "verify clean clone") != head) {
				throw new CliFailure("WPHX3417", "private regeneration clone selected a different commit", 70, "generated-output-git");
			}
			final clonedProject = projectPrefix.length == 0 ? cloneRoot : Path.join(cloneRoot, projectPrefix.split("/").join(Path.sep));
			return new GeneratedOutputClone(temporaryRoot, cloneRoot, clonedProject);
		} catch (failure:haxe.Exception) {
			GeneratedOutputClone.removeTemporary(temporaryRoot);
			throw failure;
		}
	}

	function requireTracked(paths:Array<String>, message:String):Void {
		final tracked = trackedFiles();
		for (path in paths) {
			if (!tracked.exists(repositoryPath(path))) {
				fail(message, path);
			}
		}
	}

	function trackedFiles():Map<String, Bool> {
		final result = new Map<String, Bool>();
		final source = runRaw(repositoryRoot, ["ls-files", "-z"], "list tracked repository files");
		for (path in source.split("\x00")) {
			if (path.length != 0) {
				result.set(path, true);
			}
		}
		return result;
	}

	function repositoryPath(relative:String):String {
		return projectPrefix.length == 0 ? relative : projectPrefix + "/" + relative;
	}

	static function containsAtOrBelow(paths:Map<String, Bool>, root:String):Bool {
		for (path => _ in paths) {
			if (path == root || StringTools.startsWith(path, root + "/")) {
				return true;
			}
		}
		return false;
	}

	static function run(cwd:String, arguments:Array<String>, label:String):String {
		return StringTools.trim(runRaw(cwd, arguments, label));
	}

	static function runRaw(cwd:String, arguments:Array<String>, label:String):String {
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync("git", arguments, {
			cwd: cwd,
			encoding: "utf8",
			timeout: 120000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		if (result.error != null || result.status != 0) {
			fail("could not " + label + " without prompts", "wordpress-hx.json");
		}
		return Std.string(result.stdout);
	}

	static function fail<T>(message:String, relative:String):T {
		throw new CliFailure("WPHX3417", message, 5, "generated-output-git", relative, [
			"Commit the complete reviewed Haxe, lock, policy, manifest, and generated-output change, then retry from a clean HEAD."
		]);
	}

	function new(repositoryRoot:String, projectRoot:String, projectPrefix:String, head:String) {
		this.repositoryRoot = repositoryRoot;
		this.projectRoot = projectRoot;
		this.projectPrefix = projectPrefix;
		this.head = head;
	}
}

class GeneratedOutputClone {
	public final temporaryRoot:String;
	public final repositoryRoot:String;
	public final projectRoot:String;

	public function dispose():Void {
		removeTemporary(temporaryRoot);
	}

	public static function removeTemporary(root:String):Void {
		final expected = Path.join(Os.tmpdir(), "wordpresshx-generated-output-check-");
		if (!StringTools.startsWith(root, expected) || !Fs.existsSync(root)) {
			return;
		}
		removeTree(root);
	}

	static function removeTree(path:String):Void {
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(path);
			return;
		}
		if (!stats.isDirectory()) {
			throw new haxe.Exception("private regeneration clone contains a special file");
		}
		final names = Fs.readdirSync(path);
		names.sort((left, right) -> left < right ? -1 : left > right ? 1 : 0);
		for (name in names) {
			removeTree(Path.join(path, name));
		}
		Fs.rmdirSync(path);
	}

	public function new(temporaryRoot:String, repositoryRoot:String, projectRoot:String) {
		this.temporaryRoot = temporaryRoot;
		this.repositoryRoot = repositoryRoot;
		this.projectRoot = projectRoot;
	}
}
