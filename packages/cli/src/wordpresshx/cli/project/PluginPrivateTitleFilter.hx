package wordpresshx.cli.project;

/** Compiler-resolved private implementation edge for the native title adapter. */
class PluginPrivateTitleFilter {
	public final className:String;
	public final methodName:String;
	public final sourcePath:String;
	public final startLine:Int;
	public final startColumn:Int;
	public final endLine:Int;
	public final endColumn:Int;

	public function new(className:String, methodName:String, sourcePath:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int) {
		this.className = className;
		this.methodName = methodName;
		this.sourcePath = sourcePath;
		this.startLine = startLine;
		this.startColumn = startColumn;
		this.endLine = endLine;
		this.endColumn = endColumn;
	}
}
