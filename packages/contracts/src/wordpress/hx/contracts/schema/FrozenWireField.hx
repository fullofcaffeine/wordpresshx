package wordpress.hx.contracts.schema;

/** One immutable member of a frozen wire object. */
final class FrozenWireField {
	public final name:String;
	public final value:FrozenWireValue;

	public function new(name:String, value:FrozenWireValue) {
		this.name = name;
		this.value = value;
	}
}
