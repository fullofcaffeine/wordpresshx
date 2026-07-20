package sdk060.fixture;

import wordpress.hx.gutenberg.block.Block;
import wordpress.hx.gutenberg.block.BlockAlignment;
import wordpress.hx.gutenberg.block.BlockCategory;

class Main {
	public static function main():Void {
		Block.define(CalloutAttributes, {
			name: "wordpresshx/callout",
			title: "Editorial callout",
			category: BlockCategory.Design,
			description: "A focused note with a compile-time checked tone.",
			icon: "megaphone",
			keywords: ["notice", "editorial"],
			version: "1.0.0",
			supports: {
				anchor: true,
				align: [BlockAlignment.Wide, BlockAlignment.Full],
				color: {background: true, text: true},
				spacing: {margin: true, padding: true}
			},
			providesContext: [{name: "wordpresshx/tone", attribute: "tone"}],
			assets: {
				editorScript: "callout-editor",
				style: "callout-style",
				script: "wordpress-blocks-handle"
			}
		});

		Block.define(BookGridAttributes, {
			name: "wordpresshx/book-grid",
			title: "Book grid",
			category: BlockCategory.Widgets,
			usesContext: ["wordpresshx/tone"],
			supports: {align: true, html: false},
			assets: {
				editorScript: "book-grid-editor",
				render: "book-grid-render"
			}
		});
	}
}
