package wordpress.hx.contracts.tests;

#if js
import js.Node;
#end
import wordpress.hx.contracts.CanonicalWireJson;
import wordpress.hx.contracts.ContractCodec;
import wordpress.hx.contracts.ContractError;
import wordpress.hx.contracts.ContractRuleSet;
import wordpress.hx.contracts.ContractValidator;
import wordpress.hx.contracts.DecodeResult;
import wordpress.hx.contracts.NoContractRules;
import wordpress.hx.contracts.NullableValue;
import wordpress.hx.contracts.Presence;
import wordpress.hx.contracts.RuleEvaluation;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireValue.WireField;
import wordpress.hx.contracts.schema.FieldDefault;
import wordpress.hx.contracts.schema.FieldDefaults;
import wordpress.hx.contracts.schema.FieldRequirement;
import wordpress.hx.contracts.schema.MigrationRef;
import wordpress.hx.contracts.schema.RuleId;
import wordpress.hx.contracts.schema.RuleParity;
import wordpress.hx.contracts.schema.SchemaDocument;
import wordpress.hx.contracts.schema.SchemaCase;
import wordpress.hx.contracts.schema.SchemaField;
import wordpress.hx.contracts.schema.SchemaId;
import wordpress.hx.contracts.schema.SchemaJson;
import wordpress.hx.contracts.schema.SchemaNode;
import wordpress.hx.contracts.schema.SchemaRuleRef;
import wordpress.hx.contracts.schema.UnknownFieldPolicy;

class SchemaAuthorityTest {
	static function main():Void {
		final codec = new ArticleCodec();
		final lines = ["schema=" + CanonicalWireJson.encode(SchemaJson.encode(codec.schema()))];
		lines.push("schema-invariants=" + verifySchemaInvariants());
		run(lines, codec, "missing-optional", articleWire());
		run(lines, codec, "explicit-null", articleWire([{name: "summary", value: NullValue}]));
		run(lines, codec, "present-summary", articleWire([{name: "summary", value: StringValue("A bounded field note.")}]));
		run(lines, codec, "unicode-title", articleWire([{name: "title", value: StringValue("Café 🚀")}]));
		run(lines, codec, "decomposed-title", articleWire([{name: "title", value: StringValue("Cafe\u0301")}]));
		run(lines, codec, "missing-required", object([
			field("id", IntegerValue(7)),
			field("status", StringValue("published")),
			field("tags", ArrayValue([]))
		]));
		run(lines, codec, "wrong-type", articleWire([{name: "id", value: StringValue("7")}]));
		run(lines, codec, "zero-id", articleWire([{name: "id", value: IntegerValue(0)}]));
		run(lines, codec, "unknown-enum", articleWire([{name: "status", value: StringValue("scheduled")}]));
		run(lines, codec, "empty-tag", articleWire([{name: "tags", value: ArrayValue([StringValue("")])}]));
		run(lines, codec, "too-many-tags", articleWire([
			{name: "tags", value: ArrayValue([for (index in 0...9) StringValue("tag-" + index)])}
		]));
		run(lines, codec, "unknown-field", articleWire([{name: "extra", value: BoolValue(true)}]));
		run(lines, codec, "unicode-key-order", articleWire([{name: "𐀀", value: BoolValue(true)}, {name: "", value: BoolValue(true)}]));
		run(lines, codec, "duplicate-field", duplicateArticleWire());
		run(lines, codec, "invalid-title", articleWire([{name: "title", value: StringValue("   ")}]));
		run(lines, codec, "null-required", articleWire([{name: "title", value: NullValue}]));
		lines.push("encode-invariants=" + verifyEncodeInvariants(codec));

		final output = lines.join("\n") + "\n";
		#if js
		Node.process.stdout.write(output);
		#else
		Sys.print(output);
		#end
	}

