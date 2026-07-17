package wordpress.hx.core.profile;

class RuntimeRequestScope {
	private static var nextId = 0;

	private final id:Int;
	private var active:Bool;

	private function new(id:Int) {
		this.id = id;
		this.active = true;
	}

	public static function begin():RuntimeRequestScope {
		nextId += 1;
		return new RuntimeRequestScope(nextId);
	}

	public function close():Void {
		active = false;
	}

	public function assertActive():Void {
		if (!active) {
			throw new ProfileContractError("runtime capability escaped its request scope");
		}
	}

	public function isSameRequest(other:RuntimeRequestScope):Bool {
		return id == other.id;
	}
}
