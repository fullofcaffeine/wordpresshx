package reflaxe.php.compiler;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import reflaxe.data.ClassFuncData;

using reflaxe.helpers.ClassFieldHelper;
#end

/** Rejects unsupported application AST before Reflaxe's after-generation emission phase. **/
class PhpTypedAstValidator {
	#if macro
	public static function validateModules(moduleTypes:Array<ModuleType>):Void {
		PhpSemanticCapabilities.requireAdmitted(UnsupportedAstDiagnostic);
		final config = new PhpCompilerConfig();
		for (moduleType in moduleTypes) {
			switch (moduleType) {
				case TClassDecl(classRef):
					final classType = classRef.get();
					if (config.owns(classType.pos)) {
						validateClass(classType);
					}
				case TEnumDecl(enumRef):
					final enumType = enumRef.get();
					if (config.owns(enumType.pos)) {
						Context.error("reflaxe.php tracer does not yet support application enums", enumType.pos);
					}
				case _:
			}
		}
	}

	public static function validateClass(classType:ClassType):Void {
		validateFields(classType, classType.fields.get(), false);
		validateFields(classType, classType.statics.get(), true);
	}

	static function validateFields(classType:ClassType, fields:Array<ClassField>, isStatic:Bool):Void {
		for (field in fields) {
			switch (field.kind) {
				case FVar(_, _):
					Context.error("reflaxe.php tracer does not yet support application fields", field.pos);
				case FMethod(_):
					final functionData = field.findFuncData(classType, isStatic);
					if (functionData == null) {
						Context.error("reflaxe.php application method has no typed function data", field.pos);
					} else {
						validateMethod(functionData);
					}
			}
		}
	}

	static function validateMethod(functionData:ClassFuncData):Void {
		if (!functionData.isStatic) {
			Context.error("reflaxe.php tracer supports only static application methods", functionData.field.pos);
		}
		switch (TypeTools.toString(functionData.ret)) {
			case "Void":
				if (functionData.args.length != 0) {
					Context.error("reflaxe.php Void methods do not yet support parameters", functionData.field.pos);
				}
			case "Int":
				validateRequiredParameters(functionData, "Int");
			case "Bool":
				validateRequiredParameters(functionData, "Bool");
			case "String":
				validateRequiredParameters(functionData, "String");
			case _:
				Context.error("reflaxe.php supports only Void, Int, Bool, and String method returns in the admitted semantic slice", functionData.field.pos);
		}
		if (functionData.expr == null) {
			Context.error("reflaxe.php application methods require a typed body", functionData.field.pos);
			return;
		}
		validateStatement(functionData.expr, new Map<Int, Int>());
	}

	static function validateRequiredParameters(functionData:ClassFuncData, haxeType:String):Void {
		if (functionData.args.length == 0) {
			Context.error("reflaxe.php " + haxeType + "-returning methods currently require at least one " + haxeType + " parameter", functionData.field.pos);
		}
		for (argument in functionData.args) {
			if (argument.opt || argument.expr != null) {
				Context.error("reflaxe.php supports only required parameters without defaults", functionData.field.pos);
			}
			if (TypeTools.toString(argument.type) != haxeType) {
				Context.error("reflaxe.php supports only "
					+ haxeType
					+ " parameters for "
					+ haxeType
					+ "-returning methods in the admitted semantic slice",
					functionData.field.pos);
			}
		}
	}

	static function validateStatement(expression:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (expression.expr) {
			case TBlock(expressions):
				for (child in expressions) {
					validateStatement(child, intArrayLengths);
				}
			case TCall(target, arguments):
				validateCall(expression, target, arguments);
			case TVar(variable, initialValue):
				if (initialValue == null) {
					Context.error("reflaxe.php local bindings require an initial value", expression.pos);
				} else {
					switch (TypeTools.toString(variable.t)) {
						case "Int": validateIntValue(initialValue, intArrayLengths);
						case "Bool": validateBoolValue(initialValue);
						case "String": validateStringValue(initialValue);
						case "Array<Int>": validateIntArrayLiteral(variable, initialValue, intArrayLengths);
						case _:
							Context.error("reflaxe.php supports only Int, Bool, String, and Array<Int> local bindings in the admitted semantic slice",
								expression.pos);
					}
				}
			case TIf(condition, thenBranch, elseBranch):
				validateCondition(condition, intArrayLengths);
				validateStatement(thenBranch, intArrayLengths);
				if (elseBranch == null) {
					Context.error("reflaxe.php requires an else branch in the admitted semantic slice", expression.pos);
				} else {
					validateStatement(elseBranch, intArrayLengths);
				}
			case TWhile(condition, body, true):
				validateIntCondition(condition, intArrayLengths);
				validateStatement(body, intArrayLengths);
			case TWhile(_, _, false):
				Context.error("reflaxe.php does not yet support do-while loops", expression.pos);
			case TBinop(OpAssign, target, value):
				validateIntAssignment(expression, target, value, intArrayLengths);
			case TBinop(OpAssignOp(_), _, _):
				Context.error("reflaxe.php does not yet support compound assignment", expression.pos);
			case TReturn(null):
			case TReturn(value):
				switch (TypeTools.toString(value.t)) {
					case "Int": validateIntValue(value, intArrayLengths);
					case "Bool": validateBoolValue(value);
					case "String": validateStringValue(value);
					case _:
						Context.error("reflaxe.php supports only Int, Bool, and String return expressions in the admitted semantic slice", value.pos);
				}
			case TMeta(_, inner) | TParenthesis(inner):
				validateStatement(inner, intArrayLengths);
			case _:
				Context.error("reflaxe.php tracer does not support statement " + expression.expr.getName(), expression.pos);
		}
	}

