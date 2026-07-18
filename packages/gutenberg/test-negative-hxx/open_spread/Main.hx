import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;

class Main {
	public static function main():Void {}

	public static function view(attributes:Dynamic):BrowserNode {
		return <Button {...attributes}>Unsafe spread</Button>;
	}
}
