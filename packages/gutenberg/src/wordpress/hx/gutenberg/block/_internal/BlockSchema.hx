package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.build._internal.JsonValue.JsonField;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockAttribute;

/** Shared deterministic projection of derived Haxe attributes. */
class BlockSchema {
	public static function value(attributes:Array<BlockAttribute>):JsonValue {
		return ObjectValue([for (attribute in attributes) field(attribute.name, attributeValue(attribute))]);
	}

	public static function expression(attributes:Array<BlockAttribute>, position:Position):Expr {
		return jsonExpression(value(attributes), position);
	}

	static function attributeValue(attribute:BlockAttribute):JsonValue {
		final fields:Array<JsonField> = [field("type", StringValue(attribute.typeName))];
		if (attribute.enumValues.length > 0) {
			fields.push(field("enum", ArrayValue([for (value in attribute.enumValues) StringValue(value)])));
		}
		optionalString(fields, "source", attribute.source);
		optionalString(fields, "selector", attribute.selector);
		optionalString(fields, "attribute", attribute.htmlAttribute);
		optionalString(fields, "role", attribute.role);
		if (attribute.defaultValue != null) {
			fields.push(field("default", attribute.defaultValue.value));
		}
		return ObjectValue(fields);
	}

	static function jsonExpression(value:JsonValue, position:Position):Expr {
		return switch value {
			case NullValue: macro @:pos(position) null;
			case BoolValue(value): macro @:pos(position) $v{value};
			case NumberValue(value): Context.parse(value, position);
			case StringValue(value): macro @:pos(position) $v{value};
			case ArrayValue(values):
				{expr: EArrayDecl([for (value in values) jsonExpression(value, position)]), pos: position};
			case ObjectValue(fields):
				{
					expr: EObjectDecl([
						for (entry in fields)
							{field: entry.name, expr: jsonExpression(entry.value, position)}
					]),
					pos: position
				};
		};
	}

	static function optionalString(fields:Array<JsonField>, name:String, value:Null<String>):Void {
		if (value != null) {
			fields.push(field(name, StringValue(value)));
		}
	}

	static function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}
}
#end
