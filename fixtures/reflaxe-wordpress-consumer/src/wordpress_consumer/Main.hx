package wordpress_consumer;

import wordpress.hx.wordpress.TextOptions;

/** Ordinary Haxe plugin entry: no PHP source and no backend IR. */
class Main {
	public static function main():Void {
		TextOptions.set("wordpresshx_reflaxe_consumer", "ordinary-haxe");
	}
}
