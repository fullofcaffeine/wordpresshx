package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.Presence;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireValue.WireField;

/** Canonical wire projection of the schema IR; target emitters consume this shape. */
class SchemaJson {
	public static function encode(document:SchemaDocument):WireValue {
		return object([
			field("migrations", ArrayValue([for (migration in document.migrations) encodeMigration(migration)])),
			field("root", encodeNode(document.root)),
			field("schema", StringValue("wordpress-hx.contract-schema.v1")),
			field("schemaId", StringValue(document.schemaId.asString())),
			field("version", IntegerValue(document.version))
		]);
	}

	static function encodeNode(node:SchemaNode):WireValue {
		return switch node {
			case BooleanNode:
				object([field("kind", StringValue("boolean"))]);
			case IntegerNode(minimum, maximum):
				final fields = [field("kind", StringValue("integer"))];
				addOptionalInteger(fields, "maximum", maximum);
				addOptionalInteger(fields, "minimum", minimum);
				object(fields);
			case StringNode(minLength, maxLength):
				final fields = [field("kind", StringValue("string"))];
				addOptionalInteger(fields, "maxLength", maxLength);
				addOptionalInteger(fields, "minLength", minLength);
				object(fields);
			case EnumNode(values):
				object([
					field("kind", StringValue("enum")),
					field("values", ArrayValue([for (value in values) StringValue(value)]))
				]);
			case ArrayNode(value, minItems, maxItems):
				final fields = [field("items", encodeNode(value)), field("kind", StringValue("array"))];
				addOptionalInteger(fields, "maxItems", maxItems);
				addOptionalInteger(fields, "minItems", minItems);
				object(fields);
			case ObjectNode(schemaFields, unknownFields):
				object([
					field("fields", ArrayValue([for (schemaField in schemaFields) encodeField(schemaField)])),
					field("kind", StringValue("object")),
					field("unknownFields", StringValue(unknownFields))
				]);
			case TaggedUnionNode(discriminator, payloadField, cases):
				object([
					field("cases", ArrayValue([for (schemaCase in cases) encodeCase(schemaCase)])),
					field("discriminator", StringValue(discriminator)),
					field("kind", StringValue("tagged-union")),
					field("payloadField", StringValue(payloadField))
				]);
			case NullableNode(value):
				object([field("kind", StringValue("nullable")), field("value", encodeNode(value))]);
			case RefinedNode(value, validators, sanitizers):
				object([
					field("kind", StringValue("refined")),
					field("sanitizers", ArrayValue([for (rule in sanitizers) encodeRule(rule)])),
					field("validators", ArrayValue([for (rule in validators) encodeRule(rule)])),
					field("value", encodeNode(value))
				]);
		};
	}

	static function encodeField(schemaField:SchemaField):WireValue {
		return object([
			field("default", encodeDefault(schemaField.defaultValue)),
			field("jsonName", StringValue(schemaField.jsonName)),
			field("requirement", StringValue(schemaField.requirement)),
			field("value", encodeNode(schemaField.value))
		]);
	}

	static function encodeDefault(defaultValue:FieldDefault):WireValue {
		return switch defaultValue {
			case NoDefault: object([field("mode", StringValue("none"))]);
			case DefaultWhenMissing(value):
				object([
					field("mode", StringValue("when-missing")),
					field("value", FrozenWireValueTools.thaw(value))
				]);
		};
	}

	static function encodeRule(rule:SchemaRuleRef):WireValue {
		return object([
			field("parity", StringValue(rule.parity)),
			field("revision", IntegerValue(rule.revision)),
			field("ruleId", StringValue(rule.ruleId.asString()))
		]);
	}

	static function encodeCase(schemaCase:SchemaCase):WireValue {
		return object([
			field("tag", StringValue(schemaCase.tag)),
			field("value", encodeNode(schemaCase.value))
		]);
	}

	static function encodeMigration(migration:MigrationRef):WireValue {
		return object([
			field("fromVersion", IntegerValue(migration.fromVersion)),
			field("revision", IntegerValue(migration.revision)),
			field("ruleId", StringValue(migration.ruleId.asString())),
			field("toVersion", IntegerValue(migration.toVersion))
		]);
	}

	static function addOptionalInteger(fields:Array<WireField>, name:String, value:Presence<Int>):Void {
		switch value {
			case Missing:
			case Present(number):
				fields.push(field(name, IntegerValue(number)));
		}
	}

	static function object(fields:Array<WireField>):WireValue {
		return ObjectValue(fields);
	}

	static function field(name:String, value:WireValue):WireField {
		return {name: name, value: value};
	}
}
