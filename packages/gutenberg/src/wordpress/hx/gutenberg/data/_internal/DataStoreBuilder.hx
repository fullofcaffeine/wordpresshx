package wordpress.hx.gutenberg.data._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

/** Compile-time validation for the public typed data-store constructor. */
class DataStoreBuilder {
	public static function build(key:ExprOf<wordpress.hx.gutenberg.data.StoreKey>, initialState:Expr, reducer:Expr):Expr {
		final stateType = Context.follow(Context.typeof(initialState));
		final reducerType = Context.follow(Context.typeof(reducer));
		final signature = switch reducerType {
			case TFun(arguments, result) if (arguments.length == 2):
				{state: arguments[0].t, action: arguments[1].t, result: result};
			case _:
				Context.error("WPX6402: a WordPress data-store reducer must have the form (state, action) -> state.", reducer.pos);
		};

		if (!Context.unify(stateType, signature.state) || !Context.unify(signature.result, signature.state)) {
			Context.error('WPX6403: reducer input and result must match the initial state type ${TypeTools.toString(stateType)}.', reducer.pos);
		}

		final actionType = Context.follow(signature.action);
		final fields = switch actionType {
			case TAnonymous(reference): reference.get().fields;
			case _:
				Context.error('WPX6404: store actions must be a closed typed structure with a string-compatible `type` field, found ${TypeTools.toString(actionType)}.',
					reducer.pos);
		};
		var actionIdentity:Null<Type> = null;
		for (field in fields) {
			if (field.name == "type") {
				actionIdentity = field.type;
				break;
			}
		}
		if (actionIdentity == null || !Context.unify(actionIdentity, Context.getType("String"))) {
			Context.error('WPX6405: store action ${TypeTools.toString(actionType)} needs a string-compatible `type` field for the native Redux contract.',
				reducer.pos);
		}

		return macro @:pos(reducer.pos) wordpress.hx.gutenberg.data.DataStores.createValidated($key, $initialState, $reducer);
	}
}
#end