	static function verifySchemaInvariants():String {
		var verified = 0;
		verified += assertSchemaFailure("reversed integer bounds", () -> schema(IntegerNode(Present(2), Present(1))));
		verified += assertSchemaFailure("empty enum", () -> schema(EnumNode([])));
		verified += assertSchemaFailure("duplicate fields", () -> schema(ObjectNode([
			new SchemaField("title", FieldRequirement.Required, BooleanNode, NoDefault),
			new SchemaField("title", FieldRequirement.Optional, BooleanNode, NoDefault)
		], UnknownFieldPolicy.Reject)));
		verified += assertSchemaFailure("nested nullable", () -> schema(NullableNode(NullableNode(BooleanNode))));
		verified += assertSchemaFailure("negative array count", () -> schema(ArrayNode(BooleanNode, Present(-1), Missing)));
		verified += assertSchemaFailure("incomplete migration chain",
			() -> new SchemaDocument(SchemaId.parse("site.incomplete"), 2, BooleanNode, [], new NoContractRules()));

		final rule = new SchemaRuleRef(RuleId.parse("site.shared-rule"), 1, RuleParity.Exact);
		verified += assertSchemaFailure("validator and sanitizer collision", () -> schema(RefinedNode(BooleanNode, [rule], [rule])));
		final nativeValidator = new SchemaRuleRef(RuleId.parse("wordpress.native-only-validation"), 1, RuleParity.DocumentedNativeRelation);
		verified += assertSchemaFailure("non-exact validator", () -> schema(RefinedNode(BooleanNode, [nativeValidator], [])));
		verified += assertSchemaFailure("required field default", () -> schema(ObjectNode([
			new SchemaField("status", FieldRequirement.Required, EnumNode(["draft"]), FieldDefaults.whenMissing(StringValue("draft")))
		], UnknownFieldPolicy.Reject)));
		verified += assertSchemaFailure("default shape", () -> schema(ObjectNode([
			new SchemaField("count", FieldRequirement.Optional, IntegerNode(Present(1), Missing), FieldDefaults.whenMissing(StringValue("one")))
		], UnknownFieldPolicy.Reject)));

		final sourceValues = ["first"];
		final snapshot = schema(EnumNode(sourceValues));
		sourceValues.push("mutated-after-construction");
		final encoded = CanonicalWireJson.encode(SchemaJson.encode(snapshot));
		if (encoded.indexOf("mutated-after-construction") >= 0) {
			throw new haxe.Exception("schema collection did not snapshot authored values");
		}
		verified++;

		final sourceDefaultItems:Array<WireValue> = [StringValue("first")];
		final sourceDefaultFields:Array<WireField> = [field("items", ArrayValue(sourceDefaultItems))];
		final defaultSnapshot = schema(ObjectNode([
			new SchemaField("settings", FieldRequirement.Optional, ObjectNode([
				new SchemaField("items", FieldRequirement.Required, ArrayNode(StringNode(Present(1), Missing), Missing, Missing), NoDefault)
			],
				UnknownFieldPolicy.Reject), FieldDefaults.whenMissing(ObjectValue(sourceDefaultFields)))
		], UnknownFieldPolicy.Reject));
		sourceDefaultItems.push(StringValue("mutated-nested-item"));
		sourceDefaultFields.push(field("mutated-field", BoolValue(true)));
		final encodedDefaultSnapshot = CanonicalWireJson.encode(SchemaJson.encode(defaultSnapshot));
		if (encodedDefaultSnapshot.indexOf("mutated-nested-item") >= 0 || encodedDefaultSnapshot.indexOf("mutated-field") >= 0) {
			throw new haxe.Exception("schema default did not snapshot its nested wire value");
		}
		verified++;

		final projectedDefault = SchemaJson.encode(defaultSnapshot);
		if (!mutateFirstStringArray(projectedDefault)) {
			throw new haxe.Exception("schema default projection fixture did not expose its copied array");
		}
		final encodedAfterProjectionMutation = CanonicalWireJson.encode(SchemaJson.encode(defaultSnapshot));
		if (encodedAfterProjectionMutation.indexOf("mutated-output-item") >= 0) {
			throw new haxe.Exception("mutating a schema projection changed the retained default");
		}
		verified++;

		final cyclicItems:Array<WireValue> = [];
		final cyclicDefault:WireValue = ArrayValue(cyclicItems);
		cyclicItems.push(cyclicDefault);
		verified += assertSchemaFailure("cyclic default", function():Void {
			FieldDefaults.whenMissing(cyclicDefault);
		});
		final cyclicFields:Array<WireField> = [];
		final cyclicObjectDefault:WireValue = ObjectValue(cyclicFields);
		cyclicFields.push(field("self", cyclicObjectDefault));
		verified += assertSchemaFailure("cyclic object default", function():Void {
			FieldDefaults.whenMissing(cyclicObjectDefault);
		});

		final nonBlank = new SchemaRuleRef(RuleId.parse("site.article.title.nonblank"), 1, RuleParity.Exact);
		verified += assertSchemaFailure("named-rule-invalid default", () -> schemaWithRules(ObjectNode([
			new SchemaField("title", FieldRequirement.Optional, RefinedNode(StringNode(Present(1), Missing), [nonBlank], []),
				FieldDefaults.whenMissing(StringValue("   ")))
		], UnknownFieldPolicy.Reject), new ArticleRules()));
		verified += assertSchemaFailure("nested refinement", () -> schema(RefinedNode(RefinedNode(BooleanNode, [], []), [], [])));

		final tagged = schema(TaggedUnionNode("kind", "value", [new SchemaCase("text", StringNode(Present(1), Present(20)))]));
		verified += assertAccepted("tagged union",
			ContractValidator.validate(object([field("kind", StringValue("text")), field("value", StringValue("hello"))]), tagged));
		verified += assertRejected("unknown union tag",
			ContractValidator.validate(object([field("kind", StringValue("image")), field("value", StringValue("hello"))]), tagged), "WPHX5205", "/kind");

		final refinedRoot = schemaWithRules(RefinedNode(StringNode(Present(1), Missing), [nonBlank], []), new ArticleRules());
		verified += assertRejected("refined scalar root", ContractValidator.validate(StringValue("   "), refinedRoot), "WPHX5205", "");
		final refinedItems = schemaWithRules(ArrayNode(RefinedNode(StringNode(Present(1), Missing), [nonBlank], []), Missing, Missing), new ArticleRules());
		verified += assertRejected("refined array item", ContractValidator.validate(ArrayValue([StringValue("   ")]), refinedItems), "WPHX5205", "/0");
		final refinedPayload = schemaWithRules(TaggedUnionNode("kind", "value", [
			new SchemaCase("text", RefinedNode(StringNode(Present(1), Missing), [nonBlank], []))
		]), new ArticleRules());
		verified += assertRejected("refined union payload",
			ContractValidator.validate(object([field("kind", StringValue("text")), field("value", StringValue("   "))]), refinedPayload), "WPHX5205", "/value");

		final unavailableRule = new SchemaRuleRef(RuleId.parse("site.unavailable"), 1, RuleParity.Exact);
		final unavailable = schema(ObjectNode([
			new SchemaField("value", FieldRequirement.Required, RefinedNode(BooleanNode, [unavailableRule], []), NoDefault)
		], UnknownFieldPolicy.Reject));
		verified += assertRejected("unavailable rule", ContractValidator.validate(object([field("value", BoolValue(true))]), unavailable), "WPHX5206",
			"/value");

		final oneScalar = schema(StringNode(Present(1), Present(1)));
		verified += assertAccepted("one non-BMP Unicode scalar", ContractValidator.validate(StringValue("🚀"), oneScalar));
		verified += assertRejected("two Unicode scalars", ContractValidator.validate(StringValue("éx"), oneScalar), "WPHX5205", "");

		final closedEmpty = schema(ObjectNode([], UnknownFieldPolicy.Reject));
		verified += assertRejected("JSON Pointer escaping", ContractValidator.validate(object([field("a/b~c", BoolValue(true))]), closedEmpty), "WPHX5203",
			"/a~1b~0c");

		final withDefault = schema(ObjectNode([
			new SchemaField("status", FieldRequirement.Optional, EnumNode(["draft", "published"]), FieldDefaults.whenMissing(StringValue("draft")))
		], UnknownFieldPolicy.Reject));
		switch ContractValidator.validate(object([]), withDefault) {
			case Decoded(value):
				if (CanonicalWireJson.encode(value) != '{"status":"draft"}') {
					throw new haxe.Exception("missing-field default was not materialized canonically");
				}
				verified++;
			case Rejected(_):
				throw new haxe.Exception("valid missing-field default was rejected");
		}

		return verified + "/27";
	}

