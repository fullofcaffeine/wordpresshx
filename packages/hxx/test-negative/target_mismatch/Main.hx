import wordpress.hx.hxx.prototype.BrowserHxx;

class Main {
	public static function main():Void {
		BrowserHxx.render(<ServerFragment token="server-only" />);
	}
}
