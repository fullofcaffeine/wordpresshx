package wordpress.hx.compiler.php.profile;

import reflaxe.php.ir.PhpIdentifier;

/** One dynamic native register_block_type render boundary. **/
class WordPressBlockRegistration {
	static final BLOCK_NAME = ~/^[a-z0-9]+(?:-[a-z0-9]+)*\/[a-z0-9]+(?:-[a-z0-9]+)*$/;

	public final blockName:String;
	public final renderCallback:PhpIdentifier;

	public function new(blockName:String, renderCallback:PhpIdentifier) {
		if (blockName == null || !BLOCK_NAME.match(blockName) || renderCallback == null) {
			throw "WordPress block registration requires a namespace/name and render callback";
		}
		this.blockName = blockName;
		this.renderCallback = renderCallback;
	}
}
