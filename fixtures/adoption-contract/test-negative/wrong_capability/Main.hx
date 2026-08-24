import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.testing.TargetProbe;

final class Main {
	static function main():Void {
		final browser = TargetProbe.exactBrowserModule();
		switch browser.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				token.authorizes(browser.scope, AcmeCalendar.provider, AcmeCalendar.read, browser.bundleDigest);
			case Unavailable(_):
		}
	}
}
