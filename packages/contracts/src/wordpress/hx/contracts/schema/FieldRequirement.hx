package wordpress.hx.contracts.schema;

enum abstract FieldRequirement(String) to String {
	var Required = "required";
	var Optional = "optional";
}
