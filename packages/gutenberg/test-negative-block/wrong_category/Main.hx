import sdk060.fixture.CalloutAttributes;
import wordpress.hx.gutenberg.block.Block;

enum abstract LookalikeCategory(String) {
	var Design = "design";
}

class Main {
	public static function main():Void {
		Block.define(CalloutAttributes, {
			name: "wordpresshx/callout",
			title: "Lookalike category",
			category: LookalikeCategory.Design,
			assets: {editorScript: "callout-editor"}
		});
	}
}
