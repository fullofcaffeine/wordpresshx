import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;

class Main {
	public static function main():Void {}

	public static function view():BrowserNode {
		return <Button mystery="unprofiled">Unknown prop</Button>;
	}
}
