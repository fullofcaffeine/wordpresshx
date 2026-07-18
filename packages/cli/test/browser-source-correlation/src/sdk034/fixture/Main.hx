package sdk034.fixture;

import js.Browser;

/** One Haxe-owned browser failure shared by development and minified builds. **/
class Main {
	static function main():Void {
		Browser.window.setTimeout(deliberateFailure, 0);
	}

	static function deliberateFailure():Void {
		throw new js.lib.Error("SDK034_DELIBERATE_BROWSER_FAILURE");
	}
}