	static function mutateFirstStringArray(value:WireValue):Bool {
		return switch value {
			case ArrayValue(values):
				if (values.length == 1) {
					switch values[0] {
						case StringValue("first"):
							values.push(StringValue("mutated-output-item"));
							true;
						case _:
							mutateFirstChild(values);
					}
				} else {
					mutateFirstChild(values);
				}
			case ObjectValue(fields):
				var mutated = false;
				for (field in fields) {
					if (!mutated && mutateFirstStringArray(field.value)) {
						mutated = true;
					}
				}
				mutated;
			case _:
				false;
		};
	}

	static function mutateFirstChild(values:Array<WireValue>):Bool {
		for (value in values) {
			if (mutateFirstStringArray(value)) {
				return true;
			}
		}
		return false;
	}

	static function assertAccepted(label:String, result:DecodeResult<WireValue>):Int {
		return switch result {
			case Decoded(_): 1;
			case Rejected(_): throw new haxe.Exception(label + " unexpectedly failed");
		};
	}

	static function assertRejected(label:String, result:DecodeResult<WireValue>, code:String, path:String):Int {
		return switch result {
			case Decoded(_): throw new haxe.Exception(label + " unexpectedly passed");
			case Rejected(issues):
				if (issues.length != 1 || issues[0].code != code || issues[0].path != path) {
					throw new haxe.Exception(label + " produced a non-canonical issue");
				}
				1;
		};
	}

