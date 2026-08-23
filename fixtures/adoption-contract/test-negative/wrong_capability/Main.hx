import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarFacade;
import wordpress.hx.adoption.prototype.AcmeCalendar.EventQuery;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.testing.TargetProbe;

final class Main {
	static function main():Void {
		final browser = TargetProbe.exactBrowserModule();
		switch browser.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				AcmeCalendarFacade.listEvents(TargetProbe.exactPhpRequest().scope, token, new EventQuery(1));
			case Unavailable(_):
		}
	}
}
