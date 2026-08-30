import wordpress.hx.adoption.prototype.AcmeCalendar.AcmeCalendarProvider;
import wordpress.hx.adoption.prototype.AcmeCalendar.CalendarBadgeCapability;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;

final class Main {
	static function main():Void {}

	static function reject(token:CapabilityToken<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>, scope:PhpRequestScope,
			provider:wordpress.hx.adoption.prototype.Adoption.ProviderContract<AcmeCalendarProvider>,
			capability:CapabilityContract<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>):Bool {
		return token.authorizes(scope, provider, capability, "bundle");
	}
}
