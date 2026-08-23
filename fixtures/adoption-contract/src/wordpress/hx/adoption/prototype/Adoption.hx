package wordpress.hx.adoption.prototype;

/** Bounded ADR-015 capability-token prototype; SDK-070/073 own production APIs. */
final class Adoption {}

enum abstract LifecycleKind(String) {
	final PhpRequest = "php-request";
	final PhpProcess = "php-process";
	final BrowserModule = "browser-module";
}

enum CapabilityRequirement {
	Required;
	Optional;
}

final class ProviderContract<Provider> {
	public final id:String;
	public final version:String;
	public final artifactSha256:String;
	public final bundleDigest:String;

	public function new(id:String, version:String, artifactSha256:String, bundleDigest:String) {
		this.id = id;
		this.version = version;
		this.artifactSha256 = artifactSha256;
		this.bundleDigest = bundleDigest;
	}
}

final class CapabilityContract<Provider, Capability, Scope:LifecycleScope> {
	public final id:String;
	public final lifecycle:LifecycleKind;
	public final requirement:CapabilityRequirement;
	public final requiredBindings:Array<String>;

	public function new(id:String, lifecycle:LifecycleKind, requirement:CapabilityRequirement, requiredBindings:Array<String>) {
		this.id = id;
		this.lifecycle = lifecycle;
		this.requirement = requirement;
		this.requiredBindings = requiredBindings.copy();
	}
}

private final class LifecycleNonce {
	public function new() {}
}

@:allow(wordpress.hx.adoption.prototype.CapabilityToken)
@:allow(wordpress.hx.adoption.prototype.CapabilityRuntime)
@:allow(wordpress.hx.adoption.prototype.PhpRequestScope)
@:allow(wordpress.hx.adoption.prototype.PhpProcessScope)
@:allow(wordpress.hx.adoption.prototype.BrowserModuleScope)
class LifecycleScope {
	final nonce:LifecycleNonce;
	final lifecycle:LifecycleKind;

	private function new(lifecycle:LifecycleKind) {
		this.nonce = new LifecycleNonce();
		this.lifecycle = lifecycle;
	}

	function matches(nonce:LifecycleNonce, lifecycle:LifecycleKind):Bool {
		return this.nonce == nonce && this.lifecycle == lifecycle;
	}
}

@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)
final class PhpRequestScope extends LifecycleScope {
	private function new() {
		super(PhpRequest);
	}
}

@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)
final class PhpProcessScope extends LifecycleScope {
	private function new() {
		super(PhpProcess);
	}
}

@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)
final class BrowserModuleScope extends LifecycleScope {
	private function new() {
		super(BrowserModule);
	}
}

private enum ObservationState {
	Exact(providerId:String, version:String, artifactSha256:String, bundleDigest:String, bindings:Array<String>);
	Absent;
}

@:allow(wordpress.hx.adoption.prototype.CapabilityRuntime)
@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)
final class ProviderObservation {
	final state:ObservationState;

	private function new(state:ObservationState) {
		this.state = state;
	}

	private static function exact(providerId:String, version:String, artifactSha256:String, bundleDigest:String, bindings:Array<String>):ProviderObservation {
		return new ProviderObservation(Exact(providerId, version, artifactSha256, bundleDigest, bindings.copy()));
	}

	private static function absent():ProviderObservation {
		return new ProviderObservation(Absent);
	}
}

enum CapabilityFailure {
	RequiredProviderAbsent;
	OptionalProviderAbsent;
	WrongProvider;
	WrongVersion;
	WrongArtifact;
	WrongBundle;
	WrongLifecycle;
	MissingBinding(bindingId:String);
}

enum CapabilityAvailability<Provider, Capability, Scope:LifecycleScope> {
	Available(token:CapabilityToken<Provider, Capability, Scope>);
	Unavailable(reason:CapabilityFailure);
}

@:allow(wordpress.hx.adoption.prototype.CapabilityRuntime)
final class CapabilityToken<Provider, Capability, Scope:LifecycleScope> {
	final nonce:LifecycleNonce;
	final lifecycle:LifecycleKind;
	final providerId:String;
	final providerVersion:String;
	final artifactSha256:String;
	final bundleDigest:String;
	final capabilityId:String;
	final observedBindings:Array<String>;

	private function new(scope:Scope, lifecycle:LifecycleKind, providerId:String, providerVersion:String, artifactSha256:String, bundleDigest:String,
			capabilityId:String, observedBindings:Array<String>) {
		this.nonce = scope.nonce;
		this.lifecycle = lifecycle;
		this.providerId = providerId;
		this.providerVersion = providerVersion;
		this.artifactSha256 = artifactSha256;
		this.bundleDigest = bundleDigest;
		this.capabilityId = capabilityId;
		this.observedBindings = observedBindings.copy();
	}

	public function authorizes(scope:Scope, provider:ProviderContract<Provider>, capability:CapabilityContract<Provider, Capability, Scope>):Bool {
		return scope.matches(nonce, lifecycle)
			&& capability.lifecycle == lifecycle
			&& provider.id == providerId
			&& provider.version == providerVersion
			&& provider.artifactSha256 == artifactSha256
			&& provider.bundleDigest == bundleDigest
			&& capability.id == capabilityId
			&& firstMissing(capability.requiredBindings, observedBindings) == null;
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

@:allow(wordpress.hx.adoption.prototype.testing.TargetProbe)
final class CapabilityRuntime<Scope:LifecycleScope> {
	final scope:Scope;
	final observation:ProviderObservation;

	private function new(scope:Scope, observation:ProviderObservation) {
		this.scope = scope;
		this.observation = observation;
	}

	public function probe<Provider, Capability>(provider:ProviderContract<Provider>,
			capability:CapabilityContract<Provider, Capability, Scope>):CapabilityAvailability<Provider, Capability, Scope> {
		if (capability.lifecycle != scope.lifecycle) {
			return Unavailable(WrongLifecycle);
		}
		return switch observation.state {
			case Absent:
				switch capability.requirement {
					case Required: Unavailable(RequiredProviderAbsent);
					case Optional: Unavailable(OptionalProviderAbsent);
				}
			case Exact(providerId, version, artifactSha256, bundleDigest, bindings):
				if (providerId != provider.id) {
					Unavailable(WrongProvider);
				} else if (version != provider.version) {
					Unavailable(WrongVersion);
				} else if (artifactSha256 != provider.artifactSha256) {
					Unavailable(WrongArtifact);
				} else if (bundleDigest != provider.bundleDigest) {
					Unavailable(WrongBundle);
				} else {
					final missing = firstMissing(capability.requiredBindings, bindings);
					if (missing == null) {
						Available(new CapabilityToken(scope, scope.lifecycle, provider.id, provider.version, provider.artifactSha256, provider.bundleDigest,
							capability.id, bindings));
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
			case RequiredProviderAbsent: "required-provider-absent";
			case OptionalProviderAbsent: "optional-provider-absent";
			case WrongProvider: "wrong-provider";
			case WrongVersion: "wrong-version";
			case WrongArtifact: "wrong-artifact";
			case WrongBundle: "wrong-bundle";
			case WrongLifecycle: "wrong-lifecycle";
			case MissingBinding(bindingId): "missing-binding:" + bindingId;
		};
	}
}
