package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;
import wordpress.hx.contracts.ContractRuleSet;
import wordpress.hx.contracts.ContractValidator;
import wordpress.hx.contracts.DecodeResult;
import wordpress.hx.contracts.Presence;

class SchemaInvariant {
	public static function validate(document:SchemaDocument):Void {
		validateMigrations(document.version, document.migrations);
		validateNode(document.root, "$root", document.rules);
	}

	static function validateMigrations(version:Int, migrations:FrozenList<MigrationRef>):Void {
		if (migrations.length != version - 1) {
			fail("$migrations", "schema version " + version + " requires one explicit migration for each adjacent version");
		}
		for (index in 0...migrations.length) {
			final migration = migrations[index];
			final expectedFrom = index + 1;
			if (migration.fromVersion != expectedFrom || migration.toVersion != expectedFrom + 1) {
				fail("$migrations[" + index + "]", "migration chain must be ordered, complete, and adjacent");
			}
		}
	}

	static function validateNode(node:SchemaNode, path:String, declarationRules:ContractRuleSet):Void {
		switch node {
			case BooleanNode:
			case IntegerNode(minimum, maximum):
				validateBounds(minimum, maximum, path);
			case StringNode(minLength, maxLength):
				validateLengths(minLength, maxLength, path);
			case EnumNode(values):
				if (values.length == 0) {
					fail(path + ".values", "enum must contain at least one value");
				}
				for (index in 0...values.length) {
					if (values[index].length == 0) {
						fail(path + ".values[" + index + "]", "enum value cannot be empty");
					}
					for (otherIndex in index + 1...values.length) {
						if (values[index] == values[otherIndex]) {
							fail(path + ".values", "enum values must be unique");
						}
					}
				}
			case ArrayNode(value, minItems, maxItems):
				validateLengths(minItems, maxItems, path);
				validateNode(value, path + ".items", declarationRules);
			case ObjectNode(fields, _):
				validateFields(fields, path + ".fields", declarationRules);
			case TaggedUnionNode(discriminator, payloadField, cases):
				if (!isFieldName(discriminator)) {
					fail(path + ".discriminator", "discriminator must be a stable JSON field name");
				}
				if (!isFieldName(payloadField) || payloadField == discriminator) {
					fail(path + ".payloadField", "payload must use a distinct stable JSON field name");
				}
				if (cases.length == 0) {
					fail(path + ".cases", "tagged union must contain at least one case");
				}
				for (index in 0...cases.length) {
					final schemaCase = cases[index];
					if (schemaCase.tag.length == 0) {
						fail(path + ".cases[" + index + "].tag", "tag cannot be empty");
					}
					for (otherIndex in index + 1...cases.length) {
						if (schemaCase.tag == cases[otherIndex].tag) {
							fail(path + ".cases", "tagged-union tags must be unique");
						}
					}
					validateNode(schemaCase.value, path + ".cases[" + index + "].value", declarationRules);
				}
			case NullableNode(value):
				switch value {
					case NullableNode(_):
						fail(path, "nullable nodes cannot be nested");
					case RefinedNode(_, _, _):
						fail(path, "refinement must wrap nullable rather than nest inside it");
					case _:
						validateNode(value, path + ".value", declarationRules);
				}
			case RefinedNode(value, validators, sanitizers):
				switch value {
					case RefinedNode(_, _, _):
						fail(path, "refined nodes cannot be nested");
					case _:
				}
				validateRuleList(validators, path + ".validators");
				validateRuleList(sanitizers, path + ".sanitizers");
				for (validator in validators) {
					if (validator.parity != RuleParity.Exact) {
						fail(path + ".validators", "validators require exact cross-target parity");
					}
					for (sanitizer in sanitizers) {
						if (validator.ruleId.asString() == sanitizer.ruleId.asString() && validator.revision == sanitizer.revision) {
							fail(path, "one rule revision cannot be both validator and sanitizer");
						}
					}
				}
				validateNode(value, path + ".value", declarationRules);
		}
	}

	static function validateFields(fields:FrozenList<SchemaField>, path:String, declarationRules:ContractRuleSet):Void {
		for (index in 0...fields.length) {
			final field = fields[index];
			if (!isFieldName(field.jsonName)) {
				fail(path + "[" + index + "].jsonName", "field must be a stable JSON name");
			}
			for (otherIndex in index + 1...fields.length) {
				if (field.jsonName == fields[otherIndex].jsonName) {
					fail(path, "field names must be unique");
				}
			}
			validateNode(field.value, path + "[" + index + "].value", declarationRules);
			switch field.defaultValue {
				case NoDefault:
				case DefaultWhenMissing(value):
					if (field.requirement != FieldRequirement.Optional) {
						fail(path + "[" + index + "].default", "defaults are legal only on optional fields");
					}
					switch ContractValidator.validateValue(FrozenWireValueTools.thaw(value), field.value, declarationRules) {
						case Decoded(_):
						case Rejected(issues):
							fail(path + "[" + index + "].default", "default fails its value schema or named rule: " + issues[0].code);
					}
			}
		}
	}

	static function validateRuleList(rules:FrozenList<SchemaRuleRef>, path:String):Void {
		for (index in 0...rules.length) {
			for (otherIndex in index + 1...rules.length) {
				if (rules[index].ruleId.asString() == rules[otherIndex].ruleId.asString()
					&& rules[index].revision == rules[otherIndex].revision) {
					fail(path, "rule identities and revisions must be unique");
				}
			}
		}
	}

	static function validateBounds(minimum:Presence<Int>, maximum:Presence<Int>, path:String):Void {
		switch [minimum, maximum] {
			case [Present(minimumValue), Present(maximumValue)] if (minimumValue > maximumValue):
				fail(path, "minimum cannot exceed maximum");
			case _:
		}
	}

	static function validateLengths(minimum:Presence<Int>, maximum:Presence<Int>, path:String):Void {
		switch minimum {
			case Present(value) if (value < 0):
				fail(path, "minimum length/count cannot be negative");
			case _:
		}
		switch maximum {
			case Present(value) if (value < 0):
				fail(path, "maximum length/count cannot be negative");
			case _:
		}
		validateBounds(minimum, maximum, path);
	}

	static function isFieldName(value:String):Bool {
		return ~/^[A-Za-z_][A-Za-z0-9_-]*$/.match(value);
	}

	static function fail(path:String, message:String):Void {
		throw new ContractError(path + ": " + message);
	}
}
