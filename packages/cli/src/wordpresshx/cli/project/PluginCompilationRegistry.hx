package wordpresshx.cli.project;

/** Process-local handoff from one bounded compiler invocation to its build. */
class PluginCompilationRegistry {
	static final plans = new Map<String, PluginPlan>();

	public static function clear(projectRoot:String):Void {
		plans.remove(projectRoot);
	}

	public static function put(projectRoot:String, plan:PluginPlan):Void {
		plans.set(projectRoot, plan);
	}

	public static function get(projectRoot:String):Null<PluginPlan> {
		return plans.get(projectRoot);
	}
}
