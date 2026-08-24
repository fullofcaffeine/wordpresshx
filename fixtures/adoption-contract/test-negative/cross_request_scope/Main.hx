import wordpress.hx.adoption.prototype.AcmeCalendar;
import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.testing.TargetProbe;

final class Main {
	static function main():Void {
		final browser = TargetProbe.exactBrowserModule();
		switch browser.runtime.probe(AcmeCalendar.provider, AcmeCalendar.badge) {
			case Available(token):
				token.authorizes(TargetProbe.exactPhpRequest().scope, AcmeCalendar.provider, AcmeCalendar.badge, browser.bundleDigest);
			case Unavailable(_):
		}
	}
}
