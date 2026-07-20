package wordpress.hx.contracts;

import haxe.iterators.StringIteratorUnicode;
import wordpress.hx.contracts.DecodeResult.DecodeIssue;
import wordpress.hx.contracts.Presence;
import wordpress.hx.contracts.RuleEvaluation;
import wordpress.hx.contracts.WireValue.WireField;
import wordpress.hx.contracts.schema.FieldRequirement;
import wordpress.hx.contracts.schema.FieldDefault;
import wordpress.hx.contracts.schema.FrozenList;
import wordpress.hx.contracts.schema.FrozenWireValueTools;
import wordpress.hx.contracts.schema.SchemaCase;
import wordpress.hx.contracts.schema.SchemaDocument;
import wordpress.hx.contracts.schema.SchemaField;
import wordpress.hx.contracts.schema.SchemaNode;
import wordpress.hx.contracts.schema.SchemaRuleRef;

/** Validates wire values from the canonical schema before domain decoding. */
class ContractValidator {
	public static function validate(value:WireValue, document:SchemaDocument):DecodeResult<WireValue> {
		try {
			return Decoded(validateNode(value, document.root, "", document.rules, true));
		} catch (failure:SchemaValidationFailure) {
			return Rejected([failure.issue]);
		}
	}

	public static function validateShape(value:WireValue, node:SchemaNode):DecodeResult<WireValue> {
		try {
			return Decoded(validateNode(value, node, "", new NoContractRules(), false));
		} catch (failure:SchemaValidationFailure) {
			return Rejected([failure.issue]);
		}
	}

	public static function validateValue(value:WireValue, node:SchemaNode, rules:ContractRuleSet):DecodeResult<WireValue> {
		try {
			return Decoded(validateNode(value, node, "", rules, true));
		} catch (failure:SchemaValidationFailure) {
			return Rejected([failure.issue]);
		}
	}

	static function validateNode(value:WireValue, node:SchemaNode, path:String, rules:ContractRuleSet, evaluateNamedRules:Bool):WireValue {
		return switch node {
			case BooleanNode:
				switch value {
					case BoolValue(_): value;
					case _: rejectType(path, "boolean", value);
				};
			case IntegerNode(minimum, maximum):
				final number = switch value {
					case IntegerValue(number): number;
					case _: rejectType(path, "integer", value);
				};
				switch minimum {
					case Present(bound) if (number < bound): rejectConstraint(path, "integer greater than or equal to " + bound, Std.string(number));
					case _:
				}
				switch maximum {
					case Present(bound) if (number > bound): rejectConstraint(path, "integer less than or equal to " + bound, Std.string(number));
					case _:
				}
				value;
			case StringNode(minLength, maxLength):
				final text = switch value {
					case StringValue(text): text;
					case _: rejectType(path, "string", value);
				};
				final length = unicodeScalarLength(text);
				switch minLength {
					case Present(bound) if (length < bound): rejectConstraint(path, "string with at least " + bound + " Unicode scalar values",
							"length=" + length);
					case _:
				}
				switch maxLength {
					case Present(bound) if (length > bound): rejectConstraint(path, "string with at most " + bound + " Unicode scalar values",
							"length=" + length);
					case _:
				}
				value;
			case EnumNode(values):
				final text = switch value {
					case StringValue(text): text;
					case _: rejectType(path, "string enum", value);
				};
				if (!containsText(values, text)) {
					rejectConstraint(path, values.toArray().join("|"), text);
				}
				value;
			case ArrayNode(itemNode, minItems, maxItems):
				final values = switch value {
					case ArrayValue(values): values;
					case _: rejectType(path, "array", value);
				};
				switch minItems {
					case Present(bound) if (values.length < bound): rejectConstraint(path, "array with at least " + bound + " items",
							"length=" + values.length);
					case _:
				}
				switch maxItems {
					case Present(bound) if (values.length > bound): rejectConstraint(path, "array with at most " + bound + " items", "length=" + values.length);
					case _:
				}
				ArrayValue([
					for (index in 0...values.length)
						validateNode(values[index], itemNode, childPath(path, Std.string(index)), rules, evaluateNamedRules)
				]);
			case ObjectNode(schemaFields, _):
				validateObject(value, schemaFields, path, rules, evaluateNamedRules);
			case TaggedUnionNode(discriminator, payloadField, cases):
				validateTaggedUnion(value, discriminator, payloadField, cases, path, rules, evaluateNamedRules);
			case NullableNode(child):
				switch value {
					case NullValue: NullValue;
					case _: validateNode(value, child, path, rules, evaluateNamedRules);
				};
			case RefinedNode(child, validators, _):
				final normalized = validateNode(value, child, path, rules, evaluateNamedRules);
				if (evaluateNamedRules) {
					validateRules(normalized, validators, path, rules);
				}
				normalized;
		};
	}