	static function validateIntArrayLiteral(variable:TVar, initialValue:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (initialValue.expr) {
			case TArrayDecl(values):
				for (value in values) {
					validateIntValue(value, intArrayLengths);
				}
				intArrayLengths.set(variable.id, values.length);
			case _:
				Context.error("reflaxe.php supports only direct Array<Int> literals in the admitted semantic slice", initialValue.pos);
		}
	}

	static function validateIntAssignment(assignment:TypedExpr, target:TypedExpr, value:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (target.expr) {
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Int"):
				validateIntValue(value, intArrayLengths);
			case _:
				Context.error("reflaxe.php supports assignment only to Int variables in the admitted semantic slice", assignment.pos);
		}
	}

	static function validateCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (classRef.get().module == "Sys" && fieldRef.get().name == "println" && arguments.length == 1):
				validateStringValue(arguments[0]);
			case _:
				Context.error("reflaxe.php tracer supports only Sys.println with an admitted String expression", call.pos);
		}
	}

	static function validateStringValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TString(_)):
			case TLocal(variable) if (TypeTools.toString(variable.t) == "String"):
			case TBinop(OpAdd, left, right):
				if (TypeTools.toString(left.t) != "String" || TypeTools.toString(right.t) != "String") {
					Context.error("reflaxe.php String concatenation accepts only String operands; implicit coercion is not admitted", expression.pos);
				} else {
					validateStringValue(left);
					validateStringValue(right);
				}
			case TCall(target, arguments):
				validateStaticApplicationStringCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner):
				validateStringValue(inner);
			case _:
				Context.error("reflaxe.php supports only String literals, String locals, exact String concatenation, and source-owned static String calls without coercion",
					expression.pos);
		}
	}

	static function validateBoolValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TBool(_)):
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Bool"):
			case TUnop(OpNot, _, value):
				validateBoolValue(value);
			case TCall(target, arguments):
				validateStaticApplicationBoolCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner):
				validateBoolValue(inner);
			case _:
				Context.error("reflaxe.php supports only Bool literals, Bool locals, logical negation, and source-owned static Bool calls", expression.pos);
		}
	}

	static function validateIntValue(expression:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (expression.expr) {
			case TConst(TInt(_)):
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Int"):
			case TBinop(OpAdd, left, right):
				validateIntValue(left, intArrayLengths);
				validateIntValue(right, intArrayLengths);
			case TArray(base, index):
				validateProvenIntArrayRead(expression, base, index, intArrayLengths);
			case TCall(target, arguments):
				validateStaticApplicationIntCall(expression, target, arguments, intArrayLengths);
			case TMeta(_, inner) | TParenthesis(inner):
				validateIntValue(inner, intArrayLengths);
			case _:
				Context.error("reflaxe.php supports only admitted Int literals, locals, addition, proven array reads, and source-owned calls", expression.pos);
		}
	}

	static function validateProvenIntArrayRead(read:TypedExpr, base:TypedExpr, index:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch [base.expr, index.expr] {
			case [TLocal(variable), TConst(TInt(value))] if (intArrayLengths.exists(variable.id)):
				final length = intArrayLengths.get(variable.id);
				if (length == null || value < 0 || value >= length) {
					Context.error("reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant", read.pos);
				}
			case _:
				Context.error("reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant", read.pos);
		}
	}

	static function validateStaticApplicationIntCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>, intArrayLengths:Map<Int, Int>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, _)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "Int"):
				for (argument in arguments) {
					validateIntValue(argument, intArrayLengths);
				}
			case _:
				Context.error("reflaxe.php supports only source-owned static Int calls in the admitted semantic slice", call.pos);
		}
	}

	static function validateStaticApplicationStringCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, _)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "String"):
				for (argument in arguments) {
					validateStringValue(argument);
				}
			case _:
				Context.error("reflaxe.php supports only source-owned static String calls in the admitted semantic slice", call.pos);
		}
	}

	static function validateStaticApplicationBoolCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, _)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "Bool"):
				for (argument in arguments) {
					validateBoolValue(argument);
				}
			case _:
				Context.error("reflaxe.php supports only source-owned static Bool calls in the admitted semantic slice", call.pos);
		}
	}

	static function validateIntCondition(expression:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (expression.expr) {
			case TBinop(OpEq | OpLte, left, right):
				validateIntValue(left, intArrayLengths);
				validateIntValue(right, intArrayLengths);
			case TMeta(_, inner) | TParenthesis(inner):
				validateIntCondition(inner, intArrayLengths);
			case _:
				Context.error("reflaxe.php supports only Int equality and <= conditions in the admitted semantic slice", expression.pos);
		}
	}

	static function validateCondition(expression:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (expression.expr) {
			case TBinop(OpEq, left, right) if (TypeTools.toString(left.t) == "String" && TypeTools.toString(right.t) == "String"):
				validateStringValue(left);
				validateStringValue(right);
			case TBinop(OpEq | OpLte, left, right) if (TypeTools.toString(left.t) == "Int" && TypeTools.toString(right.t) == "Int"):
				validateIntCondition(expression, intArrayLengths);
			case _ if (TypeTools.toString(expression.t) == "Bool"):
				validateBoolValue(expression);
			case TMeta(_, inner) | TParenthesis(inner):
				validateCondition(inner, intArrayLengths);
			case _:
				Context.error("reflaxe.php supports only admitted Int, String, and Bool conditions", expression.pos);
		}
	}
	#end
}
