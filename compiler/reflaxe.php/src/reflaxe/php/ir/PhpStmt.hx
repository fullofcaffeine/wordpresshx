package reflaxe.php.ir;

/** Typed statements admitted by the generic PHP printer. **/
enum PhpStmt {
	PhpIf(condition:PhpExpr, body:Array<PhpStmt>);
	PhpIfElse(condition:PhpExpr, body:Array<PhpStmt>, elseBody:Array<PhpStmt>);
	PhpFor(init:PhpExpr, condition:PhpExpr, update:PhpExpr, body:Array<PhpStmt>);
	PhpForeach(iterable:PhpExpr, valueVar:String, body:Array<PhpStmt>);
	PhpForeachKeyValue(iterable:PhpExpr, keyVar:String, valueVar:String, body:Array<PhpStmt>);
	PhpTryCatch(tryBody:Array<PhpStmt>, catchType:String, catchVar:String, catchBody:Array<PhpStmt>);
	PhpAssign(target:PhpExpr, value:PhpExpr);
	PhpListAssign(names:Array<String>, value:PhpExpr);
	PhpGlobal(names:Array<String>);
	PhpLocal(name:String, value:PhpExpr);
	PhpStaticLocal(name:String, value:PhpExpr);
	PhpExprStmt(expr:PhpExpr);
	PhpEcho(expr:PhpExpr);
	PhpRequireOnce(path:PhpExpr);
	PhpReturn(value:PhpExpr);
	PhpReturnVoid;
	PhpThrow(value:PhpExpr);
	PhpUnset(target:PhpExpr);
	PhpBreak;
	PhpContinue;
}
