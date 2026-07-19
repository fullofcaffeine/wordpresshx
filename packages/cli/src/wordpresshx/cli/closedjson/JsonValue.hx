package wordpresshx.cli.closedjson;

/** Closed JSON representation for authenticated runtime boundaries. */
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
