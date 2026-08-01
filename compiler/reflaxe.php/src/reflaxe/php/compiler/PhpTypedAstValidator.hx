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
		if (functionData.args.length != 0) {
			Context.error("reflaxe.php tracer does not yet support method parameters", functionData.field.pos);
		}
		if (TypeTools.toString(functionData.ret) != "Void") {
			Context.error("reflaxe.php tracer supports only Void methods", functionData.field.pos);
		}
		if (functionData.expr == null) {
			Context.error("reflaxe.php application methods require a typed body", functionData.field.pos);
			return;
		}
		validateStatement(functionData.expr);
	}

	static function validateStatement(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TBlock(expressions):
				for (child in expressions) {
					validateStatement(child);
				}
			case TCall(target, arguments):
				validateCall(expression, target, arguments);
			case TReturn(null):
			case TMeta(_, inner) | TParenthesis(inner):
				validateStatement(inner);
			case _:
				Context.error("reflaxe.php tracer does not support statement " + expression.expr.getName(), expression.pos);
		}
	}

	static function validateCall(call:TypedExpr, target:TypedExpr, arguments:Array<TypedExpr>):Void {
		switch (target.expr) {
			case TField(_, FStatic(classRef, fieldRef)) if (classRef.get().module == "Sys" && fieldRef.get().name == "println" && arguments.length == 1):
				validateValue(arguments[0]);
			case _:
				Context.error("reflaxe.php tracer supports only Sys.println(String)", call.pos);
		}
	}

	static function validateValue(expression:TypedExpr):Void {
		switch (expression.expr) {
			case TConst(TString(_)):
			case TMeta(_, inner) | TParenthesis(inner):
				validateValue(inner);
			case _:
				Context.error("reflaxe.php tracer supports only string literal values", expression.pos);
		}
	}
	#end
}
