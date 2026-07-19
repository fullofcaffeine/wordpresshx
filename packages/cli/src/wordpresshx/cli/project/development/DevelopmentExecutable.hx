package wordpresshx.cli.project.development;

/** Exact executable identities admitted for external development services. */
class DevelopmentExecutable {
	public static function forComponent(component:String):Null<String> {
		return switch component {
			case "compiler.haxe": "haxe";
			case "runtime.node": "node";
			case "tool.lix": "lix";
			case "tool.npm": "npm";
			case "tool.wordpress-scripts": "wp-scripts";
			case _: null;
		};
	}
}
