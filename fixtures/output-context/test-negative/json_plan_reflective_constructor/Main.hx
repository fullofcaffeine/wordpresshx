import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

final class Main {
	static function main():Void {
		Type.createInstance(JsonPlan, ["forged.reflective.v1", null]);
	}
}
