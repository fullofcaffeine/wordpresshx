import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarBadgeCapability;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarReadCapability;
import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.ProviderContract;

final class Main {
	static function main():Void {}

	static function reject(token:CapabilityToken<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>, scope:BrowserModuleScope,
			provider:ProviderContract<AcmeCalendarProvider>,
			capability:CapabilityContract<AcmeCalendarProvider, CalendarReadCapability, BrowserModuleScope>):Bool {
		return token.authorizes(scope, provider, capability, "bundle");
	}
}
