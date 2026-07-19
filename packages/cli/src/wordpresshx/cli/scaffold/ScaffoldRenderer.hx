package wordpresshx.cli.scaffold;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldFileAction;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldOwnership;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldKind;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldMode;

/** Render the complete minimal site tree from one validated slug. */
class ScaffoldRenderer {
	public static function plan(request:ScaffoldRequest, cwd:String):ScaffoldPlan {
		final selected = request.projectPath == null ? cwd : request.projectPath;
		final selectedRoot = Path.resolve(selected);
		final projectId = switch request.mode {
			case NewProject:
				switch request.requestedProjectId {
					case null: throw new CliFailure("WPHX3001", "new site requires a project name", 2, "scaffold-plan");
					case value: value;
				}
			case ExistingProject:
				request.requestedProjectId == null ? ScaffoldIdentity.projectId(Path.basename(selectedRoot)) : request.requestedProjectId;
		};
		final targetRoot = switch request.mode {
			case NewProject: Path.join(selectedRoot, projectId);
			case ExistingProject: selectedRoot;
		};
		validateSelectedRoot(request.mode, selectedRoot, targetRoot);
		final packageName = ScaffoldIdentity.packageName(projectId);
		final entryPoint = ScaffoldIdentity.entryPoint(projectId);
		final config = projectConfig(projectId, entryPoint, request.profile);
		final manifest = packageManifest(projectId);
		final packageLock = packageLock(projectId);
		final projectLock = ScaffoldToolchain.lock(projectId, request.profile, config, "package.json", manifest, "package-lock.json", packageLock);
		final files:Array<ScaffoldFile> = [
			gitignore(request.mode, targetRoot),
			new ScaffoldFile(".haxerc", ScaffoldProjection.haxerc(), CliOwned, Create),
			new ScaffoldFile(".wphx/bootstrap/project.hxml", ScaffoldProjection.hxml(entryPoint, ["src"], ["test"]), CliOwned, Create),
			new ScaffoldFile(".wphx/project.lock.json", projectLock, CliOwned, Create),
			new ScaffoldFile("README.md", readme(request.kind, projectId, request.profile), Authored, Create),
			new ScaffoldFile("assets/.gitkeep", "", Authored, Create),
			new ScaffoldFile("package.json", manifest, CliOwned, Create),
			new ScaffoldFile("package-lock.json", packageLock, CliOwned, Create),
			new ScaffoldFile("src/" + entryPoint.split(".").join("/") + ".hx", siteSource(request.kind, packageName, projectId, request.profile), Authored,
				Create),
			new ScaffoldFile("test/" + packageName.split(".").join("/") + "/SiteTest.hx", siteTestSource(request.kind, packageName), Authored, Create),
			new ScaffoldFile("wordpress-hx.json", ScaffoldJson.document(config, true), CliOwned, Create)
		];
		return new ScaffoldPlan(request.mode, request.kind, projectId, ScaffoldIdentity.displayName(projectId), packageName, entryPoint, request.profile,
			targetRoot, projectId, files);
	}

	static function validateSelectedRoot(mode:ScaffoldMode, selectedRoot:String, targetRoot:String):Void {
		if (!Fs.existsSync(selectedRoot)) {
			throw new CliFailure("WPHX3006", "selected scaffold directory does not exist", 5, "scaffold-preflight", null,
				["Create the parent directory explicitly, then rerun the dry-run."]);
		}
		final selectedStats = Fs.lstatSync(selectedRoot);
		if (selectedStats.isSymbolicLink() || !selectedStats.isDirectory()) {
			throw new CliFailure("WPHX3006", "selected scaffold directory must be a real directory", 5, "scaffold-preflight", null,
				["Choose a regular directory rather than a link or special file."]);
		}
		if (mode == ExistingProject) {
			final targetStats = Fs.lstatSync(targetRoot);
			if (targetStats.isSymbolicLink() || !targetStats.isDirectory()) {
				throw new CliFailure("WPHX3006", "init target must be a real directory", 5, "scaffold-preflight");
			}
		}
	}

