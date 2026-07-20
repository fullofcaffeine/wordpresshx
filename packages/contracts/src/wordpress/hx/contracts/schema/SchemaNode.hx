package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.Presence;

enum SchemaNode {
	BooleanNode;
	IntegerNode(minimum:Presence<Int>, maximum:Presence<Int>);
	StringNode(minLength:Presence<Int>, maxLength:Presence<Int>);
	EnumNode(values:FrozenList<String>);
	ArrayNode(value:SchemaNode, minItems:Presence<Int>, maxItems:Presence<Int>);
	ObjectNode(fields:FrozenList<SchemaField>, unknownFields:UnknownFieldPolicy);
	TaggedUnionNode(discriminator:String, payloadField:String, cases:FrozenList<SchemaCase>);
	NullableNode(value:SchemaNode);
	RefinedNode(value:SchemaNode, validators:FrozenList<SchemaRuleRef>, sanitizers:FrozenList<SchemaRuleRef>);
}
