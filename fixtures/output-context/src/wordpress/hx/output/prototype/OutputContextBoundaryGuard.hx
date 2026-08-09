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
	static final UNSERIALIZER_MODULE = "haxe.Unserializer";
	static final UNSERIALIZER_NAME = "Unserializer";
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
				if (isUnserializer(constructed)) {
					Context.error("Constructorless reconstitution is not admitted by the output-context profile", expression.pos);
				}
			case TField(_, fieldAccess):
				validateFieldAccess(fieldAccess, expression);
			case _:
		}
		TypedExprTools.iter(expression, child -> validateExpression(owner, child));
	}

	static function validateFieldAccess(fieldAccess:FieldAccess, expression:TypedExpr):Void {
		switch fieldAccess {
			case FStatic(classRef, fieldRef):
				final owner = classRef.get();
				final field = fieldRef.get();
				if (isForbiddenTypeConstructor(owner, field)) {
					Context.error("Reflective construction is not admitted by the output-context profile", expression.pos);
				}
				if (isUnserializer(owner)) {
					Context.error("Constructorless reconstitution is not admitted by the output-context profile", expression.pos);
				}
			case FInstance(classRef, _, _):
				if (isUnserializer(classRef.get())) {
					Context.error("Constructorless reconstitution is not admitted by the output-context profile", expression.pos);
				}
			case _:
		}
	}

	static function isForbiddenTypeConstructor(owner:ClassType, field:ClassField):Bool {
		return owner.module == "Type" && owner.name == "Type" && (field.name == "createInstance" || field.name == "createEmptyInstance");
	}

	static function isUnserializer(owner:ClassType):Bool {
		return owner.module == UNSERIALIZER_MODULE && owner.name == UNSERIALIZER_NAME;
	}
	#end
}
