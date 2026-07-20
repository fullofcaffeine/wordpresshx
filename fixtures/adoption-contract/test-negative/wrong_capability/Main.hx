import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarFacade;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarBadgeProps;
import wordpress.hx.adoption.prototype.AcmeCalendar.EventQuery;
import wordpress.hx.adoption.prototype.Adoption;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.RequestScope;

final class Scope {}

final class Main {
	static function main():Void {
		final scope:RequestScope<Scope> = Adoption.beginRequest("request");
		final runtime = Adoption.runtime(scope,
			Adoption.observeExact("acme-calendar", "2.4.1", "6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013",
				["js.calendar.badge", "js.calendar.format-label"]));
		switch runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				AcmeCalendarFacade.listEvents(scope, token, new EventQuery(1));
			case Unavailable(_):
				new CalendarBadgeProps(0, "fallback");
		}
	}
}
