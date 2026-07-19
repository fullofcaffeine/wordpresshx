package fixtures.semanticcollector;

import wordpress.hx.build.semantic.BuildInput;
import wordpress.hx.build.semantic.Dev;
import wordpress.hx.build.semantic.Hook;
import wordpress.hx.build.semantic.Module;

class ValidFixture {
	public static function main():Void {
		Module.plugin({
			id: "acme-observatory",
			name: "Acme Observatory",
			version: "0.1.0",
			namespace: "Acme\\Observatory"
		});
		BuildInput.resource({
			id: "brand",
			path: "fixtures/semantic-collector/assets/brand.txt"
		});
		BuildInput.publicEnvironment({name: "SITE_LOCALE"});
		Dev.wordpress();
		Hook.action({
			id: "register-visits",
			module: "acme-observatory",
			name: "init",
			callback: registerVisits,
			priority: 10
		});
	}

	static function registerVisits():Void {}
}
