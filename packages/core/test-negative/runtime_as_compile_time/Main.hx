import wordpress.hx.core.profile.CompileTimeCapability;
import wordpress.hx.core.profile.RuntimeCapability;
import wordpress.hx.core.profile.RuntimeRequestScope;

class Main {
	static function main():Void {
		final scope = RuntimeRequestScope.begin();
		final runtime = RuntimeCapability.available(scope, 42);
		final invalid:CompileTimeCapability = runtime;
		trace(invalid);
	}
}
