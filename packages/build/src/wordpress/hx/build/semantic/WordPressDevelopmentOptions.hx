package wordpress.hx.build.semantic;

/** Optional overrides for the zero-configuration `Dev.wordpress()` path. */
typedef WordPressDevelopmentOptions = {
	final ?id:String;
	final ?workingDirectory:String;
	final ?dependsOn:Array<String>;
	final ?environment:Array<String>;
	final ?preferredPort:Int;
	final ?strictPort:Bool;
	final ?readinessKind:DevelopmentReadinessKind;
	final ?readinessPath:String;
	final ?readinessTimeoutMs:Int;
	final ?readinessIntervalMs:Int;
	final ?restartAttempts:Int;
	final ?restartBackoffMs:Int;
	final ?urlPath:String;
}
