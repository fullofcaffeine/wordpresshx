package wordpress.hx.contracts;

enum abstract WireKind(String) to String {
	var NullKind = "null";
	var BooleanKind = "boolean";
	var IntegerKind = "integer";
	var StringKind = "string";
	var ArrayKind = "array";
	var ObjectKind = "object";

	public static function of(value:WireValue):WireKind {
		return switch value {
			case NullValue: NullKind;
			case BoolValue(_): BooleanKind;
			case IntegerValue(_): IntegerKind;
			case StringValue(_): StringKind;
			case ArrayValue(_): ArrayKind;
			case ObjectValue(_): ObjectKind;
		};
	}
}
