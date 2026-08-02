package reflaxe.php.compiler;

import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;

/** Compiler-owned runtime declarations required by admitted ordinary-Haxe operations. **/
class PhpRuntimeLibrary {
	public static inline final STRING_IDENTITY = "runtime:string";
	public static inline final STRING_PATH = "runtime/ReflaxePhpStringRuntime.php";
	public static inline final STRING_CLASS = "\\ReflaxePhpStringRuntime";

	public static function stringRuntime(source:PhpSourceRange):PhpClass {
		if (source == null || !source.isExact) {
			throw "reflaxe.php String runtime requires an exact triggering Haxe range";
		}
		return new PhpClass(PhpClassKindClass, PhpIdentifier.named("ReflaxePhpStringRuntime"), source, null, [], [], [
			new PhpMethod(PhpPublic, true, false, PhpIdentifier.named("length"), [PhpParameter.named(PhpIdentifier.named("value"), PhpStringType)], source,
				PhpIntType, [
					PhpLocal("characters", PhpFunctionCall("\\preg_split", [PhpString("//u"), PhpVar("value"), PhpInt(-1), PhpConst("PREG_SPLIT_NO_EMPTY")])),
					PhpIf(PhpBinop("===", PhpVar("characters"), PhpBool(false)), [
						PhpThrow(PhpNew("\\RuntimeException", [PhpString("reflaxe.php String runtime received invalid UTF-8")]))
					]),
					PhpReturn(PhpFunctionCall("\\count", [PhpVar("characters")]))
				], "runtime:string-length")
		], "runtime:string");
	}
}
