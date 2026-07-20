import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.editor.EditorPlugins;
import wordpress.hx.gutenberg.editor.SidebarName;

class Main {
	static function main():Void {
		EditorPlugins.register(SidebarName.literal("wrong-kind"), render);
	}

	static function render():BrowserNode {
		return <span>Wrong identity</span>;
	}
}
