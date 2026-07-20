package wordpress.hx.contracts.negative;

import wordpress.hx.contracts.WireValue;

class RawNullMain {
	static function main():Void {
		final value:WireValue = null;
		consume(value);
	}

	static function consume(value:WireValue):Void {}
}
