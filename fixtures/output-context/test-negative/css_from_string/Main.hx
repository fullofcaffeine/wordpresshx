import wordpress.hx.output.prototype.Output;

final class Main {
	static function main():Void {
		Output.css("background:url(javascript:alert(1))");
	}
}
