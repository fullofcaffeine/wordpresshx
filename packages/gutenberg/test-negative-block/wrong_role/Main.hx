import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

enum abstract AttributeRole(String) {
	var Content = "content";
}

extern class InvalidRoleAttributes {
	@:wpRole(AttributeRole.Content)
	@:wpDefault("")
	public var message:String;
}

class Main {
	public static function main():Void {
		Block.define(InvalidRoleAttributes, {
			name: "wordpresshx/callout",
			title: "Lookalike role",
			category: BlockCategory.Design,
			assets: {editorScript: "callout-editor"}
		});
	}
}
