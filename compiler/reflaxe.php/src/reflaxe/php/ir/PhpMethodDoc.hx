package reflaxe.php.ir;

/** Structured method documentation used only when native PHP 7.4 types are insufficient. */
class PhpMethodDoc {
	public final summary:String;
	public final returnType:Null<PhpDocType>;
	public final returnDescription:Null<String>;

	final parameterValues:Array<PhpDocParameter>;

	public var parameters(get, never):Array<PhpDocParameter>;

	public function new(summary:String, parameters:Array<PhpDocParameter>, ?returnType:PhpDocType, ?returnDescription:String) {
		this.summary = validateText(summary, "PHPDoc summary");
		if (parameters == null) {
			throw "PHPDoc parameters cannot be null";
		}
		final identities:Map<String, Bool> = [];
		for (parameter in parameters) {
			if (parameter == null) {
				throw "PHPDoc parameters cannot contain null";
			}
			if (identities.exists(parameter.name.value)) {
				throw "PHPDoc parameter names must be unique";
			}
			identities.set(parameter.name.value, true);
		}
		if ((returnType == null) != (returnDescription == null)) {
			throw "PHPDoc return type and description must be declared together";
		}
		this.parameterValues = parameters.copy();
		this.returnType = returnType;
		this.returnDescription = returnDescription == null ? null : validateText(returnDescription, "PHPDoc return description");
	}

	public function validateSignature(parameters:Array<PhpParameter>):Void {
		final names:Map<String, Bool> = [];
		for (parameter in parameters) {
			names.set(parameter.name.value, true);
		}
		for (parameter in parameterValues) {
			if (!names.exists(parameter.name.value)) {
				throw "PHPDoc refines an unknown method parameter: " + parameter.name.value;
			}
		}
	}

	function get_parameters():Array<PhpDocParameter> {
		return parameterValues.copy();
	}

	public static function validateText(value:String, label:String):String {
		if (value == null || value.length == 0 || value.indexOf("\n") >= 0 || value.indexOf("\r") >= 0 || value.indexOf("*/") >= 0) {
			throw label + " must be one safe non-empty line";
		}
		for (index in 0...value.length) {
			final code = value.charCodeAt(index);
			if (code < 32 || code == 127) {
				throw label + " contains a control character";
			}
		}
		return value;
	}
}
