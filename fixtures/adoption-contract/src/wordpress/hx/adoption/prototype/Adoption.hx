package wordpress.hx.adoption.prototype;

import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarBadgeCapability;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarBadgeProps;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarReadCapability;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.EventQuery;
#if js
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedBrowserFacade;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedBrowserProviderHandle;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedJavascriptObject;
#end
#if php
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedPhpFacade;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedPhpProviderHandle;
#end

/** Bounded ADR-015 capability authority and source-owned target adapters. */
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

	public function new(id:String, version:String, artifactSha256:String) {
		this.id = id;
		this.version = version;
		this.artifactSha256 = artifactSha256;
	}
}

final class CapabilityContract<Provider, Capability, Scope:LifecycleScope> {
	public final id:String;
	public final lifecycle:LifecycleKind;
	public final requirement:CapabilityRequirement;
	public final executableClosureSha256:String;

	final bindings:Array<String>;

	public function new(id:String, lifecycle:LifecycleKind, requirement:CapabilityRequirement, requiredBindings:Array<String>, executableClosureSha256:String) {
		this.id = id;
		this.lifecycle = lifecycle;
		this.requirement = requirement;
		this.bindings = requiredBindings.copy();
		this.executableClosureSha256 = executableClosureSha256;
	}

	/** Return a copy so a caller cannot weaken the canonical requirement. */
	public function requiredBindingIds():Array<String> {
		return bindings.copy();
	}
}

private final class LifecycleNonce {
	public function new() {}
}

private final class AuthorityKey {
	static final CURRENT = new AuthorityKey();

	private function new() {}

	public static function current():AuthorityKey {
		return CURRENT;
	}

	public function verify():Void {
		if (this != CURRENT) {
			throw new haxe.Exception("invalid adoption authority key");
		}
	}
}

class LifecycleScope {
	final nonce:LifecycleNonce;
	final lifecycle:LifecycleKind;

	public function new(key:AuthorityKey, lifecycle:LifecycleKind) {
		key.verify();
		this.nonce = new LifecycleNonce();
		this.lifecycle = lifecycle;
	}

	public function authorityNonce(key:AuthorityKey):LifecycleNonce {
		key.verify();
		return nonce;
	}

	public function authorityLifecycle(key:AuthorityKey):LifecycleKind {
		key.verify();
		return lifecycle;
	}

	public function authorityMatches(key:AuthorityKey, nonce:LifecycleNonce, lifecycle:LifecycleKind):Bool {
		key.verify();
		return this.nonce == nonce && this.lifecycle == lifecycle;
	}
}

final class PhpRequestScope extends LifecycleScope {
	public function new(key:AuthorityKey) {
		super(key, PhpRequest);
	}
}

final class PhpProcessScope extends LifecycleScope {
	public function new(key:AuthorityKey) {
		super(key, PhpProcess);
	}
}

final class BrowserModuleScope extends LifecycleScope {
	public function new(key:AuthorityKey) {
		super(key, BrowserModule);
	}
}

private enum ObservationState {
	Exact(providerId:String, version:String, executableClosureSha256:String, bundleDigest:String, bindings:Array<String>);
	Absent;
}

final class ProviderObservation {
	final state:ObservationState;

	public function new(key:AuthorityKey, state:ObservationState) {
		key.verify();
		this.state = state;
	}

	public static function exact(key:AuthorityKey, providerId:String, version:String, executableClosureSha256:String, bundleDigest:String,
			bindings:Array<String>):ProviderObservation {
		return new ProviderObservation(key, Exact(providerId, version, executableClosureSha256, bundleDigest, bindings.copy()));
	}

	public static function absent(key:AuthorityKey):ProviderObservation {
		return new ProviderObservation(key, Absent);
	}

	public function authorityState(key:AuthorityKey):ObservationState {
		key.verify();
		return state;
	}
}

enum CapabilityFailure {
	RequiredProviderAbsent;
	OptionalProviderAbsent;
	WrongProvider;
	WrongVersion;
	WrongArtifact;
	WrongLifecycle;
	MissingBinding(bindingId:String);
}

enum CapabilityAvailability<Provider, Capability, Scope:LifecycleScope> {
	Available(token:CapabilityToken<Provider, Capability, Scope>);
	Unavailable(reason:CapabilityFailure);
}

