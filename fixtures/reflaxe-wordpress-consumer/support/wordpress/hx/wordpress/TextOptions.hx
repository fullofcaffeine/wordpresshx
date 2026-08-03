package wordpress.hx.wordpress;

/**
 * Typed text-only view of WordPress' public option API.
 *
 * The narrow surface deliberately excludes arbitrary serialized PHP values.
 * Additional option value domains require their own checked codecs.
 */
extern class TextOptions {
	@:phpGlobalFunction("update_option")
	public static function set(name:String, value:String):Bool;
}
