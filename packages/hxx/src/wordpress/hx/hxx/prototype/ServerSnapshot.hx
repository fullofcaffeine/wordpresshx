package wordpress.hx.hxx.prototype;

/** Evidence-only server plan returned by the SDK-080 macro prototype. */
abstract ServerSnapshot(String) {
	public static inline function fromSerialized(value:String):ServerSnapshot {
		return new ServerSnapshot(value);
	}

	private inline function new(value:String) {
		this = value;
	}

	public inline function serialized():String {
		return this;
	}
}