final class CapabilityToken<Provider, Capability, Scope:LifecycleScope> {
	final key:AuthorityKey;
	final nonce:LifecycleNonce;
	final lifecycle:LifecycleKind;
	final providerId:String;
	final providerVersion:String;
	final executableClosureSha256:String;
	final bundleDigest:String;
	final capabilityId:String;
	final observedBindings:Array<String>;

	public function new(key:AuthorityKey, scope:Scope, lifecycle:LifecycleKind, providerId:String, providerVersion:String, executableClosureSha256:String,
			bundleDigest:String, capabilityId:String, observedBindings:Array<String>) {
		key.verify();
		this.key = key;
		this.nonce = scope.authorityNonce(key);
		this.lifecycle = lifecycle;
		this.providerId = providerId;
		this.providerVersion = providerVersion;
		this.executableClosureSha256 = executableClosureSha256;
		this.bundleDigest = bundleDigest;
		this.capabilityId = capabilityId;
		this.observedBindings = observedBindings.copy();
	}

	public function authorizes(scope:Scope, provider:ProviderContract<Provider>, capability:CapabilityContract<Provider, Capability, Scope>,
			currentBundleDigest:String):Bool {
		return scope.authorityMatches(key, nonce, lifecycle)
			&& capability.lifecycle == lifecycle
			&& provider.id == providerId
			&& provider.version == providerVersion
			&& capability.executableClosureSha256 == executableClosureSha256
			&& currentBundleDigest == bundleDigest
			&& capability.id == capabilityId
			&& AuthorityCore.firstMissing(capability.requiredBindingIds(), observedBindings) == null;
	}
}

final class CapabilityRuntime<Scope:LifecycleScope> {
	final key:AuthorityKey;
	final scope:Scope;
	final observation:ProviderObservation;

	public function new(key:AuthorityKey, scope:Scope, observation:ProviderObservation) {
		key.verify();
		this.key = key;
		this.scope = scope;
		this.observation = observation;
	}

	public function probe<Provider, Capability>(provider:ProviderContract<Provider>,
			capability:CapabilityContract<Provider, Capability, Scope>):CapabilityAvailability<Provider, Capability, Scope> {
		final lifecycle = scope.authorityLifecycle(key);
		if (capability.lifecycle != lifecycle) {
			return Unavailable(WrongLifecycle);
		}
		return switch observation.authorityState(key) {
			case Absent:
				switch capability.requirement {
					case Required: Unavailable(RequiredProviderAbsent);
					case Optional: Unavailable(OptionalProviderAbsent);
				}
			case Exact(providerId, version, executableClosureSha256, bundleDigest, bindings):
				if (providerId != provider.id) {
					Unavailable(WrongProvider);
				} else if (version != provider.version) {
					Unavailable(WrongVersion);
				} else if (executableClosureSha256 != capability.executableClosureSha256) {
					Unavailable(WrongArtifact);
				} else {
					final missing = AuthorityCore.firstMissing(capability.requiredBindingIds(), bindings);
					if (missing == null) {
						Available(new CapabilityToken(key, scope, lifecycle, provider.id, provider.version, executableClosureSha256, bundleDigest,
							capability.id, bindings));
					} else {
						Unavailable(MissingBinding(missing));
					}
				}
		};
	}
}

final class TargetSession<Scope:LifecycleScope> {
	public final scope:Scope;
	public final runtime:CapabilityRuntime<Scope>;
	public final bundleDigest:String;

	public function new(key:AuthorityKey, scope:Scope, runtime:CapabilityRuntime<Scope>, bundleDigest:String) {
		key.verify();
		this.scope = scope;
		this.runtime = runtime;
		this.bundleDigest = bundleDigest;
	}
}

#if php
/** PHP request adapter that verifies provider bytes before minting authority. */
final class PhpAcmeCalendarAdapter {
	final authority:TargetSession<PhpRequestScope>;
	final provider:GeneratedPhpProviderHandle;

	public static function open(pluginFile:String, bundleFile:String):PhpAcmeCalendarAdapter {
		final provider = GeneratedPhpFacade.open(pluginFile, bundleFile);
		final authority = AuthorityCore.phpRequest(AuthorityCore.exact(GeneratedAcmeCalendar.provider, provider.executableClosureSha256,
			provider.bundleDigest, GeneratedAcmeCalendar.read.requiredBindingIds()),
			provider.bundleDigest);
		return new PhpAcmeCalendarAdapter(authority, provider);
	}

	function new(authority:TargetSession<PhpRequestScope>, provider:GeneratedPhpProviderHandle) {
		this.authority = authority;
		this.provider = provider;
	}

