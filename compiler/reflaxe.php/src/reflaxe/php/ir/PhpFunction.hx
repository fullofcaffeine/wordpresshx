package reflaxe.php.ir;

/** A native namespace or global PHP function declaration. **/
class PhpFunction {
	public final returnsByReference:Bool;
	public final name:PhpIdentifier;
	public final returnType:Null<PhpType>;
	public final source:PhpSourceRange;
	public final semanticNodeId:Null<String>;

	final parameterValues:Array<PhpParameter>;
	final bodyValues:Array<PhpStmt>;

	public var parameters(get, never):Array<PhpParameter>;
	public var body(get, never):Array<PhpStmt>;

	public function new(returnsByReference:Bool, name:PhpIdentifier, parameters:Array<PhpParameter>, body:Array<PhpStmt>, source:PhpSourceRange,
			?returnType:PhpType, ?semanticNodeId:String) {
		if (name == null || parameters == null || body == null || source == null) {
			throw "PHP function requires name, parameters, body, and source";
		}
		for (statement in body) {
			if (statement == null) {
				throw "PHP function body cannot contain null";
			}
		}
		this.returnsByReference = returnsByReference;
		this.name = name;
		this.parameterValues = PhpParameter.validatedCopy(parameters);
		this.returnType = returnType;
		this.bodyValues = body.copy();
		this.source = source;
		this.semanticNodeId = semanticNodeId == null ? null : PhpStableId.validate(semanticNodeId, "function semantic node ID");
	}

	function get_parameters():Array<PhpParameter> {
		return parameterValues.copy();
	}

	function get_body():Array<PhpStmt> {
		return bodyValues.copy();
	}
}
