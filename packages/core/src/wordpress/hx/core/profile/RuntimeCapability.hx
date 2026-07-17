package wordpress.hx.core.profile;

private enum RuntimeCapabilityState<T> {
	Available(value:T);
	Missing(reason:String);
}

class RuntimeCapability<T> {
	private final scope:RuntimeRequestScope;
	private final state:RuntimeCapabilityState<T>;

	private function new(scope:RuntimeRequestScope, state:RuntimeCapabilityState<T>) {
		scope.assertActive();
		this.scope = scope;
		this.state = state;
	}

	public static function available<T>(scope:RuntimeRequestScope, value:T):RuntimeCapability<T> {
		return new RuntimeCapability(scope, Available(value));
	}

	public static function missing<T>(scope:RuntimeRequestScope, reason:String):RuntimeCapability<T> {
		if (reason.length == 0) {
			throw new ProfileContractError("missing runtime capability requires a reason");
		}
		return new RuntimeCapability(scope, Missing(reason));
	}

	public function fold<R>(activeScope:RuntimeRequestScope, onAvailable:T->R, onMissing:String->R):R {
		scope.assertActive();
		activeScope.assertActive();
		if (!scope.isSameRequest(activeScope)) {
			throw new ProfileContractError("runtime capability used in a different request scope");
		}
		return switch state {
			case Available(value): onAvailable(value);
			case Missing(reason): onMissing(reason);
		}
	}
}
