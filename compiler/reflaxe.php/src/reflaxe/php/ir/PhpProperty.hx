package reflaxe.php.ir;

/** A native PHP class or trait property. **/
class PhpProperty {
	public final visibility:PhpVisibility;
	public final isStatic:Bool;
	public final name:PhpIdentifier;
	public final defaultValue:Null<PhpExpr>;

	public function new(visibility:PhpVisibility, isStatic:Bool, name:PhpIdentifier, ?defaultValue:PhpExpr) {
		if (visibility == null || name == null) {
			throw "PHP property requires visibility and name";
		}
		this.visibility = visibility;
		this.isStatic = isStatic;
		this.name = name;
		this.defaultValue = defaultValue;
	}
}
