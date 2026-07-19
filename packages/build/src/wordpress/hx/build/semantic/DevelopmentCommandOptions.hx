package wordpress.hx.build.semantic;

/** IDE-visible, no-shell command used by a typed development service. */
typedef DevelopmentCommandOptions = {
	final component:String;
	final executable:String;
	final arguments:Array<String>;
}
