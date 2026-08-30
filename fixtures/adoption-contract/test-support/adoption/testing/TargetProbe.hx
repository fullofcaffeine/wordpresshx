package adoption.testing;

/** Test-only shadow of the capability state machine. No product authority is imported. */
final class TargetProbe {
	static inline final PROVIDER_VERSION = "2.4.1";
	static inline final CONTENT_ROOT = "fixture-content-root";
	static inline final PHP_CLOSURE = "fixture-php-closure";
	static inline final BROWSER_CLOSURE = "fixture-browser-closure";
	static var nextNonce = 0;

	public static final phpRead = new TestCapability("calendar.read.php", PhpRequest, true, PHP_CLOSURE, [
		"php.calendar.event.construct",
		"php.calendar.event.title",
		"php.calendar.list-events"
	]);
	public static final browserBadge = new TestCapability("calendar.badge.browser", BrowserModule, false, BROWSER_CLOSURE,
		["js.calendar.badge", "js.calendar.format-label"]);
	static final phpProcess = new TestCapability("calendar.process.fixture", PhpProcess, true, PHP_CLOSURE, ["php.calendar.list-events"]);

	public static function exactPhpRequest():TestSession
		return session(PhpRequest, Exact(PROVIDER_VERSION, PHP_CLOSURE, CONTENT_ROOT, phpRead.requiredBindingIds()));

	public static function absentPhpRequest():TestSession
		return session(PhpRequest, Absent);

	public static function wrongVersionPhpRequest():TestSession
		return session(PhpRequest, Exact(PROVIDER_VERSION + ".wrong", PHP_CLOSURE, CONTENT_ROOT, phpRead.requiredBindingIds()));

	public static function missingReadBindingPhpRequest():TestSession {
		final bindings = phpRead.requiredBindingIds();
		bindings.pop();
		return session(PhpRequest, Exact(PROVIDER_VERSION, PHP_CLOSURE, CONTENT_ROOT, bindings));
	}

	public static function exactBrowserModule():TestSession
		return session(BrowserModule, Exact(PROVIDER_VERSION, BROWSER_CLOSURE, CONTENT_ROOT, browserBadge.requiredBindingIds()));

	public static function absentBrowserModule():TestSession
		return session(BrowserModule, Absent);

	public static function missingBadgeBindingBrowserModule():TestSession {
		final bindings = browserBadge.requiredBindingIds();
		bindings.shift();
		return session(BrowserModule, Exact(PROVIDER_VERSION, BROWSER_CLOSURE, CONTENT_ROOT, bindings));
	}

	public static function sameRequestInstanceReuseRejected():Bool {
		final first = exactPhpRequest();
		final second = exactPhpRequest();
		return switch first.probe(phpRead) {
			case Available(token): !token.authorizes(second, phpRead);
			case Unavailable(_): false;
		};
	}

	public static function browserReloadRejected():Bool {
		final loaded = exactBrowserModule();
		final reloaded = exactBrowserModule();
		return switch loaded.probe(browserBadge) {
			case Available(token): !token.authorizes(reloaded, browserBadge);
			case Unavailable(_): false;
		};
	}

	public static function staleProcessRejected():Bool {
		final started = session(PhpProcess, Exact(PROVIDER_VERSION, PHP_CLOSURE, CONTENT_ROOT, phpProcess.requiredBindingIds()));
		final restarted = session(PhpProcess, Exact(PROVIDER_VERSION, PHP_CLOSURE, CONTENT_ROOT, phpProcess.requiredBindingIds()));
		return switch started.probe(phpProcess) {
			case Available(token): !token.authorizes(restarted, phpProcess);
			case Unavailable(_): false;
		};
	}

	static function session(lifecycle:TestLifecycle, observation:TestObservation):TestSession {
		nextNonce += 1;
		return new TestSession(nextNonce, lifecycle, CONTENT_ROOT, observation);
	}
}

enum abstract TestLifecycle(String) {
	final PhpRequest = "php-request";
	final PhpProcess = "php-process";
	final BrowserModule = "browser-module";
}

enum TestFailure {
	RequiredProviderAbsent;
	OptionalProviderAbsent;
	WrongVersion;
	WrongArtifact;
	WrongLifecycle;
	MissingBinding(bindingId:String);
}

enum TestAvailability {
	Available(token:TestToken);
	Unavailable(reason:TestFailure);
}

private enum TestObservation {
	Exact(version:String, executableClosureSha256:String, bundleDigest:String, bindings:Array<String>);
	Absent;
}

final class TestCapability {
	public final id:String;
	public final lifecycle:TestLifecycle;
	public final required:Bool;
	public final executableClosureSha256:String;

	final bindings:Array<String>;

	public function new(id:String, lifecycle:TestLifecycle, required:Bool, executableClosureSha256:String, bindings:Array<String>) {
		this.id = id;
		this.lifecycle = lifecycle;
		this.required = required;
		this.executableClosureSha256 = executableClosureSha256;
		this.bindings = bindings.copy();
	}

	public function requiredBindingIds():Array<String>
		return bindings.copy();
}

final class TestSession {
	public final nonce:Int;
	public final lifecycle:TestLifecycle;
	public final bundleDigest:String;

	final observation:TestObservation;

	public function new(nonce:Int, lifecycle:TestLifecycle, bundleDigest:String, observation:TestObservation) {
		this.nonce = nonce;
		this.lifecycle = lifecycle;
		this.bundleDigest = bundleDigest;
		this.observation = observation;
	}

	public function probe(capability:TestCapability):TestAvailability {
		if (capability.lifecycle != lifecycle) {
			return Unavailable(WrongLifecycle);
		}
		return switch observation {
			case Absent: Unavailable(capability.required ? RequiredProviderAbsent : OptionalProviderAbsent);
			case Exact(version, executableClosureSha256, observedBundleDigest, bindings):
				if (version != "2.4.1") {
					Unavailable(WrongVersion);
				} else if (executableClosureSha256 != capability.executableClosureSha256) {
					Unavailable(WrongArtifact);
				} else {
					final missing = firstMissing(capability.requiredBindingIds(), bindings);
					missing == null ? Available(new TestToken(nonce, lifecycle, observedBundleDigest, capability.id,
						bindings)) : Unavailable(MissingBinding(missing));
				}
		};
	}

	public static function firstMissing(required:Array<String>, observed:Array<String>):Null<String> {
		for (binding in required) {
			if (observed.indexOf(binding) < 0) {
				return binding;
			}
		}
		return null;
	}
}

final class TestToken {
	final nonce:Int;
	final lifecycle:TestLifecycle;
	final bundleDigest:String;
	final capabilityId:String;
	final bindings:Array<String>;

	public function new(nonce:Int, lifecycle:TestLifecycle, bundleDigest:String, capabilityId:String, bindings:Array<String>) {
		this.nonce = nonce;
		this.lifecycle = lifecycle;
		this.bundleDigest = bundleDigest;
		this.capabilityId = capabilityId;
		this.bindings = bindings.copy();
	}

	public function authorizes(session:TestSession, capability:TestCapability):Bool {
		return session.nonce == nonce
			&& session.lifecycle == lifecycle
			&& session.bundleDigest == bundleDigest
			&& capability.lifecycle == lifecycle
			&& capability.id == capabilityId
			&& TestSession.firstMissing(capability.requiredBindingIds(), bindings) == null;
	}
}
