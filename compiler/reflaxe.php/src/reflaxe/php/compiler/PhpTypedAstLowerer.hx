package reflaxe.php.compiler;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
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
		final body = lowerStatementList(functionData.expr);
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

	function lowerStatementList(expression:TypedExpr):Array<PhpStmt> {
		return switch (expression.expr) {
			case TBlock(expressions):
				final statements = new Array<PhpStmt>();
				for (child in expressions) {
					for (statement in lowerStatementList(child)) {
						statements.push(statement);
					}
				}
				statements;
			case TCall(target, arguments): [lowerCall(expression, target, arguments)];
			case TVar(variable, initialValue):
				PhpSemanticCapabilities.requireAdmitted(InitializedIntLocal);
				if (initialValue == null) {
					Context.fatalError("reflaxe.php local bindings require an initial value", expression.pos);
					[];
				} else {
					[
						mapped(PhpLocal(variable.name, lowerIntValue(initialValue)), expression, "local-int")
					];
				}
			case TIf(condition, thenBranch, elseBranch):
				PhpSemanticCapabilities.requireAdmitted(IfElse);
				if (elseBranch == null) {
					Context.fatalError("reflaxe.php requires an else branch in the admitted semantic slice", expression.pos);
					[];
				} else {
					[
						mapped(PhpIfElse(lowerIntCondition(condition), lowerStatementList(thenBranch), lowerStatementList(elseBranch)), expression,
							"if-int-equality")
					];
				}
			case TWhile(condition, body, true):
				PhpSemanticCapabilities.requireAdmitted(WhileLoop);
				[
					mapped(PhpWhile(lowerIntCondition(condition), lowerStatementList(body)), expression, "while-int")
				];
			case TWhile(_, _, false):
				Context.fatalError("reflaxe.php does not yet support do-while loops", expression.pos);
				[];
			case TBinop(OpAssign, target, value): [lowerIntAssignment(expression, target, value)];
			case TBinop(OpAssignOp(_), _, _):
				Context.fatalError("reflaxe.php does not yet support compound assignment", expression.pos);
				[];
			case TReturn(null): [mapped(PhpReturnVoid, expression, "return")];
			case TReturn(value):
				PhpSemanticCapabilities.requireAdmitted(IntReturn);
				[mapped(PhpReturn(lowerIntValue(value)), expression, "return-int")];
			case TMeta(_, inner) | TParenthesis(inner): lowerStatementList(inner);
			case _:
				unsupportedStatement(expression);
		}
	}

	function lowerIntAssignment(assignment:TypedExpr, target:TypedExpr, value:TypedExpr):PhpStmt {
		return switch (target.expr) {
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Int"):
				PhpSemanticCapabilities.requireAdmitted(IntAssignment);
				mapped(PhpAssign(PhpVar(variable.name), lowerIntValue(value)), assignment, "assign-int");
			case _:
				Context.fatalError("reflaxe.php supports assignment only to Int variables in the admitted semantic slice", assignment.pos);
				PhpReturnVoid;
		}
	}

	function lowerCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpStmt {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (classRef.get().module == "Sys" && fieldRef.get().name == "println" && arguments.length == 1):
				PhpSemanticCapabilities.requireAdmitted(SysPrintlnString);
				final value = lowerValue(arguments[0]);
				mapped(PhpEcho(PhpBinop(".", value, PhpConst("PHP_EOL"))), call, "sys-println");
			case _:
				unsupportedCall(call);
		}
	}

	function lowerValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TString(value)):
				PhpSemanticCapabilities.requireAdmitted(StringLiteral);
				PhpString(value);
			case TMeta(_, inner) | TParenthesis(inner): lowerValue(inner);
			case _: unsupportedValue(expression);
		}
	}

	function lowerIntValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TInt(value)):
				PhpSemanticCapabilities.requireAdmitted(IntLiteral);
				PhpInt(value);
			case TLocal(variable):
				PhpSemanticCapabilities.requireAdmitted(InitializedIntLocal);
				PhpVar(variable.name);
			case TBinop(OpAdd, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntAddition);
				PhpBinop("+", lowerIntValue(left), lowerIntValue(right));
			case TCall(target, arguments): lowerStaticApplicationIntCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner): lowerIntValue(inner);
			case _: unsupportedValue(expression);
		}
	}

	function lowerStaticApplicationIntCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpExpr {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (sources.owns(classRef.get().pos) && TypeTools.toString(call.t) == "Int"):
				PhpSemanticCapabilities.requireAdmitted(StaticApplicationCall);
				PhpStaticCall(className(classRef.get()), fieldRef.get().name, arguments.map(lowerIntValue));
			case _:
				Context.fatalError("reflaxe.php supports only source-owned static Int calls in the admitted semantic slice", call.pos);
				PhpInt(0);
		}
	}

	function lowerIntCondition(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TBinop(OpEq, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntEquality);
				PhpBinop("===", lowerIntValue(left), lowerIntValue(right));
			case TBinop(OpLte, left, right):
				PhpSemanticCapabilities.requireAdmitted(IntLessOrEqual);
				PhpBinop("<=", lowerIntValue(left), lowerIntValue(right));
			case TMeta(_, inner) | TParenthesis(inner): lowerIntCondition(inner);
			case _: unsupportedValue(expression);
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
		Context.fatalError("reflaxe.php tracer supports only Sys.println(String)", expression.pos);
		return PhpReturnVoid;
	}

	function unsupportedValue(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php tracer supports only string literal values", expression.pos);
		return PhpString("");
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
