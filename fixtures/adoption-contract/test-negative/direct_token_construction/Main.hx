import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarReadCapability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.testing.TargetProbe;

final class Main {
	static function main():Void {
		new CapabilityToken<AcmeCalendarProvider, CalendarReadCapability, PhpRequestScope>(TargetProbe.exactPhpRequest().scope, LifecycleKind.PhpRequest,
			"acme-calendar", "2.4.1", "forged-artifact", "forged-bundle", "calendar.read.php", ["php.calendar.list-events"]);
	}
}
