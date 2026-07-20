package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.WireValue;

class FieldDefaults {
	public static function whenMissing(value:WireValue):FieldDefault {
		return DefaultWhenMissing(FrozenWireValueTools.snapshot(value));
	}
}
