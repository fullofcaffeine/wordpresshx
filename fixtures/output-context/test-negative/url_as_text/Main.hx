import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.UrlValidation;
import wordpress.hx.output.prototype.OutputSinks;

final class Main {
	static function main():Void {
		final url = switch Output.validateUrl("https://example.test/") {
			case AcceptedUrl(value): value;
			case RejectedUrl(reason): throw reason;
		};
		OutputSinks.text(Output.url(url));
	}
}
