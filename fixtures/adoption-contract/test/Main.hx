#if js
import js.Node;
#end
import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarFacade;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarBadgeProps;
import wordpress.hx.adoption.prototype.AcmeCalendar.EventQuery;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityFailureTools;
import wordpress.hx.adoption.prototype.Adoption.LifecycleScope;
import wordpress.hx.adoption.prototype.testing.TargetProbe;

final class Main {
	static function main():Void {
		final php = TargetProbe.exactPhpRequest();
		final browser = TargetProbe.exactBrowserModule();
		final lines = [];
		switch php.runtime.probe(AcmeCalendar.provider, AcmeCalendar.read) {
			case Available(token):
				lines.push("exact|available|" + AcmeCalendarFacade.listEvents(php.scope, token, new EventQuery(12)));
			case Unavailable(reason):
				throw new haxe.Exception("exact provider unexpectedly unavailable: " + CapabilityFailureTools.describe(reason));
		}
		switch browser.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				lines.push("browser|available|" + AcmeCalendarFacade.renderBadge(browser.scope, token, new CalendarBadgeProps(7, "Due this week")));
			case Unavailable(reason):
				throw new haxe.Exception("browser capability unexpectedly unavailable: " + CapabilityFailureTools.describe(reason));
		}

		final requiredAbsent = TargetProbe.absentPhpRequest();
		lines.push("required-absent|" + describe(requiredAbsent.runtime.probe(AcmeCalendar.provider, AcmeCalendar.read)));
		final optionalAbsent = TargetProbe.absentBrowserModule();
		lines.push("optional-absent|" + describe(optionalAbsent.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge)));
		final wrongVersion = TargetProbe.wrongVersionPhpRequest();
		lines.push("wrong-version|" + describe(wrongVersion.runtime.probe(AcmeCalendar.provider, AcmeCalendar.read)));
		final missingBinding = TargetProbe.missingBadgeBindingBrowserModule();
		lines.push("missing-binding|" + describe(missingBinding.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge)));
		lines.push("same-request-instance|" + rejected(TargetProbe.sameRequestInstanceReuseRejected()));
		lines.push("browser-reload|" + rejected(TargetProbe.browserReloadRejected()));
		lines.push("stale-process|" + rejected(TargetProbe.staleProcessRejected()));

		final output = lines.join("\n") + "\n";
		#if js
		Node.process.stdout.write(output);
		#else
		Sys.print(output);
		#end
	}

	static function describe<Provider, Capability, Scope:LifecycleScope>(availability:CapabilityAvailability<Provider, Capability, Scope>):String {
		return switch availability {
			case Available(_): "available";
			case Unavailable(reason): CapabilityFailureTools.describe(reason);
		};
	}

	static function rejected(value:Bool):String {
		return value ? "rejected" : "accepted-incorrectly";
	}
}
