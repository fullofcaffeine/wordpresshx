package wordpress.hx.output.prototype;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypedExprTools;
#end

/** Compiler-profile guard for the sink-owned `JsonPlan` construction boundary. */
final class OutputContextBoundaryGuard {
	#if macro
	static final JSON_PLAN_MODULE = "wordpress.hx.output.prototype.OutputSinks";
	static final JSON_PLAN_NAME = "JsonPlan";
	static final SINK_NAME = "OutputSinks";
	static var installed = false;

	public static function install():Expr {
		if (!installed) {
			installed = true;
			Context.onAfterTyping(validateModules);
		}
		return macro null;
	}

	static function validateModules(moduleTypes:Array<ModuleType>):Void {
		for (moduleType in moduleTypes) {
			switch moduleType {
				case TClassDecl(classRef):
					final classType = classRef.get();
					validateFields(classType, classType.fields.get());
					validateFields(classType, classType.statics.get());
					switch classType.constructor {
						case null:
						case constructor:
							validateField(classType, constructor.get());
					}
					switch classType.init {
						case null:
						case expression:
							validateExpression(classType, expression);
					}
				case _:
			}
		}
	}

	static function validateFields(owner:ClassType, fields:Array<ClassField>):Void {
		for (field in fields) {
			validateField(owner, field);
		}
	}

	static function validateField(owner:ClassType, field:ClassField):Void {
		switch field.expr() {
			case null:
			case expression:
				validateExpression(owner, expression);
		}
	}

	static function validateExpression(owner:ClassType, expression:TypedExpr):Void {
		switch expression.expr {
			case TNew(classRef, _, _):
				final constructed = classRef.get();
				if (constructed.module == JSON_PLAN_MODULE
					&& constructed.name == JSON_PLAN_NAME
					&& !(owner.module == JSON_PLAN_MODULE && owner.name == SINK_NAME)) {
					Context.error("JsonPlan construction is restricted to OutputSinks", expression.pos);
				}
			case TField(_, FStatic(classRef, fieldRef)) if (isTypeCreateInstance(classRef.get(), fieldRef.get())):
				Context.error("Reflective construction is not admitted by the output-context profile", expression.pos);
			case _:
		}
		TypedExprTools.iter(expression, child -> validateExpression(owner, child));
	}

	static function isTypeCreateInstance(owner:ClassType, field:ClassField):Bool {
		return owner.module == "Type" && owner.name == "Type" && field.name == "createInstance";
	}
	#end
}
