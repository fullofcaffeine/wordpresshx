package reflaxe.php.ir;

/**
	Typed expressions admitted by the generic PHP printer.

	Names and operators are validated by `PhpPrinter`; constructors do not
	provide an unchecked textual PHP escape hatch.
**/
enum PhpExpr {
	PhpVar(name:String);
	PhpNull;
	PhpBool(value:Bool);
	PhpInt(value:Int);
	PhpString(value:String);
	PhpConst(name:String);
	PhpMagicConst(name:String);
	PhpArrayRead(base:PhpExpr, key:PhpExpr);
	PhpArrayAppend(base:PhpExpr);
	PhpLongArray(entries:Array<PhpArrayEntry>);
	PhpNew(className:String, args:Array<PhpExpr>);
	PhpNewDynamic(classExpr:PhpExpr, args:Array<PhpExpr>);
	PhpStaticCall(className:String, method:String, args:Array<PhpExpr>);
	PhpClassConst(className:String, constName:String);
	PhpStaticProperty(className:String, property:String);
	PhpMethodCall(target:PhpExpr, method:String, args:Array<PhpExpr>);
	PhpObjectProperty(target:PhpExpr, property:String);
	PhpDynamicObjectProperty(target:PhpExpr, property:PhpExpr);
	PhpFunctionCall(name:String, args:Array<PhpExpr>);

	/** Include a PHP projection and use its returned value. */
	PhpRequire(path:PhpExpr, once:Bool);

	PhpInvoke(callable:PhpExpr, args:Array<PhpExpr>);
	PhpCallableArray(target:PhpExpr, method:PhpIdentifier);
	PhpBinop(op:String, left:PhpExpr, right:PhpExpr);
	PhpInstanceOf(value:PhpExpr, className:String);
	PhpNullCoalesce(left:PhpExpr, right:PhpExpr);
	PhpTernary(condition:PhpExpr, ifTrue:PhpExpr, ifFalse:PhpExpr);
	PhpAssignExpr(target:PhpExpr, value:PhpExpr);
	PhpPostDecrement(target:PhpExpr);
	PhpStaticClosure(parameters:Array<String>, body:Array<PhpStmt>);
	PhpClosure(parameters:Array<PhpParameter>, captures:Array<PhpClosureCapture>, body:Array<PhpStmt>, isStatic:Bool, returnType:Null<PhpType>);
	PhpReference(expr:PhpExpr);
	PhpNot(expr:PhpExpr);
	PhpCastArray(expr:PhpExpr);
	PhpCastBool(expr:PhpExpr);
	PhpCastInt(expr:PhpExpr);
	PhpCastString(expr:PhpExpr);
}
