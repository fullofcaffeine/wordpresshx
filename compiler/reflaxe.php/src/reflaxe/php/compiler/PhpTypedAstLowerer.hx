package reflaxe.php.compiler;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
#end

/** The deliberately small first typed-Haxe AST to PHP IR lowering slice. **/
class PhpTypedAstLowerer {
	#if macro
	final sources:PhpSourceRegistry;

	public function new(sources:PhpSourceRegistry) {
		this.sources = sources;
	}

	public function lowerClass(classType:ClassType, varFields:Array<ClassVarData>, funcFields:Array<ClassFuncData>):PhpClass {
		PhpSemanticCapabilities.requireAdmitted(StaticClass);
		PhpTypedAstValidator.validateClass(classType);
		if (varFields.length != 0) {
			Context.fatalError("reflaxe.php tracer does not yet support application fields", classType.pos);
		}
		final orderedFunctions = funcFields.copy();
		orderedFunctions.sort((left, right) -> compareText(left.field.name, right.field.name));
		final methods = orderedFunctions.map(lowerMethod);
		return new PhpClass(PhpClassKindClass, PhpIdentifier.named(className(classType)), sources.range(classType.pos), null, [], [], methods,
			"class:"
			+ classType.module
			+ ":"
			+ classType.name);
	}

	public function className(classType:ClassType):String {
		final parts = classType.pack.concat([classType.name]);
		return "Hx_" + parts.map(part -> part.length + "_" + part).join("_");
	}

	function lowerMethod(functionData:ClassFuncData):PhpMethod {
		if (!functionData.isStatic) {
			Context.fatalError("reflaxe.php tracer supports only static application methods", functionData.field.pos);
		}
		final signature = lowerMethodSignature(functionData);
		if (functionData.expr == null) {
			Context.fatalError("reflaxe.php application methods require a typed body", functionData.field.pos);
			return unreachableMethod(functionData);
		}
		final body = lowerStatementList(functionData.expr, new Map<Int, Int>());
		return new PhpMethod(functionData.field.isPublic ? PhpPublic : PhpPrivate, true, false, PhpIdentifier.named(functionData.field.name),
			signature.parameters, sources.range(functionData.field.pos), signature.returnType, body,
			"method:"
			+ functionData.classType.module
			+ ":"
			+ functionData.field.name);
	}

	function lowerMethodSignature(functionData:ClassFuncData):{parameters:Array<PhpParameter>, returnType:PhpType} {
		return switch (TypeTools.toString(functionData.ret)) {
			case "Void":
				PhpSemanticCapabilities.requireAdmitted(StaticVoidNoArgMethod);
				if (functionData.args.length != 0) {
					Context.fatalError("reflaxe.php Void methods do not yet support parameters", functionData.field.pos);
				}
				{parameters: [], returnType: PhpVoidType};
			case "Int":
				PhpSemanticCapabilities.requireAdmitted(RequiredIntParameters);
				PhpSemanticCapabilities.requireAdmitted(IntReturn);
				if (functionData.args.length == 0) {
					Context.fatalError("reflaxe.php Int-returning methods currently require at least one Int parameter", functionData.field.pos);
				}
				final parameters = functionData.args.map(argument -> {
					if (argument.opt || argument.expr != null) {
						Context.fatalError("reflaxe.php supports only required parameters without defaults", functionData.field.pos);
					}
					if (TypeTools.toString(argument.type) != "Int") {
						Context.fatalError("reflaxe.php supports only Int parameters in the admitted semantic slice", functionData.field.pos);
					}
					PhpParameter.named(PhpIdentifier.named(argument.getName()), PhpIntType);
				});
				{parameters: parameters, returnType: PhpIntType};
			case _:
				Context.fatalError("reflaxe.php supports only Void and Int method returns in the admitted semantic slice", functionData.field.pos);
				{parameters: [], returnType: PhpVoidType};
		}
	}

