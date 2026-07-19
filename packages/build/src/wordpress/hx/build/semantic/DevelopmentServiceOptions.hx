package wordpress.hx.build.semantic;

/**
 * Explicit Haxe-only service declaration for an external process.
 *
 * `Dev.wordpress()` owns the built-in WordPress provider and needs no command.
 * Use this shape only when an SDK adapter does not yet exist.
 */
typedef DevelopmentServiceOptions = {
	final id:String;
	final command:DevelopmentCommandOptions;
	final ?workingDirectory:String;
	final ?dependsOn:Array<String>;
	final ?environment:Array<String>;
	final ?preferredPort:Int;
	final ?strictPort:Bool;
	final ?readinessKind:DevelopmentReadinessKind;
	final ?readinessPath:String;
	final ?readinessText:String;
	final ?readinessTimeoutMs:Int;
	final ?readinessIntervalMs:Int;
	final ?restartAttempts:Int;
	final ?restartBackoffMs:Int;
	final ?urlPath:String;
}
