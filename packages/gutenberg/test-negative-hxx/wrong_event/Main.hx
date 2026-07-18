import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;

class Main {
	public static function main():Void {}

	public static function view():BrowserNode {
		final wrongHandler = (value:String) -> {};
		return <Button onClick={wrongHandler}>Wrong event</Button>;
	}
}
