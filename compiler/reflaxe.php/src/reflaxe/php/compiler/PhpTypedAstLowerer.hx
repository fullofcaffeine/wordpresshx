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
		if (functionData.args.length != 0) {
			Context.fatalError("reflaxe.php tracer does not yet support method parameters", functionData.field.pos);
		}
		if (TypeTools.toString(functionData.ret) != "Void") {
			Context.fatalError("reflaxe.php tracer supports only Void methods", functionData.field.pos);
		}
		if (functionData.expr == null) {
			Context.fatalError("reflaxe.php application methods require a typed body", functionData.field.pos);
			return unreachableMethod(functionData);
		}
		final body = lowerStatementList(functionData.expr);
		return new PhpMethod(functionData.field.isPublic ? PhpPublic : PhpPrivate, true, false, PhpIdentifier.named(functionData.field.name), [],
			sources.range(functionData.field.pos), PhpVoidType, body, "method:"
			+ functionData.classType.module
			+ ":"
			+ functionData.field.name);
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
			case TReturn(null): [mapped(PhpReturnVoid, expression, "return")];
			case TMeta(_, inner) | TParenthesis(inner): lowerStatementList(inner);
			case _:
				unsupportedStatement(expression);
		}
	}

	function lowerCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):PhpStmt {
		return switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (classRef.get().module == "Sys" && fieldRef.get().name == "println" && arguments.length == 1):
				final value = lowerValue(arguments[0]);
				mapped(PhpEcho(PhpBinop(".", value, PhpConst("PHP_EOL"))), call, "sys-println");
			case _:
				unsupportedCall(call);
		}
	}

	function lowerValue(expression:TypedExpr):PhpExpr {
		return switch (expression.expr) {
			case TConst(TString(value)): PhpString(value);
			case TMeta(_, inner) | TParenthesis(inner): lowerValue(inner);
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
