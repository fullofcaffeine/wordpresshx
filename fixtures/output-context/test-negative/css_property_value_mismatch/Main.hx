import wordpress.hx.output.prototype.Output;
import wordpress.hx.output.prototype.Output.CssLength;
import wordpress.hx.output.prototype.Output.InlineDeclaration;

final class Main {
	static function main():Void {
		Output.inlineStyle([InlineColor(Pixels(16))]);
	}
}
