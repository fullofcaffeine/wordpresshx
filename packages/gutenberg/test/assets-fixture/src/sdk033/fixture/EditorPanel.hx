package sdk033.fixture;

import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;
import wordpress.hx.gutenberg.components.ButtonProps.ButtonVariant;
import wordpress.hx.gutenberg.i18n.I18n.__;

@:build(wordpress.hx.gutenberg.browser.BrowserExport.build("wordpresshx.sdk033.editor-panel",
	["gutenberg.package.@wordpress/components", "gutenberg.package.@wordpress/i18n"]))
class EditorPanel {
	public static function App():BrowserNode {
		return <section class="sdk033-proof" aria-labelledby="sdk033-proof-title">
			<p class="sdk033-proof__eyebrow">WORDPRESSHX / FINAL ASSET PROOF</p>
			<h2 id="sdk033-proof-title">{__("Bundle metadata, under proof.", "wordpresshx-sdk033")}</h2>
			<Button variant={ButtonVariant.Primary}>{__("Inspect final dependencies", "wordpresshx-sdk033")}</Button>
		</section>;
	}
}
