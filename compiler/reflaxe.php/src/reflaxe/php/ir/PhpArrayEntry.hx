package reflaxe.php.ir;

/** One value, with an optional key, in a native PHP array literal. **/
typedef PhpArrayEntry = {
	final key:Null<PhpExpr>;
	final value:PhpExpr;
}
