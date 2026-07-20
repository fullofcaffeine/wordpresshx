import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarReadCapability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;

final class Scope {}

final class Main {
	static function main():Void {
		new CapabilityToken<AcmeCalendarProvider, CalendarReadCapability, Scope>("request", "provider", "capability");
	}
}
