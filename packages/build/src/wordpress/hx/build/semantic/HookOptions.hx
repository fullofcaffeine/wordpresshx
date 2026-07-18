package wordpress.hx.build.semantic;

/** IDE-visible shape of a literal WordPress hook declaration. */
typedef HookOptions = {
	final id:String;
	final module:String;
	final name:String;
	final callback:Dynamic;
	final ?priority:Int;
}
