import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

enum abstract LookalikeSource(String) {
	var RichText = "rich-text";
}

extern class InvalidSourceAttributes {
	@:wpSource(LookalikeSource.RichText)
	@:wpSelector("p")
	@:wpDefault("")
	public var message:String;
}

class Main {
	public static function main():Void {
		Block.define(InvalidSourceAttributes, {
			name: "wordpresshx/callout",
			title: "Lookalike source",
			category: BlockCategory.Design,
			assets: {editorScript: "callout-editor"}
		});
	}
}
