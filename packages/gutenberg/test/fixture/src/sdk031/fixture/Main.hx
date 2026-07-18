package sdk031.fixture;

import genes.ts.Imports;

class Main {
	static function __init__():Void {
		Imports.sideEffect("./runtime/setup.js");
	}

	public static function main():Void {}
}