	function lowerStatementList(expression:TypedExpr, intArrayLengths:Map<Int, Int>):Array<PhpStmt> {
		return switch (expression.expr) {
			case TBlock(expressions):
				final statements = new Array<PhpStmt>();
				for (child in expressions) {
					for (statement in lowerStatementList(child, intArrayLengths)) {
						statements.push(statement);
					}
				}
				statements;
			case TCall(target, arguments): [lowerCall(expression, target, arguments)];
			case TVar(variable, initialValue):
				if (initialValue == null) {
					Context.fatalError("reflaxe.php local bindings require an initial value", expression.pos);
					[];
				} else {
					switch (TypeTools.toString(variable.t)) {
						case "Int":
							PhpSemanticCapabilities.requireAdmitted(InitializedIntLocal);
							[
								mapped(PhpLocal(variable.name, lowerIntValue(initialValue, intArrayLengths)), expression, "local-int")
							];
						case "String":
							PhpSemanticCapabilities.requireAdmitted(InitializedStringLocal);
							[
								mapped(PhpLocal(variable.name, lowerStringValue(initialValue)), expression, "local-string")
							];
						case "Array<Int>":
							lowerIntArrayLocal(expression, variable, initialValue, intArrayLengths);
						case _:
							Context.fatalError("reflaxe.php supports only Int, String, and Array<Int> local bindings in the admitted semantic slice",
								expression.pos);
							[];
					}
				}
			case TIf(condition, thenBranch, elseBranch):
				PhpSemanticCapabilities.requireAdmitted(IfElse);
				if (elseBranch == null) {
					Context.fatalError("reflaxe.php requires an else branch in the admitted semantic slice", expression.pos);
					[];
				} else {
					final loweredCondition = lowerCondition(condition, intArrayLengths);
					[
						mapped(PhpIfElse(loweredCondition.expression, lowerStatementList(thenBranch, intArrayLengths),
							lowerStatementList(elseBranch, intArrayLengths)),
							expression, loweredCondition.mappingKind)
					];
				}
			case TWhile(condition, body, true):
				PhpSemanticCapabilities.requireAdmitted(WhileLoop);
				[
					mapped(PhpWhile(lowerIntCondition(condition, intArrayLengths), lowerStatementList(body, intArrayLengths)), expression, "while-int")
				];
			case TWhile(_, _, false):
				Context.fatalError("reflaxe.php does not yet support do-while loops", expression.pos);
				[];
			case TBinop(OpAssign, target, value): [lowerIntAssignment(expression, target, value, intArrayLengths)];
			case TBinop(OpAssignOp(_), _, _):
				Context.fatalError("reflaxe.php does not yet support compound assignment", expression.pos);
				[];
			case TReturn(null): [mapped(PhpReturnVoid, expression, "return")];
			case TReturn(value):
				PhpSemanticCapabilities.requireAdmitted(IntReturn);
				[
					mapped(PhpReturn(lowerIntValue(value, intArrayLengths)), expression, "return-int")
				];
			case TMeta(_, inner) | TParenthesis(inner): lowerStatementList(inner, intArrayLengths);
			case _:
				unsupportedStatement(expression);
		}
	}

	function lowerIntArrayLocal(expression:TypedExpr, variable:TVar, initialValue:TypedExpr, intArrayLengths:Map<Int, Int>):Array<PhpStmt> {
		return switch (initialValue.expr) {
			case TArrayDecl(values):
				PhpSemanticCapabilities.requireAdmitted(IntArrayLiteral);
				final entries:Array<PhpArrayEntry> = values.map(value -> {
					key: null,
					value: lowerIntValue(value, intArrayLengths)
				});
				intArrayLengths.set(variable.id, values.length);
				[
					mapped(PhpLocal(variable.name, PhpLongArray(entries)), expression, "local-int-array")
				];
			case _:
				Context.fatalError("reflaxe.php supports only direct Array<Int> literals in the admitted semantic slice", initialValue.pos);
				[];
		}
	}

	function lowerIntAssignment(assignment:TypedExpr, target:TypedExpr, value:TypedExpr, intArrayLengths:Map<Int, Int>):PhpStmt {
		return switch (target.expr) {
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Int"):
				PhpSemanticCapabilities.requireAdmitted(IntAssignment);
				mapped(PhpAssign(PhpVar(variable.name), lowerIntValue(value, intArrayLengths)), assignment, "assign-int");
			case _:
				Context.fatalError("reflaxe.php supports assignment only to Int variables in the admitted semantic slice", assignment.pos);
				PhpReturnVoid;
		}
	}

