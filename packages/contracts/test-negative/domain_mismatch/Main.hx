import wordpress.hx.contracts.ContractCodec;
import wordpress.hx.contracts.DecodeResult;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.contracts.schema.SchemaDocument;

class Main {
	static function main():Void {
		final codec:ContractCodec<Int> = new IntegerCodec();
		acceptText(codec);
	}

	static function acceptText(codec:ContractCodec<String>):Void {}
}

private class IntegerCodec implements ContractCodec<Int> {
	public function new() {}

	public function schema():SchemaDocument {
		throw new haxe.Exception("not reached");
	}

	public function encode(value:Int):WireValue {
		return IntegerValue(value);
	}

	public function decode(value:WireValue):DecodeResult<Int> {
		return Rejected([]);
	}
}
