import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	static function main():Void {}

	static function Broken():BrowserNode {
		return <__experimentalPluginSidebar title="Private"><span>Forbidden</span></__experimentalPluginSidebar>;
	}
}
