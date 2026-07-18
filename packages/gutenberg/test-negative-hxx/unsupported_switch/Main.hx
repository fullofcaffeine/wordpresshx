import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	public static function main():Void {}

	public static function view(mode:String):BrowserNode {
		return <main>
			<switch {mode}>
				<case {"proof"}><span>Proof</span>
			</switch>
		</main>;
	}
}
