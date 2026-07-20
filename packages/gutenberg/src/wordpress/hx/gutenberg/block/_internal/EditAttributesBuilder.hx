package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

/** Validates a field selector and emits one native partial attribute object. */
class EditAttributesBuilder {
	public static function build(props:Expr, selector:Expr, value:Expr):Expr {
		final attributesType = editAttributesType(Context.follow(Context.typeof(props)), props.pos);
		final selected = selectedField(selector);
		final field = classField(attributesType, selected.name, selected.position);
		final valueType = Context.typeof(value);
		if (!Context.unify(valueType, field.type)) {
			Context.error('WPX6103: attribute ${selected.name} expects ${TypeTools.toString(field.type)}, found ${TypeTools.toString(valueType)}.', value.pos);
		}
		final update:Expr = {
			expr: EObjectDecl([{field: selected.name, expr: value}]),
			pos: selector.pos
		};
		return macro @:pos(selector.pos) wordpress.hx.gutenberg.block._internal.EditAttributesRuntime.apply($props, $update);
	}

	static function editAttributesType(type:Type, position:Position):ClassType {
		return switch type {
			case TInst(reference, [TInst(attributes, parameters)]):
				final props = reference.get();
				if (props.module != "wordpress.hx.gutenberg.block.EditProps" || props.name != "EditProps" || parameters.length != 0) {
					Context.error('WPX6101: EditAttributes.set expects EditProps<Attributes>, found ${TypeTools.toString(type)}.', position);
				}
				attributes.get();
			case _:
				Context.error('WPX6101: EditAttributes.set expects EditProps<Attributes>, found ${TypeTools.toString(type)}.', position);
		};
	}

	static function selectedField(selector:Expr):{final name:String; final position:Position;} {
		return switch selector.expr {
			case EFunction(_, fn):
				if (fn.args.length != 1) {
					Context.error("WPX6102: attribute selector must be a one-argument field-selection function.", selector.pos);
				}
				final parameter = fn.args[0].name;
				final body = unwrapReturn(fn.expr);
				switch body.expr {
					case EField({expr: EConst(CIdent(owner))}, name):
						if (owner != parameter) {
							Context.error("WPX6102: attribute selector must read from its own argument.", body.pos);
						}
						{name: name, position: body.pos};
					case _:
						Context.error("WPX6102: attribute selector must directly select one field, for example `attributes -> attributes.message`.", body.pos);
				}
			case _:
				Context.error("WPX6102: attribute selector must be a one-argument field-selection function.", selector.pos);
		};
	}

	static function unwrapReturn(expression:Expr):Expr {
		return switch expression.expr {
			case EParenthesis(value) | EMeta(_, value): unwrapReturn(value);
			case EReturn(value): value == null ? expression : unwrapReturn(value);
			case EBlock([value]): unwrapReturn(value);
			case _: expression;
		};
	}

	static function classField(owner:ClassType, name:String, position:Position):ClassField {
		for (field in owner.fields.get()) {
			if (field.name == name && field.isPublic) {
				return field;
			}
		}
		return Context.error('WPX6102: ${owner.module}.${owner.name} has no public attribute field ${name}.', position);
	}
}
#end
