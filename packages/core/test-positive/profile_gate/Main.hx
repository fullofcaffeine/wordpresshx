import wordpress.hx.core.profile.ProfileGate;

class Main {
	static function main():Void {
		ProfileGate.requireCapability("gutenberg.package.@wordpress/content-types", ["gutenberg-forward-23.4"]);
	}
}
