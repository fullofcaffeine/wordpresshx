package wordpress.hx.adoption.prototype;

/** Bounded ADR-015 capability-token prototype; SDK-070/073 own production APIs. */
final class Adoption {
	public static function beginRequest<Scope>(identity:String):RequestScope<Scope> {
		return new RequestScope(identity);
	}

	public static function observeExact(providerId:String, version:String, artifactSha256:String, bindings:Array<String>):ProviderObservation {
		return ProviderObservation.exact(providerId, version, artifactSha256, bindings);
	}

	public static function observeAbsent():ProviderObservation {
		return ProviderObservation.absent();
	}

	public static function runtime<Scope>(scope:RequestScope<Scope>, observation:ProviderObservation):CapabilityRuntime<Scope> {
		return new CapabilityRuntime(scope, observation);
	}
}

final class ProviderContract<Provider> {
	public final id:String;
	public final version:String;
	public final artifactSha256:String;

	public function new(id:String, version:String, artifactSha256:String) {
		this.id = id;
		this.version = version;
		this.artifactSha256 = artifactSha256;
	}
}

final class CapabilityContract<Provider, Capability> {
	public final id:String;
	public final requiredBindings:Array<String>;

	public function new(id:String, requiredBindings:Array<String>) {
		this.id = id;
		this.requiredBindings = requiredBindings.copy();
	}
}

@:allow(wordpress.hx.adoption.prototype.Adoption)
final class RequestScope<Scope> {
	final identity:String;

	private function new(identity:String) {
		this.identity = identity;
	}

	function matches(value:String):Bool {
		return identity == value;
	}
}

private enum ObservationState {
	Exact(providerId:String, version:String, artifactSha256:String, bindings:Array<String>);
	Absent;
}

@:allow(wordpress.hx.adoption.prototype.Adoption)
final class ProviderObservation {
	final state:ObservationState;

	private function new(state:ObservationState) {
		this.state = state;
	}

	private static function exact(providerId:String, version:String, artifactSha256:String, bindings:Array<String>):ProviderObservation {
		return new ProviderObservation(Exact(providerId, version, artifactSha256, bindings.copy()));
	}

	private static function absent():ProviderObservation {
		return new ProviderObservation(Absent);
	}
}

enum CapabilityFailure {
	ProviderAbsent;
	WrongProvider;
	WrongVersion;
	WrongArtifact;
	MissingBinding(bindingId:String);
}

enum CapabilityAvailability<Provider, Capability, Scope> {
	Available(token:CapabilityToken<Provider, Capability, Scope>);
	Unavailable(reason:CapabilityFailure);
}

@:allow(wordpress.hx.adoption.prototype.CapabilityRuntime)
final class CapabilityToken<Provider, Capability, Scope> {
	final requestIdentity:String;
	final providerId:String;
	final capabilityId:String;

	private function new(requestIdentity:String, providerId:String, capabilityId:String) {
		this.requestIdentity = requestIdentity;
		this.providerId = providerId;
		this.capabilityId = capabilityId;
	}

	public function authorizes(scope:RequestScope<Scope>, provider:ProviderContract<Provider>, capability:CapabilityContract<Provider, Capability>):Bool {
		return scope.matches(requestIdentity) && provider.id == providerId && capability.id == capabilityId;
	}
}

@:allow(wordpress.hx.adoption.prototype.Adoption)
final class CapabilityRuntime<Scope> {
	final scope:RequestScope<Scope>;
	final observation:ProviderObservation;

	private function new(scope:RequestScope<Scope>, observation:ProviderObservation) {
		this.scope = scope;
		this.observation = observation;
	}

	public function probe<Provider, Capability>(provider:ProviderContract<Provider>,
			capability:CapabilityContract<Provider, Capability>):CapabilityAvailability<Provider, Capability, Scope> {
		return switch observation.state {
			case Absent:
				Unavailable(ProviderAbsent);
			case Exact(providerId, version, artifactSha256, bindings):
				if (providerId != provider.id) {
					Unavailable(WrongProvider);
				} else if (version != provider.version) {
					Unavailable(WrongVersion);
				} else if (artifactSha256 != provider.artifactSha256) {
					Unavailable(WrongArtifact);
				} else {
					final missing = firstMissing(capability.requiredBindings, bindings);
					if (missing == null) {
						Available(new CapabilityToken(scope.identity, provider.id, capability.id));
					} else {
						Unavailable(MissingBinding(missing));
					}
				}
		};
	}

	static function firstMissing(required:Array<String>, observed:Array<String>):Null<String> {
		for (binding in required) {
			if (observed.indexOf(binding) < 0) {
				return binding;
			}
		}
		return null;
	}
}

final class CapabilityFailureTools {
	public static function describe(failure:CapabilityFailure):String {
		return switch failure {
			case ProviderAbsent: "provider-absent";
			case WrongProvider: "wrong-provider";
			case WrongVersion: "wrong-version";
			case WrongArtifact: "wrong-artifact";
			case MissingBinding(bindingId): "missing-binding:" + bindingId;
		};
	}
}
