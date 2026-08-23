import wordpress.hx.adoption.prototype.Adoption.ProviderObservation;

final class Main {
	static function main():Void {
		ProviderObservation.exact("acme-calendar", "2.4.1", "forged-artifact", "forged-bundle", ["php.calendar.list-events"]);
	}
}
