package wordpresshx.cli.ownership;

/** A fail-closed ownership or publication error safe to show without absolute paths. **/
class OwnershipFailure extends haxe.Exception {
	public final code:String;
	public final relativePath:Null<String>;

	public function new(message:String, code:String = "ownership-contract", ?relativePath:String, ?previous:haxe.Exception) {
		super(message, previous);
		this.code = code;
		this.relativePath = relativePath;
	}
}
