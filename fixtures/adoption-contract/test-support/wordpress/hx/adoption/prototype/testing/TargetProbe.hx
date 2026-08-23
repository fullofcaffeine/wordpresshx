package wordpress.hx.adoption.prototype.testing;

import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRequirement;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRuntime;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.LifecycleScope;
import wordpress.hx.adoption.prototype.Adoption.PhpProcessScope;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderObservation;

/** A test-only stand-in for trusted PHP and browser target adapters. */
final class TargetProbe {
	static final providerId = "acme-calendar";
	static final version = "2.4.1";
	static final artifactSha256 = "923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd";
	static final bundleDigest = "db9fbcddfcb798767c8078cbae8ea27d9fe989a5c62f089c51cfc99f55fadfb9";
	static final allBindings = [
		"js.calendar.badge",
		"js.calendar.format-label",
		"php.calendar.event.construct",
		"php.calendar.event.title",
		"php.calendar.list-events"
	];

	public static function exactPhpRequest():TargetSession<PhpRequestScope> {
		return phpRequest(exact());
	}

	public static function absentPhpRequest():TargetSession<PhpRequestScope> {
		return phpRequest(ProviderObservation.absent());
	}

	public static function wrongVersionPhpRequest():TargetSession<PhpRequestScope> {
		return phpRequest(ProviderObservation.exact(providerId, "2.5.0", artifactSha256, bundleDigest, allBindings));
	}

	public static function exactBrowserModule():TargetSession<BrowserModuleScope> {
		return browserModule(exact());
	}

	public static function absentBrowserModule():TargetSession<BrowserModuleScope> {
		return browserModule(ProviderObservation.absent());
	}

	public static function missingBadgeBindingBrowserModule():TargetSession<BrowserModuleScope> {
		return browserModule(ProviderObservation.exact(providerId, version, artifactSha256, bundleDigest, ["js.calendar.format-label"]));
	}

	public static function sameRequestInstanceReuseRejected():Bool {
		final first = exactPhpRequest();
		final second = exactPhpRequest();
		return switch first.runtime.probe(AcmeCalendar.provider, AcmeCalendar.read) {
			case Available(token): !token.authorizes(second.scope, AcmeCalendar.provider, AcmeCalendar.read);
			case Unavailable(_): false;
		};
	}

	public static function browserReloadRejected():Bool {
		final loaded = exactBrowserModule();
		final reloaded = exactBrowserModule();
		return switch loaded.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token): !token.authorizes(reloaded.scope, AcmeCalendar.provider, AcmeCalendar.badge);
			case Unavailable(_): false;
		};
	}

	public static function staleProcessRejected():Bool {
		final started = phpProcess(exact());
		final restarted = phpProcess(exact());
		return switch started.runtime.probe(AcmeCalendar.provider, processCapability) {
			case Available(token): !token.authorizes(restarted.scope, AcmeCalendar.provider, processCapability);
			case Unavailable(_): false;
		};
	}

	static final processCapability = new CapabilityContract<AcmeCalendarProvider, FixtureProcessCapability, PhpProcessScope>("calendar.process.fixture",
		LifecycleKind.PhpProcess, CapabilityRequirement.Required, ["php.calendar.list-events"]);

	static function exact():ProviderObservation {
		return ProviderObservation.exact(providerId, version, artifactSha256, bundleDigest, allBindings);
	}

	static function phpRequest(observation:ProviderObservation):TargetSession<PhpRequestScope> {
		final scope = new PhpRequestScope();
		return new TargetSession(scope, new CapabilityRuntime(scope, observation));
	}

	static function phpProcess(observation:ProviderObservation):TargetSession<PhpProcessScope> {
		final scope = new PhpProcessScope();
		return new TargetSession(scope, new CapabilityRuntime(scope, observation));
	}

	static function browserModule(observation:ProviderObservation):TargetSession<BrowserModuleScope> {
		final scope = new BrowserModuleScope();
		return new TargetSession(scope, new CapabilityRuntime(scope, observation));
	}
}

final class FixtureProcessCapability {}

final class TargetSession<Scope:LifecycleScope> {
	public final scope:Scope;
	public final runtime:CapabilityRuntime<Scope>;

	public function new(scope:Scope, runtime:CapabilityRuntime<Scope>) {
		this.scope = scope;
		this.runtime = runtime;
	}
}
