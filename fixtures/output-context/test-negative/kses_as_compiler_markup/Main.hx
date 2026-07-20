import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.OutputSinks;

final class Main {
	static function main():Void {
		OutputSinks.markup(Output.postContent("<p>policy filtered is not compiler markup</p>"));
	}
}
