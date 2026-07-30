package wordpress.hx.contracts.negative;

import wordpress.hx.contracts.CanonicalWireJson;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.WireValue.WireField;

class MalformedWireValueMain {
	static function main():Void {
		final nullRoot:WireValue = null;
		final nullElements:Array<WireValue> = [null];
		final nullFields:Array<WireField> = [null];
		CanonicalWireJson.encodeChecked(nullRoot);
		CanonicalWireJson.encodeChecked(StringValue(null));
		CanonicalWireJson.encodeChecked(ArrayValue(null));
		CanonicalWireJson.encodeChecked(ArrayValue(nullElements));
		CanonicalWireJson.encodeChecked(ObjectValue(null));
		CanonicalWireJson.encodeChecked(ObjectValue(nullFields));
		CanonicalWireJson.encodeChecked(ObjectValue([{name: null, value: NullValue}]));
		CanonicalWireJson.encodeChecked(ObjectValue([{name: "value", value: null}]));
	}
}
