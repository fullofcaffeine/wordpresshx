package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.gutenberg.block._internal.BlockInputs.fail;
import wordpress.hx.gutenberg.block._internal.BlockModel.AttributeDefault;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockAttribute;

private typedef AttributeType = {
	final typeName:String;
	final enumValues:Array<String>;
	final enumNames:Map<String, String>;
}

/** Derives native Gutenberg attributes from one closed Haxe class. */
class BlockAttributeDeriver {
	static final ATTRIBUTE_NAME = ~/^[A-Za-z][A-Za-z0-9]*$/;
	static final SELECTOR = ~/^[^\x00\r\n]+$/;
	static final HTML_ATTRIBUTE = ~/^[a-zA-Z_:][a-zA-Z0-9_.:-]*$/;

	public static function derive(shape:Expr):Array<BlockAttribute> {
		final typed = Context.typeExpr(shape);
		final owner = switch typed.expr {
			case TTypeExpr(TClassDecl(reference)): reference.get();
			case _: fail("WPX6010", "Block.define expects an attribute class as its first argument", shape.pos);
		};
		if (owner.isInterface || owner.params.length > 0) {
			fail("WPX6010", "block attribute shapes must be concrete, non-generic Haxe classes", shape.pos);
		}

		final attributes:Array<BlockAttribute> = [];
		for (field in owner.fields.get()) {
			if (!field.isPublic) {
				continue;
			}
			switch field.kind {
				case FVar(_, _):
				case FMethod(_):
					fail("WPX6011", "public block attribute shapes may contain fields only: " + field.name, field.pos);
			}
			if (!ATTRIBUTE_NAME.match(field.name)) {
				fail("WPX6011", "invalid block attribute name " + field.name, field.pos);
			}
			validateMetadata(field);
			final attributeType = deriveType(field.type, field.pos);
			final source = metadataChoice(field, ":wpSource", ["attribute", "text", "rich-text", "html", "raw"], "WPX6012");
			final selector = metadataString(field, ":wpSelector", "WPX6013");
			final htmlAttribute = metadataString(field, ":wpAttribute", "WPX6013");
			final role = metadataChoice(field, ":wpRole", ["content", "local"], "WPX6014");
			validateSource(field.name, source, selector, htmlAttribute, field.pos);
			if (selector != null && !SELECTOR.match(selector)) {
				fail("WPX6013", "attribute " + field.name + " has an invalid selector", field.pos);
			}
			if (htmlAttribute != null && !HTML_ATTRIBUTE.match(htmlAttribute)) {
				fail("WPX6013", "attribute " + field.name + " has an invalid HTML attribute name", field.pos);
			}
			final typeName = source == "rich-text" ? "rich-text" : attributeType.typeName;
			if (source == "rich-text" && attributeType.typeName != "string") {
				fail("WPX6012", "rich-text attribute " + field.name + " must use the Haxe String type", field.pos);
			}
			attributes.push({
				name: field.name,
				typeName: typeName,
				enumValues: attributeType.enumValues,
				source: source,
				selector: selector,
				htmlAttribute: htmlAttribute,
				role: role,
				defaultValue: deriveDefault(field, attributeType)
			});
		}
		if (attributes.length == 0) {
			fail("WPX6010", "block attribute shape " + owner.name + " has no public fields", shape.pos);
		}
		attributes.sort((left, right) -> compareText(left.name, right.name));
		return attributes;
	}

	static function deriveType(type:Type, position:Position):AttributeType {
		return switch Context.follow(type) {
			case TAbstract(reference, _):
				switch reference.get().name {
					case "Bool": basic("boolean");
					case "Int": basic("integer");
					case "Float": basic("number");
					case other: fail("WPX6015", "unsupported abstract block attribute type " + other, position);
				};
			case TInst(reference, parameters):
				final instance = reference.get();
				switch instance.name {
					case "String" if (parameters.length == 0): basic("string");
					case "Array" if (parameters.length == 1):
						validateArrayItem(parameters[0], position);
						basic("array");
					case other: fail("WPX6015", "unsupported class block attribute type " + other, position);
				};
			case TEnum(reference, _): enumType(reference.get(), position);
			case other: fail("WPX6015", "unsupported block attribute type " + TypeTools.toString(other), position);
		};
	}

	static function validateArrayItem(type:Type, position:Position):Void {
		switch Context.follow(type) {
			case TAbstract(reference, _) if (["Bool", "Int", "Float"].contains(reference.get().name)):
			case TInst(reference, _) if (reference.get().name == "String"):
			case TEnum(reference, _):
				enumType(reference.get(), position);
			case other:
				fail("WPX6015", "block array attributes require scalar or enum items, found " + TypeTools.toString(other), position);
		}
	}

	static function enumType(type:EnumType, position:Position):AttributeType {
		final values:Array<String> = [];
		final names:Map<String, String> = [];
		for (name in type.names) {
			final constructor = type.constructs.get(name);
			if (constructor == null) {
				fail("WPX6016", "enum constructor disappeared while deriving " + type.name, position);
			}
			switch Context.follow(constructor.type) {
				case TFun(arguments, _) if (arguments.length > 0):
					fail("WPX6016", "block attribute enum constructors cannot carry values: " + type.name + "." + name, constructor.pos);
				case _:
			}
			final entries = constructor.meta.extract(":wpValue");
			if (entries.length != 1 || entries[0].params.length != 1) {
				fail("WPX6016", "block attribute enum constructor " + type.name + "." + name + " needs exactly one @:wpValue string", constructor.pos);
			}
			final value = literalString(entries[0].params[0], "WPX6016", "enum wire value");
			if (values.contains(value)) {
				fail("WPX6016", "duplicate block attribute enum wire value " + value, constructor.pos);
			}
			values.push(value);
			names.set(name, value);
		}
		return {typeName: "string", enumValues: values, enumNames: names};
	}

