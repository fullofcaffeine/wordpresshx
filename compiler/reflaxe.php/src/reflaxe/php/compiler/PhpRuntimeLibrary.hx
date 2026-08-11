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
	public static inline final INT32_IDENTITY = "runtime:int32";
	public static inline final INT32_PATH = "runtime/ReflaxePhpInt32Runtime.php";
	public static inline final INT32_CLASS = "\\ReflaxePhpInt32Runtime";

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

	/** Preserve Haxe's signed 32-bit `Int` result on the admitted 64-bit PHP profile. **/
	public static function int32Runtime(source:PhpSourceRange):PhpClass {
		if (source == null || !source.isExact) {
			throw "reflaxe.php Int32 runtime requires an exact triggering Haxe range";
		}
		final platformGuard = PhpIf(PhpBinop("!==", PhpConst("PHP_INT_SIZE"), PhpInt(8)), [
			PhpThrow(PhpNew("\\RuntimeException", [PhpString("reflaxe.php Int32 runtime requires 64-bit PHP")]))
		]);
		return new PhpClass(PhpClassKindClass, PhpIdentifier.named("ReflaxePhpInt32Runtime"), source, null, [], [], [
			new PhpMethod(PhpPublic, true, false, PhpIdentifier.named("add"), [
				PhpParameter.named(PhpIdentifier.named("left"), PhpIntType),
				PhpParameter.named(PhpIdentifier.named("right"), PhpIntType)
			],
				source, PhpIntType, [platformGuard, PhpReturn(wrap32(PhpBinop("+", PhpVar("left"), PhpVar("right"))))], "runtime:int32-add"),
			new PhpMethod(PhpPublic, true, false, PhpIdentifier.named("subtract"), [
				PhpParameter.named(PhpIdentifier.named("left"), PhpIntType),
				PhpParameter.named(PhpIdentifier.named("right"), PhpIntType)
			], source,
				PhpIntType, [platformGuard, PhpReturn(wrap32(PhpBinop("-", PhpVar("left"), PhpVar("right"))))], "runtime:int32-subtract")
		], "runtime:int32");
	}

	public static function isRuntimeIdentity(identity:String):Bool {
		return identity == STRING_IDENTITY || identity == INT32_IDENTITY;
	}

	static function wrap32(value:PhpExpr):PhpExpr {
		return PhpBinop(">>", PhpParenthesized(PhpBinop("<<", PhpParenthesized(value), PhpInt(32))), PhpInt(32));
	}
}
