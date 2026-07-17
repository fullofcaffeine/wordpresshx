package wordpress.hx.hxx.prototype;

/** Evidence-only server plan returned by the SDK-080 macro prototype. */
abstract ServerSnapshot(String) {
	public inline function serialized():String {
		return this;
	}
}
