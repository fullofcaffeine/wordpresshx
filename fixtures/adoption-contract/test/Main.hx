#if js
import js.Node;
#end
import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarFacade;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarBadgeProps;
import wordpress.hx.adoption.prototype.AcmeCalendar.EventQuery;
import wordpress.hx.adoption.prototype.Adoption;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityFailureTools;
import wordpress.hx.adoption.prototype.Adoption.RequestScope;

final class RequestOne {}

final class Main {
	static function main():Void {
		final scope:RequestScope<RequestOne> = Adoption.beginRequest("request-one");
		final exact = Adoption.runtime(scope,
			Adoption.observeExact("acme-calendar", "2.4.1", "6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013",
				["js.calendar.badge", "js.calendar.format-label", "php.calendar.list-events"]));

		final lines = [];
		switch exact.probe(AcmeCalendar.provider, AcmeCalendar.read) {
			case Available(token):
				lines.push("exact|available|" + AcmeCalendarFacade.listEvents(scope, token, new EventQuery(12)));
			case Unavailable(reason):
				throw new haxe.Exception("exact provider unexpectedly unavailable: " + CapabilityFailureTools.describe(reason));
		}
		switch exact.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				lines.push("browser|available|" + AcmeCalendarFacade.renderBadge(scope, token, new CalendarBadgeProps(7, "Due this week")));
			case Unavailable(reason):
				throw new haxe.Exception("browser capability unexpectedly unavailable: " + CapabilityFailureTools.describe(reason));
		}

		final absent = Adoption.runtime(scope, Adoption.observeAbsent());
		lines.push("absent|" + describe(absent.probe(AcmeCalendar.provider, AcmeCalendar.read)));
		final wrongVersion = Adoption.runtime(scope,
			Adoption.observeExact("acme-calendar", "2.5.0", "6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013", ["php.calendar.list-events"]));
		lines.push("wrong-version|" + describe(wrongVersion.probe(AcmeCalendar.provider, AcmeCalendar.read)));
		final missingBinding = Adoption.runtime(scope,
			Adoption.observeExact("acme-calendar", "2.4.1", "6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013", ["js.calendar.format-label"]));
		lines.push("missing-binding|" + describe(missingBinding.probe(AcmeCalendar.provider, AcmeCalendar.badge)));

		final output = lines.join("\n") + "\n";
		#if js
		Node.process.stdout.write(output);
		#else
		Sys.print(output);
		#end
	}

	static function describe<Provider, Capability, Scope>(availability:CapabilityAvailability<Provider, Capability, Scope>):String {
		return switch availability {
			case Available(_): "available";
			case Unavailable(reason): CapabilityFailureTools.describe(reason);
		};
	}
}