	static function assertSchemaFailure(label:String, operation:Void->Void):Int {
		try {
			operation();
		} catch (_:ContractError) {
			return 1;
		}
		throw new haxe.Exception(label + " did not fail closed");
	}

	static function schema(root:SchemaNode):SchemaDocument {
		return schemaWithRules(root, new NoContractRules());
	}

	static function schemaWithRules(root:SchemaNode, rules:ContractRuleSet):SchemaDocument {
		return new SchemaDocument(SchemaId.parse("site.invariant"), 1, root, [], rules);
	}

	static function verifyEncodeInvariants(codec:ArticleCodec):String {
		final article = new Article(ArticleId.fromValidated(7), "Typed boundaries", ArticleStatus.fromValidated("published"), ["compiler"], Missing);
		article.tags.push("");
		try {
			codec.encode(article);
		} catch (_:ContractError) {
			return "1/1";
		}
		throw new haxe.Exception("development codec admitted invalid mutable domain state");
	}

	static function run(lines:Array<String>, codec:ArticleCodec, label:String, value:WireValue):Void {
		switch codec.decode(value) {
			case Decoded(article):
				lines.push(label + "=" + CanonicalWireJson.encode(codec.encode(article)));
			case Rejected(issues):
				if (issues.length != 1) {
					throw new haxe.Exception(label + " did not produce exactly one canonical issue");
				}
				final issue = issues[0];
				lines.push(label + "=" + CanonicalWireJson.encode(object([
					field("actual", StringValue(issue.actual)),
					field("code", StringValue(issue.code)),
					field("expected", StringValue(issue.expected)),
					field("path", StringValue(issue.path))
				])));
		}
	}

	static function articleWire(?replacements:Array<WireField>):WireValue {
		final fields = baseArticleFields();
		if (replacements != null) {
			for (replacement in replacements) {
				var replaced = false;
				for (index in 0...fields.length) {
					if (fields[index].name == replacement.name) {
						fields[index] = replacement;
						replaced = true;
						break;
					}
				}
				if (!replaced) {
					fields.push(replacement);
				}
			}
		}
		return object(fields);
	}

	static function duplicateArticleWire():WireValue {
		final fields = baseArticleFields();
		fields.push(field("title", StringValue("Second title")));
		return object(fields);
	}

	static function baseArticleFields():Array<WireField> {
		return [
			field("id", IntegerValue(7)),
			field("status", StringValue("published")),
			field("tags", ArrayValue([StringValue("compiler"), StringValue("wordpress")])),
			field("title", StringValue("Typed boundaries"))
		];
	}

	static function object(fields:Array<WireField>):WireValue {
		return ObjectValue(fields);
	}

	static function field(name:String, value:WireValue):WireField {
		return {name: name, value: value};
	}
}

private class ArticleCodec implements ContractCodec<Article> {
	static final RULES = new ArticleRules();
	static final ARTICLE_SCHEMA = createSchema();

	public function new() {}

	public function schema():SchemaDocument {
		return ARTICLE_SCHEMA;
	}

	static function createSchema():SchemaDocument {
		final nonBlank = new SchemaRuleRef(RuleId.parse("site.article.title.nonblank"), 1, RuleParity.Exact);
		final summarySanitizer = new SchemaRuleRef(RuleId.parse("wordpress.sanitize-text-field"), 1, RuleParity.DocumentedNativeRelation);
		return new SchemaDocument(SchemaId.parse("site.article"), 2, ObjectNode([
			new SchemaField("id", FieldRequirement.Required, IntegerNode(Present(1), Present(2147483647)), NoDefault),
			new SchemaField("status", FieldRequirement.Required, EnumNode(["draft", "published"]), NoDefault),
			new SchemaField("summary", FieldRequirement.Optional, RefinedNode(NullableNode(StringNode(Missing, Present(160))), [], [summarySanitizer]),
				NoDefault),
			new SchemaField("tags", FieldRequirement.Required, ArrayNode(StringNode(Present(1), Present(32)), Missing, Present(8)), NoDefault),
			new SchemaField("title", FieldRequirement.Required, RefinedNode(StringNode(Present(1), Present(120)), [nonBlank], []), NoDefault)
		],
			UnknownFieldPolicy.Reject), [new MigrationRef(1, 2, RuleId.parse("site.article.v1-to-v2"), 1)], RULES);
	}

