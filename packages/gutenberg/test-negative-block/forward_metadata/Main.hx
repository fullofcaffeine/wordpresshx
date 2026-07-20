import sdk060.fixture.CalloutAttributes;
import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

class Main {
	public static function main():Void {
		Block.define(CalloutAttributes, {
			name: "wordpresshx/callout",
			title: "Forward metadata",
			category: BlockCategory.Design,
			viewScriptModule: "callout-editor",
			assets: {editorScript: "callout-editor"}
		});
	}
}
