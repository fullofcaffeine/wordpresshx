package wordpresshx.cli.project;

import js.node.Buffer;

/** One ordinary PHP file produced from the typed plugin declaration. */
class PluginEmittedFile {
	public final lane:PluginArtifactLane;
	public final role:String;
	public final relativePath:String;
	public final bytes:Buffer;
	public final sha256:String;

	public function new(lane:PluginArtifactLane, role:String, relativePath:String, source:String) {
		this.lane = lane;
		this.role = role;
		this.relativePath = relativePath;
		this.bytes = Buffer.from(source, "utf8");
		this.sha256 = wordpresshx.cli.Content.digest(source);
	}

	public function artifactKind():String {
		return switch lane {
			case PublicNative: "wordpress.plugin.public-php." + role;
			case PrivateRuntime: "wordpress.plugin.private-stock-haxe.php";
			case PrivateClassmap: "wordpress.plugin.private-classmap.php";
			case PrivateManifest: "wordpress.plugin.private-runtime-manifest.json";
		};
	}
}
