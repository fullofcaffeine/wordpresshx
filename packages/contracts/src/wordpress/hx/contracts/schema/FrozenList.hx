package wordpress.hx.contracts.schema;

import wordpress.hx.contracts.ContractError;

/** An insertion-ordered snapshot with no public mutation operations. */
abstract FrozenList<T>(Array<T>) {
	private inline function new(values:Array<T>) {
		this = values.copy();
	}

	@:from
	public static function fromArray<T>(values:Array<T>):FrozenList<T> {
		if (values == null) {
			throw new ContractError("schema collection cannot be null");
		}
		return new FrozenList(values);
	}

	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:arrayAccess
	public inline function get(index:Int):T {
		return this[index];
	}

	public inline function iterator():Iterator<T> {
		return this.iterator();
	}

	public function toArray():Array<T> {
		return this.copy();
	}
}
