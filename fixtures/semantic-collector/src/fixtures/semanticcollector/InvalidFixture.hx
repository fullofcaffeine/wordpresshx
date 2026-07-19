package fixtures.semanticcollector;

import wordpress.hx.build.semantic.BuildInput;
import wordpress.hx.build.semantic.Dev;
import wordpress.hx.build.semantic.DevelopmentReadinessKind;
import wordpress.hx.build.semantic.Hook;
import wordpress.hx.build.semantic.Module;

class InvalidFixture {
	public static function main():Void {
		#if missing_module
		Hook.action({
			id: "orphan-hook",
			module: "missing-module",
			name: "init",
			callback: validAction
		});
		#else
		declareModule();
		#end

		#if duplicate_module
		Module.plugin({
			id: "acme-observatory",
			name: "Duplicate Observatory",
			version: "0.1.0",
			namespace: "Acme\\Duplicate"
		});
		#end
		#if duplicate_hook
		Hook.action({
			id: "duplicate-hook",
			module: "acme-observatory",
			name: "init",
			callback: validAction
		});
		Hook.action({
			id: "duplicate-hook",
			module: "acme-observatory",
			name: "init",
			callback: validAction
		});
		#end
		#if missing_profile_capability
		Hook.action({
			id: "unsupported-hook",
			module: "acme-observatory",
			name: "save_post",
			callback: validAction
		});
		#end
		#if wrong_action_return
		Hook.action({
			id: "wrong-return",
			module: "acme-observatory",
			name: "init",
			callback: invalidAction
		});
		#end
		#if missing_filter_capability
		Hook.filter({
			id: "unsupported-filter",
			module: "acme-observatory",
			name: "init",
			callback: validFilter
		});
		#end
		#if wrong_filter_return
		Hook.filter({
			id: "wrong-filter",
			module: "acme-observatory",
			name: "init",
			callback: invalidFilter
		});
		#end
		#if computed_identity
		final computed = "computed-module";
		Module.plugin({
			id: computed,
			name: "Computed",
			version: "0.1.0",
			namespace: "Acme\\Computed"
		});
		#end
		#if resource_traversal
		BuildInput.resource({id: "escape", path: "../outside.txt"});
		#end
		#if missing_environment
		BuildInput.publicEnvironment({name: "REQUIRED_PUBLIC_VALUE"});
		#end
		#if duplicate_service
		Dev.wordpress();
		Dev.wordpress();
		#end
		#if unknown_service_dependency
		Dev.wordpress({dependsOn: ["missing-service"]});
		#end
		#if invalid_service_environment
		Dev.wordpress({environment: ["WP_DB_PASSWORD"]});
		#end
		#if invalid_service_port
		Dev.wordpress({preferredPort: 70000});
		#end
		#if invalid_service_readiness
		Dev.wordpress({readinessKind: DevelopmentReadinessKind.Log});
		#end
		#if unlocked_external_service
		Dev.service({
			id: "search",
			command: {
				component: "tool.unlocked",
				executable: "search-server",
				arguments: ["--port", "{port}"]
			}
		});
		#end
		#if service_cycle
		Dev.service({
			id: "api",
			dependsOn: ["worker"],
			command: {
				component: "tool.npm",
				executable: "npm",
				arguments: ["run", "api", "--", "--port", "{port}"]
			}
		});
		Dev.service({
			id: "worker",
			dependsOn: ["api"],
			command: {
				component: "tool.npm",
				executable: "npm",
				arguments: ["run", "worker"]
			}
		});
		#end
	}

	static function declareModule():Void {
		Module.plugin({
			id: "acme-observatory",
			name: "Acme Observatory",
			version: "0.1.0",
			namespace: "Acme\\Observatory"
		});
	}

	static function validAction():Void {}

	static function invalidAction():String {
		return "invalid";
	}

	static function validFilter(value:String):String {
		return value;
	}

	static function invalidFilter(value:String):Void {}
}
