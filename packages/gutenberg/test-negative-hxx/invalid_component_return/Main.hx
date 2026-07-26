import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	public static function main():Void {}

	public static function view():BrowserNode {
		return <Main.InvalidComponent/>;
	}

	private static function InvalidComponent():Date {
		return Date.now();
	}
}
