package reflaxe.php.compiler;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpClassKind;
import reflaxe.php.ir.PhpClosureCapture;
import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpIdentifier;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpParameter;
import reflaxe.php.ir.PhpProperty;
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
		if (classType.superClass != null || classType.interfaces.length != 0) {
			Context.fatalError("reflaxe.php instance layout does not yet support inheritance or interfaces", classType.pos);
		}
		final orderedFields = varFields.copy();
		orderedFields.sort((left, right) -> compareText(left.field.name, right.field.name));
		final properties = orderedFields.map(lowerProperty);
		final orderedFunctions = funcFields.copy();
		orderedFunctions.sort((left, right) -> compareText(left.field.name, right.field.name));
		final methods = orderedFunctions.map(lowerMethod);
		return new PhpClass(PhpClassKindClass, PhpIdentifier.named(className(classType)), sources.range(classType.pos), null, [], properties, methods,
			"class:"
			+ classType.module
			+ ":"
			+ classType.name);
	}

	function lowerProperty(variableData:ClassVarData):PhpProperty {
		if (variableData.isStatic || variableData.field.isPublic || TypeTools.toString(variableData.field.type) != "String") {
			Context.fatalError("reflaxe.php supports only private instance String fields in the admitted instance-layout slice", variableData.field.pos);
		}
		switch (variableData.write) {
			case AccCtor:
			case _:
				Context.fatalError("reflaxe.php instance fields must be constructor-initialized and immutable after construction", variableData.field.pos);
		}
		if (variableData.findDefaultExpr() != null) {
			Context.fatalError("reflaxe.php instance fields do not yet support declaration initializers", variableData.field.pos);
		}
		PhpSemanticCapabilities.requireAdmitted(PrivateInstanceStringField);
		return new PhpProperty(PhpPrivate, false, PhpIdentifier.named(variableData.field.name), null, PhpStringType);
	}

	public function className(classType:ClassType):String {
		final parts = classType.pack.concat([classType.name]);
		return "Hx_" + parts.map(part -> part.length + "_" + part).join("_");
	}

	function lowerMethod(functionData:ClassFuncData):PhpMethod {
		final isConstructor = functionData.field.name == "new";
		if (!functionData.isStatic && !isConstructor && TypeTools.toString(functionData.ret) != "String") {
			Context.fatalError("reflaxe.php supports only String-returning instance methods in the admitted instance-layout slice", functionData.field.pos);
		}
		if (!functionData.isStatic) {
			PhpSemanticCapabilities.requireAdmitted(isConstructor ? RequiredStringConstructor : RequiredStringInstanceMethod);
		}
		final signature = isConstructor ? lowerConstructorSignature(functionData) : lowerMethodSignature(functionData);
		if (functionData.expr == null) {
			Context.fatalError("reflaxe.php application methods require a typed body", functionData.field.pos);
			return unreachableMethod(functionData);
		}
		final body = lowerStatementList(functionData.expr, new Map<Int, Int>());
		return new PhpMethod(functionData.field.isPublic ? PhpPublic : PhpPrivate, functionData.isStatic, false,
			PhpIdentifier.named(isConstructor ? "__construct" : functionData.field.name), signature.parameters, sources.range(functionData.field.pos),
			signature.returnType, body, "method:"
			+ functionData.classType.module
			+ ":"
			+ functionData.field.name);
	}

	function lowerConstructorSignature(functionData:ClassFuncData):{parameters:Array<PhpParameter>, returnType:Null<PhpType>} {
		if (functionData.isStatic || TypeTools.toString(functionData.ret) != "Void" || functionData.args.length == 0) {
			Context.fatalError("reflaxe.php constructors require at least one required String parameter", functionData.field.pos);
		}
		PhpSemanticCapabilities.requireAdmitted(RequiredStringConstructor);
		return {parameters: lowerRequiredParameters(functionData, "String", PhpStringType), returnType: null};
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
				final parameters = lowerRequiredParameters(functionData, "Int", PhpIntType);
				{parameters: parameters, returnType: PhpIntType};
			case "Bool":
				PhpSemanticCapabilities.requireAdmitted(RequiredBoolParameters);
				PhpSemanticCapabilities.requireAdmitted(BoolReturn);
				if (functionData.args.length == 0) {
					Context.fatalError("reflaxe.php Bool-returning methods currently require at least one Bool parameter", functionData.field.pos);
				}
				final parameters = lowerRequiredParameters(functionData, "Bool", PhpBoolType);
				{parameters: parameters, returnType: PhpBoolType};
			case "String":
				PhpSemanticCapabilities.requireAdmitted(RequiredStringParameters);
				PhpSemanticCapabilities.requireAdmitted(StringReturn);
				if (functionData.args.length == 0) {
					Context.fatalError("reflaxe.php String-returning methods currently require at least one String parameter", functionData.field.pos);
				}
				final parameters = lowerRequiredParameters(functionData, "String", PhpStringType);
				{parameters: parameters, returnType: PhpStringType};
			case _:
				Context.fatalError("reflaxe.php supports only Void, Int, Bool, and String method returns in the admitted semantic slice",
					functionData.field.pos);
				{parameters: [], returnType: PhpVoidType};
		}
	}

	function lowerRequiredParameters(functionData:ClassFuncData, haxeType:String, phpType:PhpType):Array<PhpParameter> {
		return functionData.args.map(argument -> {
			if (argument.opt || argument.expr != null) {
				Context.fatalError("reflaxe.php supports only required parameters without defaults", functionData.field.pos);
			}
			if (TypeTools.toString(argument.type) != haxeType) {
				Context.fatalError("reflaxe.php supports only " + haxeType + " parameters for " + haxeType
					+ "-returning methods in the admitted semantic slice",
					functionData.field.pos);
			}
			return PhpParameter.named(PhpIdentifier.named(argument.getName()), phpType);
		});
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
						case "Bool":
							PhpSemanticCapabilities.requireAdmitted(InitializedBoolLocal);
							[
								mapped(PhpLocal(variable.name, lowerBoolValue(initialValue)), expression, "local-bool")
							];
						case "String":
							PhpSemanticCapabilities.requireAdmitted(InitializedStringLocal);
							[
								mapped(PhpLocal(variable.name, lowerStringValue(initialValue)), expression, "local-string")
							];
						case "Array<Int>":
							lowerIntArrayLocal(expression, variable, initialValue, intArrayLengths);
						case _:
							if (PhpStringClosureShape.isType(variable.t)) {
								PhpSemanticCapabilities.requireAdmitted(InitializedStringClosureLocal);
								[
									mapped(PhpLocal(variable.name, lowerStringClosure(initialValue)), expression, "local-string-closure")
								];
							} else if (PhpStringClosureShape.isFunctionType(variable.t)) {
								Context.fatalError("reflaxe.php supports only required unary String closures with read-only String captures", expression.pos);
								[];
							} else if (ownedClass(variable.t) == null) {
								Context.fatalError("reflaxe.php supports only admitted scalar, Array<Int>, and source-owned object local bindings",
									expression.pos);
								[];
							} else {
								PhpSemanticCapabilities.requireAdmitted(InitializedObjectLocal);
								[
									mapped(PhpLocal(variable.name, lowerObjectValue(initialValue)), expression, "local-object")
								];
							}
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
			case TBinop(OpAssign, target, value):
				switch (target.expr) {
					case TField(receiver, FInstance(classRef, _, fieldRef))
						if (sources.owns(classRef.get().pos) && TypeTools.toString(fieldRef.get().type) == "String"):
						PhpSemanticCapabilities.requireAdmitted(InstanceStringFieldConstructorAssignment);
						[
							mapped(PhpAssign(PhpObjectProperty(lowerObjectValue(receiver), fieldRef.get().name), lowerStringValue(value)), expression,
								"assign-instance-string")
						];
					case _: [lowerIntAssignment(expression, target, value, intArrayLengths)];
				}
			case TBinop(OpAssignOp(_), _, _):
				Context.fatalError("reflaxe.php does not yet support compound assignment", expression.pos);
				[];
			case TReturn(null): [mapped(PhpReturnVoid, expression, "return")];
			case TReturn(value):
				switch (TypeTools.toString(value.t)) {
					case "Int":
						PhpSemanticCapabilities.requireAdmitted(IntReturn);
						[
							mapped(PhpReturn(lowerIntValue(value, intArrayLengths)), expression, "return-int")
						];
					case "Bool":
						PhpSemanticCapabilities.requireAdmitted(BoolReturn);
						[mapped(PhpReturn(lowerBoolValue(value)), expression, "return-bool")];
					case "String":
						PhpSemanticCapabilities.requireAdmitted(StringReturn);
						[mapped(PhpReturn(lowerStringValue(value)), expression, "return-string")];
					case _:
						Context.fatalError("reflaxe.php supports only Int, Bool, and String return expressions in the admitted semantic slice", value.pos);
						[];
				}
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
			case TCall(target, arguments): lowerStaticApplicationStringCall(expression, target, arguments);
			case TField(receiver, FInstance(classRef, _, fieldRef))
				if (sources.owns(classRef.get().pos) && TypeTools.toString(fieldRef.get().type) == "String"):
				PhpSemanticCapabilities.requireAdmitted(InstanceStringFieldRead);
				PhpObjectProperty(lowerObjectValue(receiver), fieldRef.get().name);
			case TMeta(_, inner) | TParenthesis(inner): lowerStringValue(inner);
			case _: unsupportedStringValue(expression);
		}
	}

	function lowerStringClosure(expression:TypedExpr):PhpExpr {
		final plan = PhpStringClosureShape.analyze(expression);
		if (plan == null) {
			Context.fatalError("reflaxe.php supports only required unary String closures with read-only String captures", expression.pos);
			return PhpString("");
		}
		PhpSemanticCapabilities.requireAdmitted(RequiredStringClosureParameter);
		PhpSemanticCapabilities.requireAdmitted(StringClosureReturn);
		PhpSemanticCapabilities.requireAdmitted(ReadOnlyStringClosureCapture);
		final parameters = plan.functionData.args.map(argument -> PhpParameter.named(PhpIdentifier.named(argument.v.name), PhpStringType));
		final captures = plan.captures.map(variable -> new PhpClosureCapture(PhpIdentifier.named(variable.name)));
		return PhpClosure(parameters, captures, lowerStatementList(plan.functionData.expr, new Map<Int, Int>()), true, PhpStringType);
	}

	function lowerBoolValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TBool(value)):
				PhpSemanticCapabilities.requireAdmitted(BoolLiteral);
				PhpBool(value);
			case TLocal(variable) if (TypeTools.toString(variable.t) == "Bool"):
				PhpSemanticCapabilities.requireAdmitted(InitializedBoolLocal);
				PhpVar(variable.name);
			case TUnop(OpNot, _, value):
				PhpSemanticCapabilities.requireAdmitted(BoolNot);
				PhpNot(lowerBoolValue(value));
			case TBinop(OpBoolAnd, left, right):
				PhpSemanticCapabilities.requireAdmitted(BoolShortCircuitAnd);
				PhpSemanticCapabilities.requireAdmitted(BoolParenthesizedGrouping);
				PhpParenthesized(PhpBinop("&&", lowerBoolValue(left), lowerBoolValue(right)));
			case TBinop(OpBoolOr, left, right):
				PhpSemanticCapabilities.requireAdmitted(BoolShortCircuitOr);
				PhpSemanticCapabilities.requireAdmitted(BoolParenthesizedGrouping);
				PhpParenthesized(PhpBinop("||", lowerBoolValue(left), lowerBoolValue(right)));
			case TCall(target, arguments): lowerStaticApplicationBoolCall(expression, target, arguments);
			case TMeta(_, inner) | TParenthesis(inner): lowerBoolValue(inner);
			case _: unsupportedBoolValue(expression);
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

	function lowerStaticApplicationStringCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpExpr {
		return switch (target.expr) {
			case TLocal(variable) if (PhpStringClosureShape.isType(target.t) && TypeTools.toString(call.t) == "String"):
				if (arguments.length != 1) {
					Context.fatalError("reflaxe.php String closures require exactly one String argument", call.pos);
				}
				PhpSemanticCapabilities.requireAdmitted(StringClosureInvoke);
				PhpInvoke(PhpVar(variable.name), arguments.map(lowerStringValue));
			case TField(_, FStatic(classRef, fieldRef)) if (sources.owns(classRef.get().pos) && TypeTools.toString(call.t) == "String"):
				PhpSemanticCapabilities.requireAdmitted(StaticApplicationStringCall);
				PhpStaticCall(className(classRef.get()), fieldRef.get().name, arguments.map(lowerStringValue));
			case TField(receiver, FInstance(classRef, _, fieldRef)) if (sources.owns(classRef.get().pos) && TypeTools.toString(call.t) == "String"):
				PhpSemanticCapabilities.requireAdmitted(SourceOwnedStringInstanceCall);
				PhpMethodCall(lowerObjectValue(receiver), fieldRef.get().name, arguments.map(lowerStringValue));
			case _:
				Context.fatalError("reflaxe.php supports only source-owned static String calls in the admitted semantic slice", call.pos);
				PhpString("");
		}
	}

	function lowerObjectValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TThis): PhpVar("this");
			case TLocal(variable) if (ownedClass(variable.t) != null): PhpVar(variable.name);
			case TNew(classRef, _, arguments) if (sources.owns(classRef.get().pos)):
				PhpSemanticCapabilities.requireAdmitted(SourceOwnedConstructorCall);
				PhpNew(className(classRef.get()), arguments.map(lowerStringValue));
			case TMeta(_, inner) | TParenthesis(inner): lowerObjectValue(inner);
			case _:
				Context.fatalError("reflaxe.php supports only this, source-owned object locals, and source-owned construction", expression.pos);
				PhpNull;
		}
	}

	function ownedClass(type:Type):Null<ClassType> {
		return switch (TypeTools.follow(type)) {
			case TInst(classRef, _):
				final classType = classRef.get();
				sources.owns(classType.pos) ? classType : null;
			case _: null;
		}
	}

	function lowerStaticApplicationBoolCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpExpr {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (sources.owns(classRef.get().pos) && TypeTools.toString(call.t) == "Bool"):
				PhpSemanticCapabilities.requireAdmitted(StaticApplicationBoolCall);
				PhpStaticCall(className(classRef.get()), fieldRef.get().name, arguments.map(lowerBoolValue));
			case _:
				Context.fatalError("reflaxe.php supports only source-owned static Bool calls in the admitted semantic slice", call.pos);
				PhpBool(false);
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
			case TBinop(OpEq | OpLte, left, right) if (TypeTools.toString(left.t) == "Int" && TypeTools.toString(right.t) == "Int"):
				{
					expression: lowerIntCondition(expression, intArrayLengths),
					mappingKind: "if-int-equality"
				};
			case _ if (TypeTools.toString(expression.t) == "Bool"):
				PhpSemanticCapabilities.requireAdmitted(BoolCondition);
				{
					expression: lowerBoolValue(expression),
					mappingKind: "if-bool"
				};
			case TMeta(_, inner) | TParenthesis(inner): lowerCondition(inner, intArrayLengths);
			case _:
				Context.fatalError("reflaxe.php supports only admitted Int, String, and Bool conditions", expression.pos);
				{expression: PhpBool(false), mappingKind: "if-unsupported"};
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
		Context.fatalError("reflaxe.php supports only String literals, String locals, exact String concatenation, and source-owned static String calls without coercion",
			expression.pos);
		return PhpString("");
	}

	function unsupportedIntValue(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only admitted Int literals, locals, addition, proven array reads, and source-owned calls", expression.pos);
		return PhpInt(0);
	}

	function unsupportedBoolValue(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only Bool literals, Bool locals, logical negation, lazy Bool conjunction/disjunction, and source-owned static Bool calls",
			expression.pos);
		return PhpBool(false);
	}

	function unsupportedIntCondition(expression:TypedExpr):PhpExpr {
		Context.fatalError("reflaxe.php supports only Int equality and <= conditions in the admitted semantic slice", expression.pos);
		return PhpBool(false);
	}

	function unreachableMethod(functionData:ClassFuncData):PhpMethod {
		return new PhpMethod(PhpPrivate, functionData.isStatic, false, PhpIdentifier.named(functionData.field.name), [],
			sources.range(functionData.field.pos), PhpVoidType, [], "method:unreachable:" + functionData.field.name);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
	#end
}
