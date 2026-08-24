package wordpress.hx.adoption.prototype.testing;

import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderObservation;

final class TargetProbe {
	public static function spoof():Void {
		new PhpRequestScope();
		ProviderObservation.exact("acme-calendar", "2.4.1", "0", "0", []);
	}
}
