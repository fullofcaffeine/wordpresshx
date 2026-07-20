package wordpress.hx.contracts;

/** Closed JSON-compatible value algebra used at contract boundaries. */
enum WireValue {
	NullValue;
	BoolValue(value:Bool);
	IntegerValue(value:Int);
	StringValue(value:String);
	ArrayValue(values:Array<WireValue>);
	ObjectValue(fields:Array<WireField>);
}

typedef WireField = {
	final name:String;
	final value:WireValue;
}
