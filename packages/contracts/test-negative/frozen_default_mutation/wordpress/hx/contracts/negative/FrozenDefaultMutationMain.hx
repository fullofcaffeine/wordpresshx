package wordpress.hx.contracts.negative;

import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.schema.FieldDefault;
import wordpress.hx.contracts.schema.FieldDefaults;
import wordpress.hx.contracts.schema.FrozenWireValue;

class FrozenDefaultMutationMain {
	static function main():Void {
		final defaultValue = FieldDefaults.whenMissing(ArrayValue([StringValue("first")]));
		switch defaultValue {
			case DefaultWhenMissing(FrozenArray(values)):
				values.push(FrozenString("mutated"));
			case _:
		}
	}
}
