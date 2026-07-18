package wordpresshx.cli;

/** Stable, redacted command failure suitable for human or JSON diagnostics. **/
class CliFailure extends haxe.Exception {
	public final code:String;
	public final exitCode:Int;
	public final stage:String;
	public final relativePath:Null<String>;
	public final remediations:Array<String>;

	public function new(code:String, message:String, exitCode:Int, stage:String, ?relativePath:String, ?remediations:Array<String>, ?previous:haxe.Exception) {
		super(message, previous);
		this.code = code;
		this.exitCode = exitCode;
		this.stage = stage;
		this.relativePath = relativePath;
		this.remediations = remediations == null ? [] : remediations;
	}
}
