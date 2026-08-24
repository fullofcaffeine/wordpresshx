package wordpress.hx.adoption.prototype.testing;

import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRequirement;
import wordpress.hx.adoption.prototype.Adoption.FixtureTargetAdapter;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.PhpProcessScope;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.TargetSession;

/** Scenario names for the source-owned fixture adapter; this class has no friend access. */
final class TargetProbe {
	public static function exactPhpRequest():TargetSession<PhpRequestScope> {
		return FixtureTargetAdapter.exactPhpRequest(AcmeCalendar.provider, AcmeCalendar.read);
	}

	public static function absentPhpRequest():TargetSession<PhpRequestScope> {
		return FixtureTargetAdapter.absentPhpRequest();
	}

	public static function wrongVersionPhpRequest():TargetSession<PhpRequestScope> {
		return FixtureTargetAdapter.wrongVersionPhpRequest(AcmeCalendar.provider, AcmeCalendar.read);
	}

	public static function missingReadBindingPhpRequest():TargetSession<PhpRequestScope> {
		return FixtureTargetAdapter.missingLastPhpBinding(AcmeCalendar.provider, AcmeCalendar.read);
	}

	public static function exactBrowserModule():TargetSession<BrowserModuleScope> {
		return FixtureTargetAdapter.exactBrowserModule(AcmeCalendar.provider, AcmeCalendar.badge);
	}

	public static function absentBrowserModule():TargetSession<BrowserModuleScope> {
		return FixtureTargetAdapter.absentBrowserModule();
	}

	public static function missingBadgeBindingBrowserModule():TargetSession<BrowserModuleScope> {
		return FixtureTargetAdapter.missingFirstBrowserBinding(AcmeCalendar.provider, AcmeCalendar.badge);
	}

	public static function sameRequestInstanceReuseRejected():Bool {
		final first = exactPhpRequest();
		final second = exactPhpRequest();
		return switch first.runtime.probe(AcmeCalendar.provider, AcmeCalendar.read) {
			case Available(token): !token.authorizes(second.scope, AcmeCalendar.provider, AcmeCalendar.read, second.bundleDigest);
			case Unavailable(_): false;
		};
	}

	public static function browserReloadRejected():Bool {
		final loaded = exactBrowserModule();
		final reloaded = exactBrowserModule();
		return switch loaded.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token): !token.authorizes(reloaded.scope, AcmeCalendar.provider, AcmeCalendar.badge, reloaded.bundleDigest);
			case Unavailable(_): false;
		};
	}

	public static function staleProcessRejected():Bool {
		final started = FixtureTargetAdapter.exactPhpProcess(AcmeCalendar.provider, processCapability);
		final restarted = FixtureTargetAdapter.exactPhpProcess(AcmeCalendar.provider, processCapability);
		return switch started.runtime.probe(AcmeCalendar.provider, processCapability) {
			case Available(token): !token.authorizes(restarted.scope, AcmeCalendar.provider, processCapability, restarted.bundleDigest);
			case Unavailable(_): false;
		};
	}

	static final processCapability = new CapabilityContract<AcmeCalendarProvider, FixtureProcessCapability, PhpProcessScope>("calendar.process.fixture",
		LifecycleKind.PhpProcess, CapabilityRequirement.Required, ["php.calendar.list-events"]);
}

final class FixtureProcessCapability {}
