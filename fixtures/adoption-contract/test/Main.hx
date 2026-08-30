import adoption.testing.TargetProbe;
import adoption.testing.TargetProbe.TestAvailability;
import adoption.testing.TargetProbe.TestFailure;

final class Main {
	static function main():Void {
		final php = TargetProbe.exactPhpRequest();
		final browser = TargetProbe.exactBrowserModule();
		final lines = [];
		switch php.probe(TargetProbe.phpRead) {
			case Available(_):
				lines.push("exact|available|verified-token");
			case Unavailable(reason):
				throw new haxe.Exception("exact provider unexpectedly unavailable: " + describeFailure(reason));
		}
		switch browser.probe(TargetProbe.browserBadge) {
			case Available(_):
				lines.push("browser|available|verified-token");
			case Unavailable(reason):
				throw new haxe.Exception("browser capability unexpectedly unavailable: " + describeFailure(reason));
		}

		final requiredAbsent = TargetProbe.absentPhpRequest();
		lines.push("required-absent|" + describe(requiredAbsent.probe(TargetProbe.phpRead)));
		final optionalAbsent = TargetProbe.absentBrowserModule();
		lines.push("optional-absent|" + describe(optionalAbsent.probe(TargetProbe.browserBadge)));
		final wrongVersion = TargetProbe.wrongVersionPhpRequest();
		lines.push("wrong-version|" + describe(wrongVersion.probe(TargetProbe.phpRead)));
		final missingBinding = TargetProbe.missingBadgeBindingBrowserModule();
		lines.push("missing-binding|" + describe(missingBinding.probe(TargetProbe.browserBadge)));
		final callerBindings = TargetProbe.phpRead.requiredBindingIds();
		callerBindings.resize(0);
		final immutableBindings = TargetProbe.missingReadBindingPhpRequest();
		lines.push("binding-mutation|" + describe(immutableBindings.probe(TargetProbe.phpRead)));
		lines.push("same-request-instance|" + rejected(TargetProbe.sameRequestInstanceReuseRejected()));
		lines.push("browser-reload|" + rejected(TargetProbe.browserReloadRejected()));
		lines.push("stale-process|" + rejected(TargetProbe.staleProcessRejected()));

		final output = lines.join("\n") + "\n";
		Sys.print(output);
	}

	static function describe(availability:TestAvailability):String {
		return switch availability {
			case Available(_): "available";
			case Unavailable(reason): describeFailure(reason);
		};
	}

	static function describeFailure(failure:TestFailure):String
		return switch failure {
			case RequiredProviderAbsent: "required-provider-absent";
			case OptionalProviderAbsent: "optional-provider-absent";
			case WrongVersion: "wrong-version";
			case WrongArtifact: "wrong-artifact";
			case WrongLifecycle: "wrong-lifecycle";
			case MissingBinding(bindingId): "missing-binding:" + bindingId;
		};

	static function rejected(value:Bool):String {
		return value ? "rejected" : "accepted-incorrectly";
	}
}
