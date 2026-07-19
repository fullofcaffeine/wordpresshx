package wordpress.hx.build.semantic;

/**
 * IDE-visible, no-shell command used by a typed development service.
 *
 * Haxe derives the admitted executable from the exact lock component. Omit
 * `arguments` when the component needs no argv.
 */
typedef DevelopmentCommandOptions = {
	final component:String;
	final ?arguments:Array<String>;
}
