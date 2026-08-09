import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

final class Main {
	static function main():Void {
		final construct = Type.createInstance;
		construct(JsonPlan, ["forged.reflective.alias.v1", null]);
	}
}
