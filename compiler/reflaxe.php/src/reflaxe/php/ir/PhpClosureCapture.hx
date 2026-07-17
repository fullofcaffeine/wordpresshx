package reflaxe.php.ir;

/** One lexical variable captured by a native PHP closure. **/
class PhpClosureCapture {
	public final name:PhpIdentifier;
	public final byReference:Bool;

	public function new(name:PhpIdentifier, byReference:Bool = false) {
		if (name == null) {
			throw "PHP closure capture requires a name";
		}
		this.name = name;
		this.byReference = byReference;
	}
}
