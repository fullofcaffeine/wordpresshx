package reflaxe.php.compiler;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import reflaxe.data.ClassFuncData;
import reflaxe.php.ir.PhpIdentifier;

using reflaxe.helpers.ClassFieldHelper;

private typedef PhpExceptionValidationState = {
	var tryCount:Int;
	final methodLocalNames:Map<String, Bool>;
}
#end

/** Rejects unsupported application AST before Reflaxe's after-generation emission phase. **/
class PhpTypedAstValidator {
	#if macro
	public static function nativeGlobalName(classType:ClassType, field:ClassField):Null<String> {
		final matches = field.meta.get().filter(entry -> entry.name == ":phpGlobalFunction");
		if (matches.length == 0) {
			return null;
		}
		if (matches.length != 1) {
			Context.fatalError("reflaxe.php native global functions require exactly one @:phpGlobalFunction annotation", field.pos);
		}
		if (!classType.isExtern || !field.isPublic) {
			Context.fatalError("reflaxe.php @:phpGlobalFunction is allowed only on public static extern methods", field.pos);
		}
		final entry = matches[0];
		if (entry.params.length != 1) {
			Context.fatalError("reflaxe.php @:phpGlobalFunction requires one literal PHP function name", entry.pos);
		}
		final name = switch (entry.params[0].expr) {
			case EConst(CString(value, _)): value;
			case _:
				Context.fatalError("reflaxe.php @:phpGlobalFunction requires one literal PHP function name", entry.params[0].pos);
				"";
		}
		try {
			PhpIdentifier.named(name);
		} catch (_:String) {
			Context.fatalError("reflaxe.php @:phpGlobalFunction contains an invalid PHP function name", entry.params[0].pos);
		}
		return "\\" + name;
	}

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
		if (classType.superClass != null || classType.interfaces.length != 0) {
			Context.error("reflaxe.php instance layout does not yet support inheritance or interfaces", classType.pos);
		}
		if (classType.constructor != null) {
			final constructorData = classType.constructor.get().findFuncData(classType, false);
			if (constructorData == null) {
				Context.error("reflaxe.php application constructor has no typed function data", classType.constructor.get().pos);
			} else {
				validateMethod(constructorData);
			}
		}
		validateFields(classType, classType.fields.get(), false);
		validateFields(classType, classType.statics.get(), true);
	}

	static function validateFields(classType:ClassType, fields:Array<ClassField>, isStatic:Bool):Void {
		for (field in fields) {
			switch (field.kind) {
				case FVar(_, write):
					if (isStatic || field.isPublic || TypeTools.toString(field.type) != "String") {
						Context.error("reflaxe.php supports only private instance String fields in the admitted instance-layout slice", field.pos);
					}
					if (field.hasDefaultValue()) {
						Context.error("reflaxe.php instance fields do not yet support declaration initializers", field.pos);
					}
					switch (write) {
						case AccCtor:
						case _:
							Context.error("reflaxe.php instance fields must be constructor-initialized and immutable after construction", field.pos);
					}
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
		final isConstructor = functionData.field.name == "new";
		if (isConstructor) {
			if (functionData.isStatic || TypeTools.toString(functionData.ret) != "Void" || functionData.args.length == 0) {
				Context.error("reflaxe.php constructors require at least one required String parameter", functionData.field.pos);
			}
			validateRequiredParameters(functionData, "String");
		} else if (!functionData.isStatic && TypeTools.toString(functionData.ret) != "String") {
			Context.error("reflaxe.php supports only String-returning instance methods in the admitted instance-layout slice", functionData.field.pos);
		}
		if (!isConstructor)
			switch (TypeTools.toString(functionData.ret)) {
				case "Void":
					if (functionData.args.length != 0) {
						Context.error("reflaxe.php Void methods do not yet support parameters", functionData.field.pos);
					}
				case "Int":
					validateRequiredParameters(functionData, "Int");
				case "Bool":
					validateRequiredParameters(functionData, hasRequiredNullableStringParameter(functionData) ? "Null<String>" : "Bool");
				case "String":
					validateRequiredParameters(functionData, "String");
				case "Null<String>":
					if (!hasRequiredNullableStringParameter(functionData)) {
						Context.error("reflaxe.php nullable String returns require exactly one required Null<String> parameter", functionData.field.pos);
					} else {
						validateRequiredParameters(functionData, "Null<String>");
					}
				case _:
					Context.error("reflaxe.php supports only Void, Int, Bool, String, and Null<String> method returns in the admitted semantic slice",
						functionData.field.pos);
			}
		if (functionData.expr == null) {
			Context.error("reflaxe.php application methods require a typed body", functionData.field.pos);
			return;
		}
		final methodLocalNames:Map<String, Bool> = [];
		for (argument in functionData.args) {
			methodLocalNames.set(argument.getName(), true);
		}
		validateStatement(functionData.expr, new Map<Int, Int>(), {tryCount: 0, methodLocalNames: methodLocalNames}, true);
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

	static function validateStatement(expression:TypedExpr, intArrayLengths:Map<Int, Int>, exceptionState:PhpExceptionValidationState,
			allowDirectArrayMutation:Bool):Void {
		switch (expression.expr) {
			case TBlock(expressions):
				for (child in expressions) {
					validateStatement(child, intArrayLengths, exceptionState, allowDirectArrayMutation);
				}
			case TCall(target, arguments):
				if (!tryValidateIntArrayPush(expression, target, arguments, intArrayLengths, allowDirectArrayMutation)) {
					validateCall(expression, target, arguments);
				}
			case TVar(variable, initialValue):
				reserveMethodLocalName(variable.name, expression, exceptionState);
				if (initialValue == null) {
					Context.error("reflaxe.php local bindings require an initial value", expression.pos);
				} else {
					switch (TypeTools.toString(variable.t)) {
						case "Int": validateIntValue(initialValue, intArrayLengths);
						case "Bool": validateBoolValue(initialValue);
						case "String": validateStringValue(initialValue);
						case "Null<String>": validateNullableStringValue(initialValue);
						case "Array<Int>": validateIntArrayLiteral(variable, initialValue, intArrayLengths);
						case _:
							if (PhpStringClosureShape.isType(variable.t)) {
								validateStringClosure(initialValue, exceptionState);
							} else if (PhpStringClosureShape.isFunctionType(variable.t)) {
								Context.error("reflaxe.php supports only required unary String closures with read-only String captures", expression.pos);
							} else if (ownedClass(variable.t) == null) {
								Context.error("reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings", expression.pos);
							} else {
								validateObjectValue(initialValue);
							}
					}
				}
			case TIf(condition, thenBranch, elseBranch):
				validateCondition(condition, intArrayLengths);
				validateStatement(thenBranch, intArrayLengths, exceptionState, false);
				if (elseBranch == null) {
					Context.error("reflaxe.php requires an else branch in the admitted semantic slice", expression.pos);
				} else {
					validateStatement(elseBranch, intArrayLengths, exceptionState, false);
				}
			case TWhile(condition, body, true):
				validateIntCondition(condition, intArrayLengths);
				validateStatement(body, intArrayLengths, exceptionState, false);
			case TWhile(_, _, false):
				Context.error("reflaxe.php does not yet support do-while loops", expression.pos);
			case TBinop(OpAssign, target, value):
				switch (target.expr) {
					case TField(receiver, FInstance(classRef, _, fieldRef))
						if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(fieldRef.get().type) == "String"):
						validateObjectValue(receiver);
						validateStringValue(value);
					case _: validateIntAssignment(expression, target, value, intArrayLengths);
				}
			case TBinop(OpAssignOp(_), _, _):
				Context.error("reflaxe.php does not yet support compound assignment", expression.pos);
			case TReturn(null):
			case TReturn(value):
				switch (TypeTools.toString(value.t)) {
					case "Int": validateIntValue(value, intArrayLengths);
					case "Bool": validateBoolValue(value);
					case "String": validateStringValue(value);
					case "Null<String>": validateNullableStringValue(value);
					case _:
						Context.error("reflaxe.php supports only Int, Bool, String, and Null<String> return expressions in the admitted semantic slice",
							value.pos);
				}
			case TTry(tryExpression, catches):
				validateHaxeExceptionTry(expression, tryExpression, catches, intArrayLengths, exceptionState);
			case TMeta(_, inner) | TParenthesis(inner):
				validateStatement(inner, intArrayLengths, exceptionState, allowDirectArrayMutation);
			case _:
				Context.error("reflaxe.php tracer does not support statement " + expression.expr.getName(), expression.pos);
		}
	}

	/** Validates one straight-line push and advances the exact local array length used by later bounds checks. */
	static function tryValidateIntArrayPush(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>, intArrayLengths:Map<Int, Int>,
			allowDirectArrayMutation:Bool):Bool {
		if (!isIntArrayPushTarget(target)) {
			return false;
		}
		if (!allowDirectArrayMutation) {
			Context.error("reflaxe.php Array<Int>.push is admitted only as a direct straight-line statement", call.pos);
			return true;
		}
		if (arguments.length != 1) {
			Context.error("reflaxe.php Array<Int>.push requires exactly one Int value", call.pos);
			return true;
		}
		final receiver = switch (target.expr) {
			case TField(value, _): value;
			case _: return false;
		}
		switch (receiver.expr) {
			case TLocal(variable) if (intArrayLengths.exists(variable.id)):
				validateIntValue(arguments[0], intArrayLengths);
				final length = intArrayLengths.get(variable.id);
				if (length == null) {
					Context.error("reflaxe.php Array<Int>.push requires a compiler-owned non-null Array<Int> local", call.pos);
				} else {
					intArrayLengths.set(variable.id, length + 1);
				}
			case _:
				Context.error("reflaxe.php Array<Int>.push requires a compiler-owned non-null Array<Int> local", call.pos);
		}
		return true;
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
			case TField(_, FStatic(classRef, fieldRef)) if (nativeGlobalName(classRef.get(), fieldRef.get()) != null):
				for (argument in arguments) {
					validateStringValue(argument);
				}
			case _:
				Context.error("reflaxe.php tracer supports only Sys.println or a typed @:phpGlobalFunction extern call with admitted String arguments",
					call.pos);
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
				switch (target.expr) {
					case TField(receiver, FInstance(classRef, _, fieldRef))
						if (isHaxeExceptionClass(classRef.get()) && fieldRef.get().name == "get_message" && arguments.length == 0):
						validateCaughtExceptionReceiver(receiver);
					case _:
						validateStaticApplicationStringCall(expression, target, arguments);
				}
			case TField(receiver, FInstance(classRef, _, fieldRef)) if (isHaxeExceptionClass(classRef.get())
				&& fieldRef.get().name == "message"):
				validateCaughtExceptionReceiver(receiver);
			case TField(receiver, FInstance(classRef, _, fieldRef))
				if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(fieldRef.get().type) == "String"):
				validateObjectValue(receiver);
			case TMeta(_, inner) | TParenthesis(inner):
				validateStringValue(inner);
			case _:
				Context.error("reflaxe.php supports only String literals, String locals, exact String concatenation, and source-owned static String calls without coercion",
					expression.pos);
		}
	}

	static function validateStringClosure(expression:TypedExpr, exceptionState:PhpExceptionValidationState):Void {
		final plan = PhpStringClosureShape.analyze(expression);
		if (plan == null) {
			Context.error("reflaxe.php supports only required unary String closures with read-only String captures", expression.pos);
			return;
		}
		validateStatement(plan.functionData.expr, new Map<Int, Int>(), exceptionState, false);
	}

	static function validateHaxeExceptionTry(expression:TypedExpr, tryExpression:TypedExpr, catches:Array<{v:TVar, expr:TypedExpr}>,
			intArrayLengths:Map<Int, Int>, exceptionState:PhpExceptionValidationState):Void {
		if (exceptionState.tryCount != 0) {
			Context.error("reflaxe.php supports only one non-nested haxe.Exception try/catch per method", expression.pos);
		}
		if (catches.length != 1 || !isHaxeExceptionType(catches[0].v.t)) {
			Context.error("reflaxe.php supports exactly one haxe.Exception catch", expression.pos);
		}
		exceptionState.tryCount++;
		reserveMethodLocalName(catches[0].v.name, catches[0].expr, exceptionState);
		switch (tryExpression.expr) {
			case TBlock([throwExpression]):
				switch (throwExpression.expr) {
					case TThrow(value): validateHaxeExceptionThrow(value);
					case _:
						Context.error("reflaxe.php exception try blocks require one immediate haxe.Exception throw", tryExpression.pos);
				}
			case _:
				Context.error("reflaxe.php exception try blocks require one immediate haxe.Exception throw", tryExpression.pos);
		}
		validateStatement(catches[0].expr, intArrayLengths, exceptionState, false);
	}

	static function validateHaxeExceptionThrow(value:TypedExpr):Void {
		switch (value.expr) {
			case TNew(classRef, _, arguments) if (isHaxeExceptionClass(classRef.get()) && arguments.length == 1):
				validateStringValue(arguments[0]);
			case _:
				Context.error("reflaxe.php supports throwing only a new haxe.Exception with one admitted String message", value.pos);
		}
	}

	static function validateCaughtExceptionReceiver(receiver:TypedExpr):Void {
		switch (receiver.expr) {
			case TLocal(variable) if (isHaxeExceptionType(variable.t)):
			case _:
				Context.error("reflaxe.php reads exception messages only from the exact caught haxe.Exception local", receiver.pos);
		}
	}

	static function reserveMethodLocalName(name:String, expression:TypedExpr, exceptionState:PhpExceptionValidationState):Void {
		if (exceptionState.methodLocalNames.exists(name)) {
			Context.error("reflaxe.php requires unique method-local PHP names across Haxe lexical scopes", expression.pos);
		}
		exceptionState.methodLocalNames.set(name, true);
	}

	static function validateBoolValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TBool(_)):
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Bool"):
			case TUnop(OpNot, _, value):
				validateBoolValue(value);
			case TBinop(OpBoolAnd | OpBoolOr, left, right):
				validateBoolValue(left);
				validateBoolValue(right);
			case TBinop(OpEq | OpNotEq, left, right):
				validateNullableStringNullCheck(expression, left, right);
			case TCall(target, arguments):
				validateStaticApplicationBoolCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner):
				validateBoolValue(inner);
			case _:
				Context.error("reflaxe.php supports only Bool literals, Bool locals, logical negation, lazy Bool conjunction/disjunction, and source-owned static Bool calls",
					expression.pos);
		}
	}

	static function validateNullableStringValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TNull | TString(_)):
			case TLocal(variable) if (isNullableStringType(variable.t)):
			case TCall(target, arguments):
				validateStaticApplicationNullableStringReturnCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner):
				validateNullableStringValue(inner);
			case _:
				Context.error("reflaxe.php nullable String values support only null, String literals, and exact Null<String> locals", expression.pos);
		}
	}

	static function validateStaticApplicationNullableStringReturnCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef))
				if (new PhpCompilerConfig().owns(classRef.get().pos)
					&& isRequiredNullableStringReturnField(classRef.get(), fieldRef.get())):
				if (arguments.length != 1) {
					Context.error("reflaxe.php nullable String return calls require exactly one argument", call.pos);
				} else {
					validateNullableStringValue(arguments[0]);
				}
			case _:
				Context.error("reflaxe.php supports only source-owned nullable String return calls in the admitted semantic slice", call.pos);
		}
	}

	static function validateNullableStringNullCheck(expression:TypedExpr, left:TypedExpr, right:TypedExpr):Void {
		if (isNullableStringLocal(left) && isNullLiteral(right)) {
			return;
		}
		Context.error("reflaxe.php nullable String checks require an exact Null<String> local on the left and null on the right", expression.pos);
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
			case TField(receiver, FInstance(classRef, _, fieldRef)) if (isStringClass(classRef.get()) && fieldRef.get().name == "length"):
				validateStringValue(receiver);
			case TField(receiver, FInstance(classRef, _, fieldRef)) if (isArrayClass(classRef.get()) && fieldRef.get().name == "length"):
				validateProvenIntArrayLength(expression, receiver, intArrayLengths);
			case TCall(target, arguments):
				if (isIntArrayPushTarget(target)) {
					Context.error("reflaxe.php Array<Int>.push return values are not yet admitted", expression.pos);
				} else {
					validateStaticApplicationIntCall(expression, target, arguments, intArrayLengths);
				}
			case TMeta(_, inner) | TParenthesis(inner):
				validateIntValue(inner, intArrayLengths);
			case _:
				Context.error("reflaxe.php supports only admitted Int literals, locals, addition, proven array reads, and source-owned calls", expression.pos);
		}
	}

	static function isStringClass(classType:ClassType):Bool {
		return classType.pack.length == 0 && classType.name == "String";
	}

	static function isArrayClass(classType:ClassType):Bool {
		return classType.pack.length == 0 && classType.name == "Array";
	}

	static function isIntArrayPushTarget(target:TypedExpr):Bool {
		return switch (target.expr) {
			case TField(_, FInstance(classRef, _, fieldRef)): isArrayClass(classRef.get()) && fieldRef.get().name == "push";
			case _: false;
		}
	}

	static function validateProvenIntArrayLength(read:TypedExpr, receiver:TypedExpr, intArrayLengths:Map<Int, Int>):Void {
		switch (receiver.expr) {
			case TLocal(variable) if (intArrayLengths.exists(variable.id)):
			case _:
				Context.error("reflaxe.php Array<Int> length requires a compiler-owned non-null Array<Int> local", read.pos);
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
			case TLocal(_) if (PhpStringClosureShape.isType(target.t) && TypeTools.toString(call.t) == "String"):
				if (arguments.length != 1) {
					Context.error("reflaxe.php String closures require exactly one String argument", call.pos);
				} else {
					validateStringValue(arguments[0]);
				}
			case TField(_, FStatic(classRef, _)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "String"):
				for (argument in arguments) {
					validateStringValue(argument);
				}
			case TField(receiver, FInstance(classRef, _, _)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "String"):
				validateObjectValue(receiver);
				for (argument in arguments) {
					validateStringValue(argument);
				}
			case _:
				Context.error("reflaxe.php supports only source-owned static String calls in the admitted semantic slice", call.pos);
		}
	}

	static function validateObjectValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TThis):
			case TLocal(variable) if (ownedClass(variable.t) != null):
			case TNew(classRef, _, arguments) if (new PhpCompilerConfig().owns(classRef.get().pos)):
				for (argument in arguments) {
					validateStringValue(argument);
				}
			case TMeta(_, inner) | TParenthesis(inner):
				validateObjectValue(inner);
			case _:
				Context.error("reflaxe.php supports only this, source-owned object locals, and source-owned construction", expression.pos);
		}
	}

	static function ownedClass(type:Type):Null<ClassType> {
		return switch (TypeTools.follow(type)) {
			case TInst(classRef, _):
				final classType = classRef.get();
				new PhpCompilerConfig().owns(classType.pos) ? classType : null;
			case _: null;
		}
	}

	static function isHaxeExceptionType(type:Type):Bool {
		return switch (TypeTools.follow(type)) {
			case TInst(classRef, _): isHaxeExceptionClass(classRef.get());
			case _: false;
		}
	}

	static function isHaxeExceptionClass(classType:ClassType):Bool {
		return classType.pack.join(".") == "haxe" && classType.name == "Exception";
	}

	static function validateStaticApplicationBoolCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (new PhpCompilerConfig().owns(classRef.get().pos) && TypeTools.toString(call.t) == "Bool"):
				if (isRequiredNullableStringBoolField(classRef.get(), fieldRef.get())) {
					if (arguments.length != 1) {
						Context.error("reflaxe.php nullable String Bool calls require exactly one argument", call.pos);
					} else {
						validateNullableStringValue(arguments[0]);
					}
				} else {
					for (argument in arguments) {
						validateBoolValue(argument);
					}
				}
			case _:
				Context.error("reflaxe.php supports only source-owned static Bool calls in the admitted semantic slice", call.pos);
		}
	}

	static function hasRequiredNullableStringParameter(functionData:ClassFuncData):Bool {
		return functionData.args.length == 1 && isNullableStringType(functionData.args[0].type);
	}

	static function isRequiredNullableStringBoolField(classType:ClassType, field:ClassField):Bool {
		final functionData = field.findFuncData(classType, true);
		return functionData != null && TypeTools.toString(functionData.ret) == "Bool" && hasRequiredNullableStringParameter(functionData);
	}

	static function isRequiredNullableStringReturnField(classType:ClassType, field:ClassField):Bool {
		final functionData = field.findFuncData(classType, true);
		return functionData != null && isNullableStringType(functionData.ret) && hasRequiredNullableStringParameter(functionData);
	}

	static function isNullableStringType(type:Type):Bool {
		return TypeTools.toString(type) == "Null<String>";
	}

	static function isNullableStringLocal(expression:TypedExpr):Bool {
		return switch (expression.expr) {
			case TLocal(variable): isNullableStringType(variable.t);
			case TMeta(_, inner) | TParenthesis(inner): isNullableStringLocal(inner);
			case _: false;
		}
	}

	static function isNullLiteral(expression:TypedExpr):Bool {
		return switch (expression.expr) {
			case TConst(TNull): true;
			case TMeta(_, inner) | TParenthesis(inner): isNullLiteral(inner);
			case _: false;
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