	static function basic(typeName:String):AttributeType {
		return {typeName: typeName, enumValues: [], enumNames: []};
	}

	static function deriveDefault(field:ClassField, attributeType:AttributeType):Null<AttributeDefault> {
		final entries = field.meta.extract(":wpDefault");
		if (entries.length == 0) {
			return null;
		}
		if (entries.length != 1 || entries[0].params.length != 1) {
			return fail("WPX6017", "attribute " + field.name + " needs at most one single-value @:wpDefault", field.pos);
		}
		final expression = entries[0].params[0];
		final defaultType = Context.typeof(expression);
		if (!Context.unify(defaultType, field.type)) {
			return fail("WPX6018",
				"default for "
				+ field.name
				+ " must match "
				+ TypeTools.toString(field.type)
				+ ", found "
				+ TypeTools.toString(defaultType), expression.pos);
		}
		return {value: defaultValue(expression, attributeType), position: expression.pos};
	}

	static function defaultValue(expression:Expr, attributeType:AttributeType):JsonValue {
		return switch expression.expr {
			case EParenthesis(inner): defaultValue(inner, attributeType);
			case EConst(CString(value, _)): StringValue(value);
			case EConst(CInt(value, _)): NumberValue(value);
			case EConst(CFloat(value, _)): NumberValue(value);
			case EConst(CIdent("true")): BoolValue(true);
			case EConst(CIdent("false")): BoolValue(false);
			case EArrayDecl(values): ArrayValue([for (value in values) defaultValue(value, attributeType)]);
			case EField(_, name) if (attributeType.enumNames.exists(name)): StringValue(attributeType.enumNames.get(name));
			case _: fail("WPX6019", "block attribute defaults must be closed scalar, enum, or array literals", expression.pos);
		};
	}

	static function validateMetadata(field:ClassField):Void {
		final allowed = [":wpSource", ":wpSelector", ":wpAttribute", ":wpRole", ":wpDefault"];
		for (entry in field.meta.get()) {
			if (StringTools.startsWith(entry.name, ":wp") && !allowed.contains(entry.name)) {
				fail("WPX6011", "unknown block attribute metadata @" + entry.name + " on " + field.name, entry.pos);
			}
		}
	}

	static function metadataString(field:ClassField, name:String, code:String):Null<String> {
		final entries = field.meta.extract(name);
		if (entries.length == 0) {
			return null;
		}
		if (entries.length != 1 || entries[0].params.length != 1) {
			return fail(code, "attribute " + field.name + " needs one " + name + " value", field.pos);
		}
		return literalString(entries[0].params[0], code, field.name + " " + name);
	}

	static function metadataChoice(field:ClassField, name:String, choices:Array<String>, code:String):Null<String> {
		final entries = field.meta.extract(name);
		if (entries.length == 0) {
			return null;
		}
		if (entries.length != 1 || entries[0].params.length != 1) {
			return fail(code, "attribute " + field.name + " needs one " + name + " value", field.pos);
		}
		final expression = entries[0].params[0];
		final expectedOwner = name == ":wpSource" ? "AttributeSource" : "AttributeRole";
		switch expression.expr {
			case EField(owner, _) if (terminalName(owner) == expectedOwner):
			case _:
				return fail(code, "attribute " + field.name + " must use a typed " + expectedOwner + " value", expression.pos);
		}
		final terminal = terminalName(expression);
		final value = switch terminal {
			case "Attribute": "attribute";
			case "Text": "text";
			case "RichText": "rich-text";
			case "Html": "html";
			case "Raw": "raw";
			case "Content": "content";
			case "Local": "local";
			case _: fail(code, "attribute " + field.name + " uses an unknown typed " + name + " value", expression.pos);
		};
		if (!choices.contains(value)) {
			return fail(code, "attribute " + field.name + " uses unsupported " + name + " value " + value, expression.pos);
		}
		return value;
	}

	static function validateSource(name:String, source:Null<String>, selector:Null<String>, htmlAttribute:Null<String>, position:Position):Void {
		switch source {
			case "attribute":
				if (selector == null || htmlAttribute == null) {
					fail("WPX6013", "attribute source " + name + " requires @:wpSelector and @:wpAttribute", position);
				}
			case "text" | "rich-text" | "html":
				if (selector == null || htmlAttribute != null) {
					fail("WPX6013", "markup source " + name + " requires @:wpSelector and forbids @:wpAttribute", position);
				}
			case "raw":
				if (selector != null || htmlAttribute != null) {
					fail("WPX6013", "raw source " + name + " does not accept selector or HTML attribute metadata", position);
				}
			case null:
				if (selector != null || htmlAttribute != null) {
					fail("WPX6013", "stored attribute " + name + " cannot declare markup extraction fields without @:wpSource", position);
				}
			case _:
		}
	}

	static function literalString(expression:Expr, code:String, label:String):String {
		return switch expression.expr {
			case EConst(CString(value, _)) if (value != ""): value;
			case _: fail(code, label + " must be a non-empty string literal", expression.pos);
		};
	}

	static function terminalName(expression:Expr):Null<String> {
		return switch expression.expr {
			case EConst(CIdent(name)): name;
			case EField(_, name): name;
			case _: null;
		};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
#end
