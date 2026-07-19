package reflaxe.php.ir;

/** A native PHP class, interface, or trait method. **/
class PhpMethod {
	public final visibility:PhpVisibility;
	public final isStatic:Bool;
	public final returnsByReference:Bool;
	public final name:PhpIdentifier;
	public final returnType:Null<PhpType>;
	public final source:PhpSourceRange;
	public final semanticNodeId:Null<String>;
	public final documentation:Null<PhpMethodDoc>;

	final parameterValues:Array<PhpParameter>;
	final bodyValues:Null<Array<PhpStmt>>;

	public var parameters(get, never):Array<PhpParameter>;
	public var body(get, never):Null<Array<PhpStmt>>;

	public function new(visibility:PhpVisibility, isStatic:Bool, returnsByReference:Bool, name:PhpIdentifier, parameters:Array<PhpParameter>,
			source:PhpSourceRange, ?returnType:PhpType, ?body:Array<PhpStmt>, ?semanticNodeId:String, ?documentation:PhpMethodDoc) {
		if (visibility == null || name == null || parameters == null || source == null) {
			throw "PHP method requires visibility, name, parameters, and source";
		}
		if (body != null) {
			for (statement in body) {
				if (statement == null) {
					throw "PHP method body cannot contain null";
				}
			}
		}
		this.visibility = visibility;
		this.isStatic = isStatic;
		this.returnsByReference = returnsByReference;
		this.name = name;
		this.parameterValues = PhpParameter.validatedCopy(parameters);
		this.returnType = returnType;
		this.bodyValues = body == null ? null : body.copy();
		this.source = source;
		this.semanticNodeId = semanticNodeId == null ? null : PhpStableId.validate(semanticNodeId, "method semantic node ID");
		if (documentation != null) {
			documentation.validateSignature(this.parameterValues);
		}
		this.documentation = documentation;
	}

	function get_parameters():Array<PhpParameter> {
		return parameterValues.copy();
	}

	function get_body():Null<Array<PhpStmt>> {
		return bodyValues == null ? null : bodyValues.copy();
	}
}