	static function gitignore(mode:ScaffoldMode, targetRoot:String):ScaffoldFile {
		final relative = ".gitignore";
		if (mode == NewProject || !Fs.existsSync(Path.join(targetRoot, relative))) {
			return new ScaffoldFile(relative, ScaffoldMarker.newDocument(), Authored, Create);
		}
		final absolute = Path.join(targetRoot, relative);
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			throw new CliFailure("WPHX3006", "existing .gitignore must be a regular non-link file", 5, "scaffold-preflight", relative);
		}
		final bytes = Fs.readFileSync(absolute);
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			throw new CliFailure("WPHX3005", "existing .gitignore is not valid UTF-8", 5, "scaffold-preflight", relative);
		}
		return new ScaffoldFile(relative, ScaffoldMarker.replace(source), Authored, UpdateMarker(Content.digest(source)));
	}

	static function projectConfig(projectId:String, entryPoint:String, profile:String):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.project.v1")),
			ScaffoldJson.field("projectId", ScaffoldJson.text(projectId)),
			ScaffoldJson.field("entryPoint", ScaffoldJson.text(entryPoint)),
			ScaffoldJson.field("profile", ScaffoldJson.object([ScaffoldJson.field("id", ScaffoldJson.text(profile))])),
			ScaffoldJson.field("paths", ScaffoldJson.object([
				ScaffoldJson.field("sourceRoots", ScaffoldJson.array([ScaffoldJson.text("src")])),
				ScaffoldJson.field("testRoots", ScaffoldJson.array([ScaffoldJson.text("test")])),
				ScaffoldJson.field("assetRoots", ScaffoldJson.array([ScaffoldJson.text("assets")])),
				ScaffoldJson.field("outputRoots",
					ScaffoldJson.array([
						ScaffoldJson.object([
							ScaffoldJson.field("id", ScaffoldJson.text("wordpress")),
							ScaffoldJson.field("path", ScaffoldJson.text("build/wordpress"))
						])
					])),
				ScaffoldJson.field("distributionRoot", ScaffoldJson.text("dist")),
				ScaffoldJson.field("stateRoot", ScaffoldJson.text(".wphx"))
			])),
			ScaffoldJson.field("toolchain", ScaffoldJson.object([
				ScaffoldJson.field("lock", ScaffoldJson.text(".wphx/project.lock.json")),
				ScaffoldJson.field("packageManager", ScaffoldJson.object([
					ScaffoldJson.field("kind", ScaffoldJson.text("npm")),
					ScaffoldJson.field("manifest", ScaffoldJson.text("package.json")),
					ScaffoldJson.field("lockfile", ScaffoldJson.text("package-lock.json"))
				]))
			])),
			ScaffoldJson.field("environment", ScaffoldJson.object([
				ScaffoldJson.field("build", ScaffoldJson.array([])),
				ScaffoldJson.field("runtime", ScaffoldJson.array([]))
			]))
		]);
	}

	static function packageManifest(projectId:String):String {
		return ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("name", ScaffoldJson.text(projectId)),
			ScaffoldJson.field("version", ScaffoldJson.text("0.0.0")),
			ScaffoldJson.field("private", ScaffoldJson.boolean(true)),
			ScaffoldJson.field("scripts",
				ScaffoldJson.object([
					ScaffoldJson.field("build", ScaffoldJson.text("wphx build")),
					ScaffoldJson.field("check", ScaffoldJson.text("wphx check")),
					ScaffoldJson.field("dev", ScaffoldJson.text("wphx dev")),
					ScaffoldJson.field("test", ScaffoldJson.text("wphx test"))
				])),
			ScaffoldJson.field("devDependencies", ScaffoldJson.object([ScaffoldJson.field("@wordpress-hx/cli", ScaffoldJson.text("0.0.0"))])),
			ScaffoldJson.field("engines", ScaffoldJson.object([ScaffoldJson.field("node", ScaffoldJson.text("22.17.0"))])),
			ScaffoldJson.field("packageManager", ScaffoldJson.text("npm@10.9.2"))
		]), true);
	}

	static function packageLock(projectId:String):String {
		return ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("name", ScaffoldJson.text(projectId)),
			ScaffoldJson.field("version", ScaffoldJson.text("0.0.0")),
			ScaffoldJson.field("lockfileVersion", ScaffoldJson.number(3)),
			ScaffoldJson.field("requires", ScaffoldJson.boolean(true)),
			ScaffoldJson.field("packages", ScaffoldJson.object([
				ScaffoldJson.field("", ScaffoldJson.object([
					ScaffoldJson.field("name", ScaffoldJson.text(projectId)),
					ScaffoldJson.field("version", ScaffoldJson.text("0.0.0")),
					ScaffoldJson.field("devDependencies", ScaffoldJson.object([ScaffoldJson.field("@wordpress-hx/cli", ScaffoldJson.text("0.0.0"))])),
					ScaffoldJson.field("engines", ScaffoldJson.object([ScaffoldJson.field("node", ScaffoldJson.text("22.17.0"))]))
				])),
				ScaffoldJson.field("node_modules/@wordpress-hx/cli", ScaffoldJson.object([
					ScaffoldJson.field("version", ScaffoldJson.text("0.0.0")),
					ScaffoldJson.field("dev", ScaffoldJson.boolean(true)),
					ScaffoldJson.field("bin", ScaffoldJson.object([ScaffoldJson.field("wphx", ScaffoldJson.text("build/index.js"))])),
					ScaffoldJson.field("engines", ScaffoldJson.object([ScaffoldJson.field("node", ScaffoldJson.text("22.17.0"))]))
				]))
			]))
		]), true);
	}

	static function siteSource(kind:ScaffoldKind, packageName:String, projectId:String, profile:String):String {
		if (kind == Plugin) {
			return "package "
				+ packageName
				+ ";\n\n"
				+ "import wordpresshx.WordPress;\n\n"
				+ "/** Haxe-owned plugin authority; identity and native PHP are derived. */\n"
				+ "final class Site {\n"
				+ "\tpublic static final definition = WordPress.plugin();\n"
				+ "}\n";
		}
		return "package "
			+ packageName
			+ ";\n\n"
			+ "/** Haxe-owned site authority; native files are derived build artifacts. */\n"
			+ "final class Site {\n"
			+ '\tpublic static inline final id = "'
			+ projectId
			+ '";\n'
			+ '\tpublic static inline final profile = "'
			+ profile
			+ '";\n\n'
			+ "\tpublic static function main():Void {}\n"
			+ "}\n";
	}

	static function siteTestSource(kind:ScaffoldKind, packageName:String):String {
		if (kind == Plugin) {
			return "package "
				+ packageName
				+ ";\n\n"
				+ "final class SiteTest {\n"
				+ "\tpublic static function targetIsTyped():Void {\n"
				+ "\t\tfinal target:wordpresshx.WordPress.WordPressTarget = Site.definition.target;\n"
				+ "\t\tif (target != wordpresshx.WordPress.WordPressTarget.Plugin) {\n"
				+ "\t\t\tthrow new haxe.Exception(\"plugin target differs\");\n"
				+ "\t\t}\n"
				+ "\t}\n"
				+ "}\n";
		}
		return "package "
			+ packageName
			+ ";\n\n"
			+ "final class SiteTest {\n"
			+ "\tpublic static function identityIsTyped():Void {\n"
			+ "\t\tfinal identity:String = Site.id;\n"
			+ "\t\tif (identity.length == 0) {\n"
			+ "\t\t\tthrow new haxe.Exception(\"site identity is empty\");\n"
			+ "\t\t}\n"
			+ "\t}\n"
			+ "}\n";
	}

	static function readme(kind:ScaffoldKind, projectId:String, profile:String):String {
		final finalParagraph = switch kind {
			case Site:
				"Pre-release limitation: native site/plugin/block producers and public package installation are not registered yet, so the current build proves only the typed project and deterministic ownership foundation.\n";
			case Plugin:
				"The zero-argument `WordPress.plugin()` declaration derives conventional plugin metadata from the project identity. Pass an inline typed options object only for metadata you need to override. This pre-release slice emits and packages the native bootstrap only; hooks, lifecycle behavior beyond bootstrap, and public package installation remain dependency-gated.\n";
		};
		return "# "
			+ ScaffoldIdentity.displayName(projectId)
			+ "\n\n"
			+ "This project keeps application authority in Haxe, centered on `src/"
			+ ScaffoldIdentity.entryPoint(projectId).split(".").join("/")
			+ ".hx`.\n\n"
			+ "```bash\n"
			+ "wphx dev\n"
			+ "wphx check\n"
			+ "wphx build\n"
			+ "```\n\n"
			+ "Exact profile: `"
			+ profile
			+ "`. Bootstrap JSON, HXML, npm metadata, and the project lock are CLI-owned projections; edit `Site.hx` for normal work.\n\n"
			+ finalParagraph;
	}
}
