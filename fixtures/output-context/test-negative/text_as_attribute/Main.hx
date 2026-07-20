import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.OutputSinks;

final class Main {
	static function main():Void {
		OutputSinks.attribute(Output.text("not an attribute value"));
	}
}
