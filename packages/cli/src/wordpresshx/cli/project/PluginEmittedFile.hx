package wordpresshx.cli.project;

import js.node.Buffer;

/** One ordinary PHP file produced from the typed plugin declaration. */
class PluginEmittedFile {
	public final role:String;
	public final relativePath:String;
	public final bytes:Buffer;
	public final sha256:String;

	public function new(role:String, relativePath:String, source:String) {
		this.role = role;
		this.relativePath = relativePath;
		this.bytes = Buffer.from(source, "utf8");
		this.sha256 = wordpresshx.cli.Content.digest(source);
	}
}