	function lowerCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpStmt {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (classRef.get().module == "Sys" && fieldRef.get().name == "println" && arguments.length == 1):
				PhpSemanticCapabilities.requireAdmitted(SysPrintlnString);
				final value = lowerStringValue(arguments[0]);
				mapped(PhpEcho(PhpBinop(".", value, PhpConst("PHP_EOL"))), call, "sys-println");
			case _:
				unsupportedCall(call);
		}
	}

	function lowerStringValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TString(value)):
				PhpSemanticCapabilities.requireAdmitted(StringLiteral);
				PhpSemanticCapabilities.requireAdmitted(Utf8StringLiteralRoundTrip);
				PhpString(value);
			case TLocal(variable) if (TypeTools.toString(variable.t) == "String"):
				PhpSemanticCapabilities.requireAdmitted(InitializedStringLocal);
				PhpVar(variable.name);
			case TBinop(OpAdd, left, right):
				if (TypeTools.toString(left.t) != "String" || TypeTools.toString(right.t) != "String") {
					Context.fatalError("reflaxe.php String concatenation accepts only String operands; implicit coercion is not admitted", expression.pos);
				}
				PhpSemanticCapabilities.requireAdmitted(StringConcatenation);
				PhpBinop(".", lowerStringValue(left), lowerStringValue(right));
			case TMeta(_, inner) | TParenthesis(inner): lowerStringValue(inner);
			case _: unsupportedStringValue(expression);
		}
	}

	function lowerIntValue(expression:TypedExpr, intArrayLengths:Map<Int, Int>):PhpExpr {
		return switch (expression.expr) {
			case TConst(TInt(value)):
				PhpSemanticCapabilities.requireAdmitted(IntLiteral);
				PhpInt(value);
			case TLocal(variable):
				PhpSemanticCapabilities.requireAdmitted(InitializedIntLocal);
				PhpVar(variable.name);
			case TBinop(OpAdd, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntAddition);
				PhpBinop("+", lowerIntValue(left, intArrayLengths), lowerIntValue(right, intArrayLengths));
			case TArray(base, index): lowerProvenIntArrayRead(expression, base, index, intArrayLengths);
			case TCall(target, arguments): lowerStaticApplicationIntCall(expression, target, arguments, intArrayLengths);
			case TMeta(_, inner) | TParenthesis(inner): lowerIntValue(inner, intArrayLengths);
			case _: unsupportedIntValue(expression);
		}
	}

	function lowerProvenIntArrayRead(read:TypedExpr, base:TypedExpr, index:TypedExpr, intArrayLengths:Map<Int, Int>):PhpExpr {
		return switch [base.expr, index.expr] {
			case [TLocal(variable), TConst(TInt(value))] if (intArrayLengths.exists(variable.id)):
				final length = intArrayLengths.get(variable.id);
				if (length == null || value < 0 || value >= length) {
					Context.fatalError("reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant", read.pos);
				}
				PhpSemanticCapabilities.requireAdmitted(ProvenIntArrayRead);
				PhpArrayRead(PhpVar(variable.name), PhpInt(value));
			case _:
				Context.fatalError("reflaxe.php Array<Int> index must be a compiler-proven in-bounds constant", read.pos);
				PhpInt(0);
		}
	}

	function lowerStaticApplicationIntCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>, intArrayLengths:Map<Int, Int>):PhpExpr {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (sources.owns(classRef.get().pos) && TypeTools.toString(call.t) == "Int"):
				PhpSemanticCapabilities.requireAdmitted(StaticApplicationCall);
				PhpStaticCall(className(classRef.get()), fieldRef.get().name, arguments.map(argument -> lowerIntValue(argument, intArrayLengths)));
			case _:
				Context.fatalError("reflaxe.php supports only source-owned static Int calls in the admitted semantic slice", call.pos);
				PhpInt(0);
		}
	}

	function lowerIntCondition(expression:TypedExpr, intArrayLengths:Map<Int, Int>):PhpExpr {
		return switch (expression.expr) {
			case TBinop(OpEq, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntEquality);
				PhpBinop("===", lowerIntValue(left, intArrayLengths), lowerIntValue(right, intArrayLengths));
			case TBinop(OpLte, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntLessOrEqual);
				PhpBinop("<=", lowerIntValue(left, intArrayLengths), lowerIntValue(right, intArrayLengths));
			case TMeta(_, inner) | TParenthesis(inner): lowerIntCondition(inner, intArrayLengths);
			case _: unsupportedIntCondition(expression);
		}
	}

	function lowerCondition(expression:TypedExpr, intArrayLengths:Map<Int, Int>):{expression:PhpExpr, mappingKind:String} {
		return switch (expression.expr) {
			case TBinop(OpEq, left, right) if (TypeTools.toString(left.t) == "String" && TypeTools.toString(right.t) == "String"):
				PhpSemanticCapabilities.requireAdmitted(StringEquality);
				{
					expression: PhpBinop("===", lowerStringValue(left), lowerStringValue(right)),
					mappingKind: "if-string-equality"
				};
			case TMeta(_, inner) | TParenthesis(inner): lowerCondition(inner, intArrayLengths);
			case _: {
					expression: lowerIntCondition(expression, intArrayLengths),
					mappingKind: "if-int-equality"
				};
		}
	}

	function mapped(statement:PhpStmt, expression:TypedExpr, kind:String):PhpStmt {
		final info = Context.getPosInfos(expression.pos);
		return PhpMapped(statement, sources.range(expression.pos), "stmt:" + kind + ":" + info.min + ":" + info.max, true);
	}

	function unsupportedStatement(expression:TypedExpr):Array<PhpStmt> {
		Context.fatalError("reflaxe.php tracer does not support statement " + expression.expr.getName(), expression.pos);
		return [];
	}

	function unsupportedCall(expression:TypedExpr):PhpStmt {
		Context.fatalError("reflaxe.php tracer supports only Sys.println with an admitted String expression", expression.pos);
		return PhpReturnVoid;
	}

	function unsupportedStringValue(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only String literals, String locals, and exact String concatenation without coercion", expression.pos);
		return PhpString("");
	}

	function unsupportedIntValue(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only admitted Int literals, locals, addition, proven array reads, and source-owned calls", expression.pos);
		return PhpInt(0);
	}

	function unsupportedIntCondition(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only Int equality and <= conditions in the admitted semantic slice", expression.pos);
		return PhpBool(false);
	}

	function unreachableMethod(functionData:ClassFuncData):PhpMethod {
		return new PhpMethod(PhpPrivate, true, false, PhpIdentifier.named(functionData.field.name), [], sources.range(functionData.field.pos), PhpVoidType,
			[], "method:unreachable:" + functionData.field.name);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
	#end
}
