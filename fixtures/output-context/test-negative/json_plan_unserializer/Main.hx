import wordpress.hx.contracts.WireValue;
import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.OutputSinks;
import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

final class NullCodec implements OutputCodec<Int> {
	public function new() {}

	public function schemaId():String {
		return "null.v1";
	}

	public function encode(value:Int):JsonEncoding {
		return EncodedValue(WireValue.NullValue);
	}
}

final class Main {
	static function main():Void {
		final seed = OutputSinks.restJson(Output.jsonDocument(new NullCodec(), 0));
		final serialized = haxe.Serializer.run(seed);
		final modified = StringTools.replace(serialized, "y4:null", "y5:false");
		final forged:JsonPlan = haxe.Unserializer.run(modified);
		forged.fold(encoded -> {
			if (encoded != "false") {
				throw new haxe.Exception("unexpected payload");
			}
			return encoded;
		}, reason -> throw new haxe.Exception("forgery rejected: " + reason));
	}
}
