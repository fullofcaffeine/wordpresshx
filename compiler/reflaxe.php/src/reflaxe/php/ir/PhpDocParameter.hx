package reflaxe.php.ir;

/** One validated PHPDoc parameter refinement. */
class PhpDocParameter {
	public final name:PhpIdentifier;
	public final type:PhpDocType;
	public final description:String;

	public function new(name:PhpIdentifier, type:PhpDocType, description:String) {
		if (name == null || type == null) {
			throw "PHPDoc parameter requires a name and type";
		}
		this.name = name;
		this.type = type;
		this.description = PhpMethodDoc.validateText(description, "PHPDoc parameter description");
	}
}