	public function listEventTitles(query:EventQuery):Array<String> {
		return switch authority.runtime.probe(GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.read) {
			case Available(token):
				if (!token.authorizes(authority.scope, GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.read, provider.bundleDigest)) {
					throw new haxe.Exception("PHP request provider token is stale or mismatched");
				}
				final titles:Array<String> = GeneratedPhpFacade.listEventTitles(provider, query.limit);
				titles;
			case Unavailable(reason):
				throw new haxe.Exception("PHP request provider unavailable: " + CapabilityFailureTools.describe(reason));
		};
	}
}
#end

#if js
/** Browser-module adapter that keeps the verified imported module as its handle. */
final class BrowserAcmeCalendarAdapter {
	final authority:TargetSession<BrowserModuleScope>;
	final provider:GeneratedBrowserProviderHandle;

	public static function open(packageRoot:String, generation:String, bundleFile:String):js.lib.Promise<BrowserAcmeCalendarAdapter> {
		return GeneratedBrowserFacade.openExactProvider(packageRoot, generation, bundleFile).then(provider -> {
			final authority = AuthorityCore.browserModule(AuthorityCore.exact(GeneratedAcmeCalendar.provider, provider.executableClosureSha256,
				provider.bundleDigest, GeneratedAcmeCalendar.badge.requiredBindingIds()),
				provider.bundleDigest);
			return new BrowserAcmeCalendarAdapter(authority, provider);
		});
	}

	function new(authority:TargetSession<BrowserModuleScope>, provider:GeneratedBrowserProviderHandle) {
		this.authority = authority;
		this.provider = provider;
	}

	public function renderBadge(props:CalendarBadgeProps):GeneratedJavascriptObject {
		return switch authority.runtime.probe(GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.badge) {
			case Available(token):
				if (!token.authorizes(authority.scope, GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.badge, provider.bundleDigest)) {
					throw new haxe.Exception("browser-module provider token is stale or mismatched");
				}
				provider.renderBadge(props);
			case Unavailable(reason):
				throw new haxe.Exception("browser provider unavailable: " + CapabilityFailureTools.describe(reason));
		};
	}
}
#end

final class CapabilityFailureTools {
	public static function describe(failure:CapabilityFailure):String {
		return switch failure {
			case RequiredProviderAbsent: "required-provider-absent";
			case OptionalProviderAbsent: "optional-provider-absent";
			case WrongProvider: "wrong-provider";
			case WrongVersion: "wrong-version";
			case WrongArtifact: "wrong-artifact";
			case WrongLifecycle: "wrong-lifecycle";
			case MissingBinding(bindingId): "missing-binding:" + bindingId;
		};
	}
}

private final class AuthorityCore {
	static final KEY = AuthorityKey.current();

	public static function exact<Provider>(provider:ProviderContract<Provider>, executableClosureSha256:String, bundleDigest:String,
			bindings:Array<String>):ProviderObservation {
		return ProviderObservation.exact(KEY, provider.id, provider.version, executableClosureSha256, bundleDigest, bindings);
	}

	public static function wrongVersion<Provider>(provider:ProviderContract<Provider>, bundleDigest:String, bindings:Array<String>):ProviderObservation {
		return ProviderObservation.exact(KEY, provider.id, provider.version + ".wrong", provider.artifactSha256, bundleDigest, bindings);
	}

	public static function absent():ProviderObservation {
		return ProviderObservation.absent(KEY);
	}

	public static function phpRequest(observation:ProviderObservation, bundleDigest:String):TargetSession<PhpRequestScope> {
		final scope = new PhpRequestScope(KEY);
		return new TargetSession(KEY, scope, new CapabilityRuntime(KEY, scope, observation), bundleDigest);
	}

	public static function phpProcess(observation:ProviderObservation, bundleDigest:String):TargetSession<PhpProcessScope> {
		final scope = new PhpProcessScope(KEY);
		return new TargetSession(KEY, scope, new CapabilityRuntime(KEY, scope, observation), bundleDigest);
	}

	public static function browserModule(observation:ProviderObservation, bundleDigest:String):TargetSession<BrowserModuleScope> {
		final scope = new BrowserModuleScope(KEY);
		return new TargetSession(KEY, scope, new CapabilityRuntime(KEY, scope, observation), bundleDigest);
	}

	public static function firstMissing(required:Array<String>, observed:Array<String>):Null<String> {
		for (binding in required) {
			if (observed.indexOf(binding) < 0) {
				return binding;
			}
		}
		return null;
	}
}
