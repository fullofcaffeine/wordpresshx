import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.OutputSinks;

final class MessageCodec implements OutputCodec<String> {
	public function new() {}

	public function schemaId():String {
		return "message.v1";
	}
}

final class Main {
	static function main():Void {
		OutputSinks.scriptData(Output.jsonDocument(new MessageCodec(), "</script>"));
	}
}