	public function encode(article:Article):WireValue {
		final fields:Array<WireField> = [
			{name: "id", value: IntegerValue(article.id.toInt())},
			{name: "status", value: StringValue(article.status.asString())},
			{name: "tags", value: ArrayValue([for (tag in article.tags) StringValue(tag)])},
			{name: "title", value: StringValue(article.title)}
		];
		switch article.summary {
			case Missing:
			case Present(ExplicitNull):
				fields.push({name: "summary", value: NullValue});
			case Present(NonNull(value)):
				fields.push({name: "summary", value: StringValue(value)});
		}
		final encoded = ObjectValue(fields);
		return switch ContractValidator.validate(encoded, ARTICLE_SCHEMA) {
			case Decoded(validated): validated;
			case Rejected(issues):
				throw new ContractError("domain encoder violated article schema: " + issues[0].code + " " + issues[0].path);
		};
	}

	public function decode(value:WireValue):DecodeResult<Article> {
		return switch ContractValidator.validate(value, ARTICLE_SCHEMA) {
			case Rejected(issues): Rejected(issues);
			case Decoded(validated): Decoded(decodeValidated(validated));
		};
	}

	static function decodeValidated(value:WireValue):Article {
		final fields = objectFields(value);
		final id = ArticleId.fromValidated(readInteger(required(fields, "id")));
		final title = readString(required(fields, "title"));
		final status = ArticleStatus.fromValidated(readString(required(fields, "status")));
		final tags = readTags(required(fields, "tags"));
		final summary = readSummary(fields);
		return new Article(id, title, status, tags, summary);
	}

	static function impossible<T>(message:String):T {
		throw new ContractError("schema validator admitted an impossible article shape: " + message);
	}

	static function objectFields(value:WireValue):Array<WireField> {
		return switch value {
			case ObjectValue(fields): fields;
			case _: impossible("root is not an object");
		};
	}

	static function required(fields:Array<WireField>, name:String):WireValue {
		return switch find(fields, name) {
			case Missing: impossible("required field " + name + " is absent");
			case Present(value): value;
		};
	}

	static function readInteger(value:WireValue):Int {
		return switch value {
			case IntegerValue(number): number;
			case _: impossible("integer field changed kind");
		};
	}

	static function readString(value:WireValue):String {
		return switch value {
			case StringValue(text): text;
			case _: impossible("string field changed kind");
		};
	}

	static function readTags(value:WireValue):Array<String> {
		return switch value {
			case ArrayValue(values): [for (value in values) readString(value)];
			case _: impossible("tags field is not an array");
		};
	}

	static function readSummary(fields:Array<WireField>):Presence<NullableValue<String>> {
		return switch find(fields, "summary") {
			case Missing: Missing;
			case Present(NullValue): Present(ExplicitNull);
			case Present(StringValue(text)): Present(NonNull(text));
			case Present(_): impossible("summary is neither null nor string");
		};
	}

	static function find(fields:Array<WireField>, name:String):Presence<WireValue> {
		for (field in fields) {
			if (field.name == name) {
				return Present(field.value);
			}
		}
		return Missing;
	}
}

private class ArticleRules implements ContractRuleSet {
	public function new() {}

	public function evaluate(rule:SchemaRuleRef, value:WireValue):RuleEvaluation {
		if (rule.ruleId.asString() != "site.article.title.nonblank" || rule.revision != 1 || rule.parity != RuleParity.Exact) {
			return RuleUnavailable;
		}
		return switch value {
			case StringValue(text) if (StringTools.trim(text).length > 0): RulePassed;
			case StringValue(_): RuleRejected("constraint-failed");
			case _: RuleUnavailable;
		};
	}
}

private abstract ArticleId(Int) {
	private function new(value:Int) {
		this = value;
	}

	public static function fromValidated(value:Int):ArticleId {
		return new ArticleId(value);
	}

	public function toInt():Int {
		return this;
	}
}

private abstract ArticleStatus(String) {
	private function new(value:String) {
		this = value;
	}

	public static function fromValidated(value:String):ArticleStatus {
		return switch value {
			case "draft", "published": new ArticleStatus(value);
			case _: throw new ContractError("schema validator admitted an unknown article status");
		};
	}

	public function asString():String {
		return this;
	}
}

private class Article {
	public final id:ArticleId;
	public final title:String;
	public final status:ArticleStatus;
	public final tags:Array<String>;
	public final summary:Presence<NullableValue<String>>;

	public function new(id:ArticleId, title:String, status:ArticleStatus, tags:Array<String>, summary:Presence<NullableValue<String>>) {
		this.id = id;
		this.title = title;
		this.status = status;
		this.tags = tags.copy();
		this.summary = summary;
	}
}
