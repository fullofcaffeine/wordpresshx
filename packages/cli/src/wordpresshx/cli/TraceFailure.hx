package wordpresshx.cli;

/** Expected CLI failure with a public, stable exit-code class. **/
class TraceFailure extends haxe.Exception {
	public final exitCode:Int;

	public function new(message:String, exitCode:Int) {
		super(message);
		this.exitCode = exitCode;
	}
}
