package wordpresshx.cli.scaffold;

import wordpresshx.cli.Content;
import wordpresshx.cli.project.ProjectContract;

enum ScaffoldFileAction {
	Create;
	UpdateMarker(beforeSha256:String);
}

enum abstract ScaffoldOwnership(String) {
	final Authored = "authored";
	final CliOwned = "cli-owned";

	public inline function label():String {
		return this;
	}
}

class ScaffoldFile {
	public final relativePath:String;
	public final content:String;
	public final ownership:ScaffoldOwnership;
	public final action:ScaffoldFileAction;
	public final mode:Int;

	public function new(relativePath:String, content:String, ownership:ScaffoldOwnership, action:ScaffoldFileAction, mode:Int = 420) {
		this.relativePath = ProjectContract.relativePath(relativePath, "scaffold file");
		this.content = content;
		this.ownership = ownership;
		this.action = action;
		this.mode = mode;
	}

	public inline function sha256():String {
		return Content.digest(content);
	}

	public inline function sizeBytes():Int {
		return Content.byteLength(content);
	}

	public function actionLabel():String {
		return switch action {
			case Create: "create";
			case UpdateMarker(_): "update-marker";
		};
	}

	public function beforeSha256():Null<String> {
		return switch action {
			case Create: null;
			case UpdateMarker(value): value;
		};
	}
}
