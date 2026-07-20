import sdk060.fixture.CalloutAttributes;
import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

class Main {
	public static function main():Void {
		Block.define(CalloutAttributes, {
			name: "wordpresshx/callout",
			title: "Missing asset",
			category: BlockCategory.Design,
			assets: {editorScript: "absent-editor"}
		});
	}
}
