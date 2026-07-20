package wordpress.hx.contracts.schema;

class SchemaCase {
	public final tag:String;
	public final value:SchemaNode;

	public function new(tag:String, value:SchemaNode) {
		this.tag = tag;
		this.value = value;
	}
}
