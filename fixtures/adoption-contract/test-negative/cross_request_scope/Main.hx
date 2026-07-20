import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarFacade;
import wordpress.hx.adoption.prototype.AcmeCalendar.EventQuery;
import wordpress.hx.adoption.prototype.Adoption;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.RequestScope;

final class FirstScope {}
final class SecondScope {}

final class Main {
	static function main():Void {
		final first:RequestScope<FirstScope> = Adoption.beginRequest("first");
		final second:RequestScope<SecondScope> = Adoption.beginRequest("second");
		final runtime = Adoption.runtime(first,
			Adoption.observeExact("acme-calendar", "2.4.1", "6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013", ["php.calendar.list-events"]));
		switch runtime.probe(AcmeCalendar.provider, AcmeCalendar.read) {
			case Available(token):
				AcmeCalendarFacade.listEvents(second, token, new EventQuery(1));
			case Unavailable(_):
		}
	}
}
