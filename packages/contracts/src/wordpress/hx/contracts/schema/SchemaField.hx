package wordpress.hx.contracts.schema;

class SchemaField {
	public final jsonName:String;
	public final requirement:FieldRequirement;
	public final value:SchemaNode;
	public final defaultValue:FieldDefault;

	public function new(jsonName:String, requirement:FieldRequirement, value:SchemaNode, defaultValue:FieldDefault) {
		this.jsonName = jsonName;
		this.requirement = requirement;
		this.value = value;
		this.defaultValue = defaultValue;
	}
}
