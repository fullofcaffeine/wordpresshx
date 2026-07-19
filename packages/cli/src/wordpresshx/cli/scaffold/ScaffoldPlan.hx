package wordpresshx.cli.scaffold;

import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldFileAction;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldKind;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldMode;

class ScaffoldPlan {
	public final mode:ScaffoldMode;
	public final kind:ScaffoldKind;
	public final projectId:String;
	public final displayName:String;
	public final packageName:String;
	public final entryPoint:String;
	public final profile:String;
	public final targetRoot:String;
	public final targetName:String;
	public final files:Array<ScaffoldFile>;

	public function new(mode:ScaffoldMode, kind:ScaffoldKind, projectId:String, displayName:String, packageName:String, entryPoint:String, profile:String,
			targetRoot:String, targetName:String, files:Array<ScaffoldFile>) {
		this.mode = mode;
		this.kind = kind;
		this.projectId = projectId;
		this.displayName = displayName;
		this.packageName = packageName;
		this.entryPoint = entryPoint;
		this.profile = profile;
		this.targetRoot = targetRoot;
		this.targetName = targetName;
		this.files = files;
		this.files.sort((left, right) -> left.relativePath < right.relativePath ? -1 : left.relativePath > right.relativePath ? 1 : 0);
	}

	public function json(dryRun:Bool, published:Bool):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.scaffold-plan.v1")),
			ScaffoldJson.field("operation", ScaffoldJson.text(operation())),
			ScaffoldJson.field("kind", ScaffoldJson.text(kindLabel())),
			ScaffoldJson.field("projectId", ScaffoldJson.text(projectId)),
			ScaffoldJson.field("profile", ScaffoldJson.text(profile)),
			ScaffoldJson.field("entryPoint", ScaffoldJson.text(entryPoint)),
			ScaffoldJson.field("target", ScaffoldJson.text(targetName)),
			ScaffoldJson.field("dryRun", ScaffoldJson.boolean(dryRun)),
			ScaffoldJson.field("status", ScaffoldJson.text(published ? "published" : "planned")),
			ScaffoldJson.field("files", ScaffoldJson.array([for (file in files) fileJson(file)])),
			ScaffoldJson.field("limitations", ScaffoldJson.array([for (limitation in limitations()) ScaffoldJson.text(limitation)]))
		]);
	}

	public function operation():String {
		return switch mode {
			case NewProject: "new-" + kindLabel();
			case ExistingProject: "init-site";
		};
	}

	public function kindLabel():String {
		return switch kind {
			case Site: "site";
			case Plugin: "plugin";
		};
	}

	public function limitations():Array<String> {
		return switch kind {
			case Site: ["native-target-producers-not-registered", "public-package-installation-blocked"];
			case Plugin: ["plugin-bootstrap-only", "public-package-installation-blocked"];
		};
	}

	static function fileJson(file:ScaffoldFile):JsonValue {
		final before = file.beforeSha256();
		final fields = [
			ScaffoldJson.field("path", ScaffoldJson.text(file.relativePath)),
			ScaffoldJson.field("action", ScaffoldJson.text(file.actionLabel())),
			ScaffoldJson.field("ownership", ScaffoldJson.text(file.ownership.label())),
			ScaffoldJson.field("mode", ScaffoldJson.number(file.mode)),
			ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256())),
			ScaffoldJson.field("sizeBytes", ScaffoldJson.number(file.sizeBytes()))
		];
		if (before != null) {
			fields.push(ScaffoldJson.field("beforeSha256", ScaffoldJson.text(before)));
		}
		return ScaffoldJson.object(fields);
	}
}
