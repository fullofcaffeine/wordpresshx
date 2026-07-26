import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.KsesProtocol;
import wordpress.hx.output.prototype.Output.KsesTag;

final class Main {
	static function main():Void {
		final policy = Output.customKsesPolicy("mutation.v1", [Link([])], [Https]);
		policy.https = false;
	}
}
