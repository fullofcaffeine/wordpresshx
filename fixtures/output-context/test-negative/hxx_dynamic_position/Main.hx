import wordpress.hx.output.prototype.HxxPositionGuard;

final class Main {
	static function main():Void {
		final attribute = "href";
		HxxPositionGuard.attribute("a", attribute);
	}
}
