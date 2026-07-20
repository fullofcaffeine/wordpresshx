package sdk061.fixture;

import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockCategory;

final class MetadataMain {
	public static function main():Void {
		Block.define(CalloutAttributes, {
			name: "wordpresshx/callout",
			title: "Durable callout",
			category: BlockCategory.Design,
			description: "A typed static note with native serialization and migration.",
			icon: "megaphone",
			keywords: ["notice", "migration"],
			version: "1.0.0",
			supports: {
				customClassName: false,
				html: false
			},
			assets: {
				editorScript: "callout-editor",
				style: "callout-style"
			}
		});
	}
}
