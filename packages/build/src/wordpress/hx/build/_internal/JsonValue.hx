package wordpress.hx.build._internal;

#if macro
/** Closed JSON representation used at compiler-owned file boundaries. */
enum JsonValue {
	NullValue;
	BoolValue(value:Bool);
	NumberValue(source:String);
	StringValue(value:String);
	ArrayValue(values:Array<JsonValue>);
	ObjectValue(fields:Array<JsonField>);
}

typedef JsonField = {
	final name:String;
	final value:JsonValue;
}
#end
