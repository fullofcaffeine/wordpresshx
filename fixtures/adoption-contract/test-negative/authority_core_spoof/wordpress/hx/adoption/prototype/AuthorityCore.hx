package wordpress.hx.adoption.prototype;

import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderObservation;

/** Downstream attempt to impersonate the production authority owner. */
final class AuthorityCore {
	public static function attack():Void {
		new PhpRequestScope();
		ProviderObservation.exact("spoof", "0", "0", "0", []);
	}
}
