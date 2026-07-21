package wordpress.hx.hxx.prototype;

/** Evidence-only browser plan returned by the SDK-080 macro prototype. */
abstract BrowserSnapshot(String) {
	public static inline function fromSerialized(value:String):BrowserSnapshot {
		return new BrowserSnapshot(value);
	}

	private inline function new(value:String) {
		this = value;
	}

	public inline function serialized():String {
		return this;
	}
}
