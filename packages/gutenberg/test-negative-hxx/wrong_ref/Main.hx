import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;
import wordpress.hx.gutenberg.react.Hooks.useRef;

class Main {
	public static function main():Void {}

	public static function view():BrowserNode {
		final wrongRef = useRef((null : Null<String>));
		return <Button ref={wrongRef}>Wrong ref</Button>;
	}
}
