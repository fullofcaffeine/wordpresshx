package reflaxe.php.ir;

/** A native PHP function, method, or closure parameter. **/
class PhpParameter {
	public final name:PhpIdentifier;
	public final type:Null<PhpType>;
	public final byReference:Bool;
	public final variadic:Bool;
	public final defaultValue:Null<PhpExpr>;

	private function new(name:PhpIdentifier, type:Null<PhpType>, byReference:Bool, variadic:Bool, defaultValue:Null<PhpExpr>) {
		if (name == null) {
			throw "PHP parameter requires a name";
		}
		if (variadic && defaultValue != null) {
			throw "Variadic PHP parameters cannot have default values";
		}
		this.name = name;
		this.type = type;
		this.byReference = byReference;
		this.variadic = variadic;
		this.defaultValue = defaultValue;
	}

	public static function named(name:PhpIdentifier, ?type:PhpType, byReference:Bool = false, variadic:Bool = false, ?defaultValue:PhpExpr):PhpParameter {
		return new PhpParameter(name, type, byReference, variadic, defaultValue);
	}

	public static function validatedCopy(values:Array<PhpParameter>):Array<PhpParameter> {
		if (values == null) {
			throw "PHP parameters cannot be null";
		}
		final names:Map<String, Bool> = [];
		for (index in 0...values.length) {
			final parameter = values[index];
			if (parameter == null) {
				throw "PHP parameters cannot contain null";
			}
			if (names.exists(parameter.name.value)) {
				throw "Duplicate PHP parameter: " + parameter.name.value;
			}
			if (parameter.variadic && index != values.length - 1) {
				throw "Variadic PHP parameter must be final: " + parameter.name.value;
			}
			names.set(parameter.name.value, true);
		}
		return values.copy();
	}
}
