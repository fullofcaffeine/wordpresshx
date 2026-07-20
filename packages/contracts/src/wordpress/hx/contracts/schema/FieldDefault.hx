package wordpress.hx.contracts.schema;

enum FieldDefault {
	NoDefault;
	DefaultWhenMissing(value:FrozenWireValue);
}
