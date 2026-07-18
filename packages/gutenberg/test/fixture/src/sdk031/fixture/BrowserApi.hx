package sdk031.fixture;

typedef SignalSnapshot = {
	final before:Int;
	final after:Int;
	final setupCount:Int;
}

@:build(wordpress.hx.gutenberg.browser.BrowserExport.build("wordpresshx.sdk031.browser-api", []))
class BrowserApi {
	public final prefix:String;

	public function new(prefix:String) {
		if (prefix.length == 0) {
			throw "prefix must not be empty";
		}
		this.prefix = prefix;
	}

	public function greet(name:String):String {
		return '${prefix}, ${name}';
	}

	public function observeSignals():SignalSnapshot {
		final before = RuntimeSignals.liveValue;
		RuntimeSignals.increment();
		return {
			before: before,
			after: RuntimeSignals.liveValue,
			setupCount: RuntimeSignals.setupCount()
		};
	}

	public function nullableLabel(value:Null<String>):String {
		return value == null ? "none" : value;
	}

	public function identity<T>(value:T):T {
		return value;
	}

	private function implementationDetail():String {
		return "private";
	}
}
