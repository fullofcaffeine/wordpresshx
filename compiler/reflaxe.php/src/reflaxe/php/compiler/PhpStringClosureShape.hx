package reflaxe.php.compiler;

#if macro
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.TypedExprTools;
#end

#if macro
typedef PhpStringClosurePlan = {
	final functionData:TFunc;
	final captures:Array<TVar>;
}
#end

/** Closed analysis for the first required String-to-String lexical closure slice. **/
class PhpStringClosureShape {
	#if macro
	public static function isType(type:Type):Bool {
		return switch (TypeTools.follow(type)) {
			case TFun(arguments, result):
				arguments.length == 1
				&& !arguments[0].opt
				&& TypeTools.toString(arguments[0].t) == "String"
				&& TypeTools.toString(result) == "String";
			case _: false;
		}
	}

	public static function isFunctionType(type:Type):Bool {
		return switch (TypeTools.follow(type)) {
			case TFun(_, _): true;
			case _: false;
		}
	}

	public static function analyze(expression:TypedExpr):Null<PhpStringClosurePlan> {
		return switch (expression.expr) {
			case TFunction(functionData)
				if (functionData.args.length == 1
					&& functionData.args[0].value == null
					&& TypeTools.toString(functionData.args[0].v.t) == "String"
					&& TypeTools.toString(functionData.t) == "String"):
				analyzeFunction(functionData);
			case TMeta(_, inner) | TParenthesis(inner): analyze(inner);
			case _: null;
		}
	}

	static function analyzeFunction(functionData:TFunc):Null<PhpStringClosurePlan> {
		final localIds:Map<Int, Bool> = [];
		localIds.set(functionData.args[0].v.id, true);
		final captures:Map<Int, TVar> = [];
		if (!visit(functionData.expr, localIds, captures)) {
			return null;
		}
		final ordered = [for (capture in captures) capture];
		ordered.sort(compareVariables);
		return ordered.length > 0 ? {functionData: functionData, captures: ordered} : null;
	}

	static function visit(expression:TypedExpr, localIds:Map<Int, Bool>, captures:Map<Int, TVar>):Bool {
		return switch (expression.expr) {
			case TFunction(_) | TConst(TThis): false;
			case TVar(variable, initialValue):
				final initialValid = initialValue == null || visit(initialValue, localIds, captures);
				localIds.set(variable.id, true);
				initialValid;
			case TLocal(variable):
				if (localIds.exists(variable.id)) {
					true;
				} else if (TypeTools.toString(variable.t) == "String") {
					captures.set(variable.id, variable);
					true;
				} else {
					false;
				}
			case _:
				var valid = true;
				TypedExprTools.iter(expression, child -> {
					if (valid && !visit(child, localIds, captures)) {
						valid = false;
					}
				});
				valid;
		}
	}

	static function compareVariables(left:TVar, right:TVar):Int {
		return left.name < right.name ? -1 : left.name > right.name ? 1 : left.id - right.id;
	}
	#end
}
