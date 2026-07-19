package reflaxe.php.ir;

/** A native PHP class or trait property. **/
class PhpProperty {
	public final visibility:PhpVisibility;
	public final isStatic:Bool;
	public final name:PhpIdentifier;
	public final defaultValue:Null<PhpExpr>;
	public final propertyType:Null<PhpType>;

	public function new(visibility:PhpVisibility, isStatic:Bool, name:PhpIdentifier, ?defaultValue:PhpExpr, ?propertyType:PhpType) {
		if (visibility == null || name == null) {
			throw "PHP property requires visibility and name";
		}
		if (propertyType != null) {
			switch propertyType {
				case PhpVoidType, PhpCallableType:
					throw "PHP properties cannot use void or callable types";
				case _:
			}
		}
		this.visibility = visibility;
		this.isStatic = isStatic;
		this.name = name;
		this.defaultValue = defaultValue;
		this.propertyType = propertyType;
	}
}
