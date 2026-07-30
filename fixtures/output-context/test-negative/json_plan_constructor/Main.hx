import wordpress.hx.output.prototype.OutputSinks.JsonPlan;

class Main {
	static function main():Void {
		new JsonPlan("forged.v1", '{"unsafe":"caller-authored"}', "");
	}
}
