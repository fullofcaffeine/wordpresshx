package wordpress.hx.contracts.schema;

/** Recursively immutable wire value retained by canonical schema metadata. */
enum FrozenWireValue {
	FrozenNull;
	FrozenBool(value:Bool);
	FrozenInteger(value:Int);
	FrozenString(value:String);
	FrozenArray(values:FrozenList<FrozenWireValue>);
	FrozenObject(fields:FrozenList<FrozenWireField>);
}
