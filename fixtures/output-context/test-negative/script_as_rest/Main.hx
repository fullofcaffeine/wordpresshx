import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.contracts.WireValue;
import wordpress.hx.output.prototype.OutputSinks;

final class MessageCodec implements OutputCodec<String> {
	public function new() {}

	public function schemaId():String {
		return "message.v1";
	}

	public function encode(value:String):JsonEncoding {
		return EncodedValue(StringValue("message"));
	}
}

final class Main {
	static function main():Void {
		OutputSinks.restJson(Output.scriptData(new MessageCodec(), "</script>"));
	}
}
