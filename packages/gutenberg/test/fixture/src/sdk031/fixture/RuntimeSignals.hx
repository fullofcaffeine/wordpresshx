package sdk031.fixture;

@:jsRequire("./runtime/signals.js")
extern class RuntimeSignals {
	public static var liveValue(default, null):Int;

	public static function increment():Void;

	public static function setupCount():Int;
}
