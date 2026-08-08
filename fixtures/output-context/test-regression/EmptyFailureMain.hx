package;

import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.JsonEncoding;
import wordpress.hx.output.prototype.Output.OutputCodec;
import wordpress.hx.output.prototype.OutputSinks;

final class EmptyFailureCodec implements OutputCodec<String> {
	public function new() {}

	public function schemaId():String {
		return "empty-failure.v1";
	}

	public function encode(value:String):JsonEncoding {
		return EncodingFailure("");
	}
}

final class EmptyFailureMain {
	static function main():Void {
		final plan = OutputSinks.restJson(Output.jsonDocument(new EmptyFailureCodec(), "rejected"));
		plan.fold(encoded -> throw new haxe.Exception("empty codec failure emitted bytes: " + encoded), reason -> {
			if (reason != "codec-rejected-without-reason") {
				throw new haxe.Exception("empty codec failure returned an unstable reason: " + reason);
			}
			return reason;
		});
	}
}
