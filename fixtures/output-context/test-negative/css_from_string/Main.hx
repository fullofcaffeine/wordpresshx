import wordpress.hx.output.prototype.Output;

final class Main {
	static function main():Void {
		Output.inlineStyle("background:url(javascript:alert(1))");
	}
}
