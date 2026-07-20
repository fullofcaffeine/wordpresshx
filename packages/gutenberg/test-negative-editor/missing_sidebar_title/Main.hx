import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.editor.PluginSidebar;
import wordpress.hx.gutenberg.editor.SidebarName;

class Main {
	static final sidebar = SidebarName.literal("missing-title");

	static function main():Void {}

	static function Broken():BrowserNode {
		return <PluginSidebar name={sidebar}><span>Missing title</span></PluginSidebar>;
	}
}
