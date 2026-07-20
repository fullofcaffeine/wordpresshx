import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

extern class InvalidAttributes {
	@:wpDefault("six")
	public var count:Int;
}

class Main {
	public static function main():Void {
		Block.define(InvalidAttributes, {
			name: "wordpresshx/callout",
			title: "Wrong default",
			category: BlockCategory.Design,
			assets: {editorScript: "callout-editor"}
		});
	}
}