	static function validateObject(value:WireValue, schemaFields:FrozenList<SchemaField>, path:String, rules:ContractRuleSet,
			evaluateNamedRules:Bool):WireValue {
		final fields = switch value {
			case ObjectValue(fields): fields;
			case _: rejectType(path, "object", value);
		};
		validateObjectFieldSet(fields, schemaFields, path);
		final normalized:Array<WireField> = [];
		for (schemaField in schemaFields) {
			final fieldPath = childPath(path, schemaField.jsonName);
			switch findWireField(fields, schemaField.jsonName) {
				case Missing:
					switch schemaField.defaultValue {
						case NoDefault:
							if (schemaField.requirement == FieldRequirement.Required) {
								reject("WPHX5202", fieldPath, "required field", "missing");
							}
						case DefaultWhenMissing(defaultValue):
							final normalizedDefault = validateNode(FrozenWireValueTools.thaw(defaultValue), schemaField.value, fieldPath, rules,
								evaluateNamedRules);
							normalized.push({name: schemaField.jsonName, value: normalizedDefault});
					}
				case Present(fieldValue):
					final normalizedValue = validateNode(fieldValue, schemaField.value, fieldPath, rules, evaluateNamedRules);
					normalized.push({name: schemaField.jsonName, value: normalizedValue});
			}
		}
		return ObjectValue(normalized);
	}

	static function validateObjectFieldSet(fields:Array<WireField>, schemaFields:FrozenList<SchemaField>, path:String):Void {
		final sorted = fields.copy();
		sorted.sort((left, right) -> UnicodeScalarOrder.compare(left.name, right.name));
		for (index in 0...sorted.length) {
			final current = sorted[index];
			final fieldPath = childPath(path, current.name);
			if (index > 0 && sorted[index - 1].name == current.name) {
				reject("WPHX5204", fieldPath, "one field occurrence", "duplicate-field");
			}
			if (!containsSchemaField(schemaFields, current.name)) {
				reject("WPHX5203", fieldPath, "closed field set", "unknown-field");
			}
		}
	}

	static function validateTaggedUnion(value:WireValue, discriminator:String, payloadField:String, cases:FrozenList<SchemaCase>, path:String,
			rules:ContractRuleSet, evaluateNamedRules:Bool):WireValue {
		final fields = switch value {
			case ObjectValue(fields): fields;
			case _: rejectType(path, "tagged-union object", value);
		};
		final syntheticFields:FrozenList<SchemaField> = [
			new SchemaField(discriminator, FieldRequirement.Required, StringNode(Missing, Missing), NoDefault),
			new SchemaField(payloadField, FieldRequirement.Required, BooleanNode, NoDefault)
		];
		validateObjectFieldSet(fields, syntheticFields, path);
		final discriminatorPath = childPath(path, discriminator);
		final tag = switch requiredWireField(fields, discriminator, discriminatorPath) {
			case StringValue(text): text;
			case other: rejectType(discriminatorPath, "string discriminator", other);
		};
		final schemaCase = findCase(cases, tag, discriminatorPath);
		final payloadPath = childPath(path, payloadField);
		final payload = validateNode(requiredWireField(fields, payloadField, payloadPath), schemaCase.value, payloadPath, rules, evaluateNamedRules);
		return ObjectValue([
			{name: discriminator, value: StringValue(tag)},
			{name: payloadField, value: payload}
		]);
	}

	static function validateRules(value:WireValue, ruleRefs:FrozenList<SchemaRuleRef>, path:String, rules:ContractRuleSet):Void {
		for (rule in ruleRefs) {
			switch rules.evaluate(rule, value) {
				case RulePassed:
				case RuleRejected(actual):
					reject("WPHX5205", path, rule.ruleId.asString() + "@" + rule.revision, actual);
				case RuleUnavailable:
					reject("WPHX5206", path, rule.ruleId.asString() + "@" + rule.revision, "rule-unavailable");
			}
		}
	}

	static function requiredWireField(fields:Array<WireField>, name:String, path:String):WireValue {
		return switch findWireField(fields, name) {
			case Missing: reject("WPHX5202", path, "required field", "missing");
			case Present(value): value;
		};
	}

	static function findWireField(fields:Array<WireField>, name:String):Presence<WireValue> {
		for (field in fields) {
			if (field.name == name) {
				return Present(field.value);
			}
		}
		return Missing;
	}

	static function containsSchemaField(fields:FrozenList<SchemaField>, name:String):Bool {
		for (field in fields) {
			if (field.jsonName == name) {
				return true;
			}
		}
		return false;
	}

	static function containsText(values:FrozenList<String>, expected:String):Bool {
		for (value in values) {
			if (value == expected) {
				return true;
			}
		}
		return false;
	}

	static function findCase(cases:FrozenList<SchemaCase>, tag:String, path:String):SchemaCase {
		for (schemaCase in cases) {
			if (schemaCase.tag == tag) {
				return schemaCase;
			}
		}
		return rejectConstraint(path, [for (schemaCase in cases) schemaCase.tag].join("|"), tag);
	}

	static function unicodeScalarLength(value:String):Int {
		var length = 0;
		for (_ in new StringIteratorUnicode(value)) {
			length++;
		}
		return length;
	}

	static function childPath(parent:String, component:String):String {
		final escaped = StringTools.replace(StringTools.replace(component, "~", "~0"), "/", "~1");
		return parent + "/" + escaped;
	}

	static function rejectType<T>(path:String, expected:String, actual:WireValue):T {
		return reject("WPHX5201", path, expected, WireKind.of(actual));
	}

	static function rejectConstraint<T>(path:String, expected:String, actual:String):T {
		return reject("WPHX5205", path, expected, actual);
	}

	static function reject<T>(code:String, path:String, expected:String, actual:String):T {
		throw new SchemaValidationFailure(new DecodeIssue(code, path, expected, actual));
	}
}

private class SchemaValidationFailure extends haxe.Exception {
	public final issue:DecodeIssue;

	public function new(issue:DecodeIssue) {
		this.issue = issue;
		super(issue.code + " " + issue.path);
	}
}
