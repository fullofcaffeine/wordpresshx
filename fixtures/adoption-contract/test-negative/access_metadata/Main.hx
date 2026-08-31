import wordpress.hx.adoption.prototype.Adoption.CapabilityAvailability;
import wordpress.hx.adoption.prototype.Adoption.AuthorityCore;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar;

final class Main {
	@:access(wordpress.hx.adoption.prototype.Adoption.AuthorityCore)
	static function main():Void {
		final selectedBundle = "caller-selected-bundle";
		final observation = AuthorityCore.exact(GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.read.executableClosureSha256, selectedBundle,
			GeneratedAcmeCalendar.read.requiredBindingIds());
		final session = AuthorityCore.phpRequest(observation, selectedBundle);
		switch session.runtime.probe(GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.read) {
			case Available(token):
				if (!token.authorizes(session.scope, GeneratedAcmeCalendar.provider, GeneratedAcmeCalendar.read, selectedBundle)) {
					throw new haxe.Exception("forged token was unexpectedly rejected");
				}
			case Unavailable(_):
				throw new haxe.Exception("forged observation was unexpectedly unavailable");
		}
	}
}
