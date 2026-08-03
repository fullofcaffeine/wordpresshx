package fixtures.semanticcollector;

import wordpress.hx.build.semantic.Hook;
import wordpress.hx.build.semantic.Module;

/** WordPress permits signed integer hook priorities; lower values execute first. */
class SignedPriorityFixture {
	public static function main():Void {
		Module.plugin({
			id: "acme-signed-priority",
			name: "Acme Signed Priority",
			version: "0.1.0",
			namespace: "Acme\\SignedPriority"
		});
		Hook.action({
			id: "early-init",
			module: "acme-signed-priority",
			name: "init",
			callback: earlyInit,
			priority: -20
		});
	}

	static function earlyInit():Void {}
}
