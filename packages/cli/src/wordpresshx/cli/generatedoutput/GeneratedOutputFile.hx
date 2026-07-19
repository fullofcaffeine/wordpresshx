package wordpresshx.cli.generatedoutput;

import js.node.Buffer;

/** One exact file in a selected generated tree. */
class GeneratedOutputFile {
	public final path:String;
	public final sizeBytes:Int;
	public final sha256:String;
	public final bytes:Buffer;

	public function new(path:String, sizeBytes:Int, sha256:String, bytes:Buffer) {
		this.path = path;
		this.sizeBytes = sizeBytes;
		this.sha256 = sha256;
		this.bytes = bytes;
	}
}
