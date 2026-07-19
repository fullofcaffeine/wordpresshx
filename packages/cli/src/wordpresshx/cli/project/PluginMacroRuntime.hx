package wordpresshx.cli.project;

import haxe.Resource;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import wordpresshx.cli.CliFailure;

/** Materialize the packaged compile-time API only for one bounded invocation. */
class PluginMacroRuntime {
	static inline final RESOURCE_ID = "wordpresshx-project-api";
	static inline final SOURCE_PATH = "wordpresshx/WordPress.hx";
	static inline final TEMPORARY_PREFIX = "wordpresshx-plugin-plan-";

	public static function prepare(context:ProjectContext):PluginMacroInvocation {
		assertNoProjectShadow(context);
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), TEMPORARY_PREFIX));
		final sourceRoot = Path.join(temporaryRoot, "source");
		final sourcePath = Path.join(sourceRoot, SOURCE_PATH);
		ensureDirectory(Path.dirname(sourcePath));
		final source = projectApiSource();
		Fs.writeFileSync(sourcePath, source, {flag: "wx", mode: 0x1a4});
		return {
			temporaryRoot: temporaryRoot,
			sourceRoot: sourceRoot,
			planPath: Path.join(temporaryRoot, "plugin-plan.json"),
			projectId: PluginPlanReader.configuredProjectId(context),
			profileId: context.profileId()
		};
	}

	public static function projectApiSource():String {
		final source = Resource.getString(RESOURCE_ID);
		if (source == null || source.length == 0) {
			throw new CliFailure("WPHX3300", "packaged Haxe project API resource is missing", 70, "haxe-typing-and-plan");
		}
		return source;
	}

	public static function compilerArguments(invocation:PluginMacroInvocation):Array<String> {
		return [
			"-cp",
			invocation.sourceRoot,
			"-D",
			"wordpress-hx-project-id=" + invocation.projectId,
			"-D",
			"wordpress-hx-profile=" + invocation.profileId,
			"-D",
			"wordpress-hx-plan-output=" + invocation.planPath
		];
	}

	public static function finish(invocation:PluginMacroInvocation, context:ProjectContext):Null<PluginPlan> {
		var plan:Null<PluginPlan> = null;
		if (Fs.existsSync(invocation.planPath)) {
			final stats = Fs.lstatSync(invocation.planPath);
			if (stats.isSymbolicLink() || !stats.isFile()) {
				discard(invocation);
				throw new CliFailure("WPHX3301", "plugin compiler plan is not a regular private file", 6, "haxe-typing-and-plan");
			}
			plan = PluginPlanReader.decode(Fs.readFileSync(invocation.planPath).toString("utf8"), context);
		}
		discard(invocation);
		return plan;
	}

	public static function discard(invocation:PluginMacroInvocation):Void {
		final expectedPrefix = Path.join(Os.tmpdir(), TEMPORARY_PREFIX);
		if (!StringTools.startsWith(invocation.temporaryRoot, expectedPrefix) || !Fs.existsSync(invocation.temporaryRoot)) {
			return;
		}
		removeTree(invocation.temporaryRoot);
	}

	static function assertNoProjectShadow(context:ProjectContext):Void {
		for (root in context.bootstrap.sourceRoots.concat(context.bootstrap.testRoots)) {
			final relative = root + "/" + SOURCE_PATH;
			if (Fs.existsSync(Path.resolve(context.bootstrap.root, relative))) {
				throw new CliFailure("WPHX3302", "project source may not shadow the packaged WordPressHx compile-time API", 6, "haxe-typing-and-plan",
					relative, [
						"Rename the colliding module; import wordpresshx.WordPress from the exact SDK instead."
					]);
			}
		}
	}

	static function ensureDirectory(path:String):Void {
		if (Fs.existsSync(path)) {
			return;
		}
		final parent = Path.dirname(path);
		if (parent != path) {
			ensureDirectory(parent);
		}
		Fs.mkdirSync(path, 0x1c0);
	}

	static function removeTree(path:String):Void {
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(path);
			return;
		}
		if (!stats.isDirectory()) {
			throw new CliFailure("WPHX3303", "private compiler directory changed to a special file", 70, "haxe-typing-and-plan");
		}
		final names = Fs.readdirSync(path);
		names.sort(compareText);
		for (name in names) {
			removeTree(Path.join(path, name));
		}
		Fs.rmdirSync(path);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
