import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

class Main {
	static function main():Void {
		JsonPlan.success("forged.v1", '{"unsafe":"caller-authored"}');
	}
}
