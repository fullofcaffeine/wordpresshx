package wordpresshx.cli.project.development;

import js.lib.Error;
import js.node.Net;
import js.node.net.Server.ServerEvent;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;

/** Bounded loopback port selection with strict-port support. */
class PortAllocator {
	static inline final MAX_ALTERNATIVES = 100;

	final used:Map<Int, Bool> = [];

	public function new() {}

	public function allocate(service:DevelopmentService, callback:(Null<Int>, Null<CliFailure>) -> Void):Void {
		attempt(service, service.port.preferred, 0, callback);
	}

	public function release(port:Int):Void {
		used.remove(port);
	}

	function attempt(service:DevelopmentService, candidate:Int, alternatives:Int, callback:(Null<Int>, Null<CliFailure>) -> Void):Void {
		if (candidate > 65535 || alternatives > MAX_ALTERNATIVES) {
			callback(null, failure(service, "no collision-free loopback port was available in the bounded search"));
			return;
		}
		if (used.exists(candidate)) {
			if (service.port.strict) {
				callback(null, failure(service, "strict preferred port is already reserved by another development service"));
				return;
			}
			attempt(service, candidate + 1, alternatives + 1, callback);
			return;
		}
		final server = Net.createServer();
		var settled = false;
		server.once(ServerEvent.Error, (_:Error) -> {
			if (settled) {
				return;
			}
			settled = true;
			if (service.port.strict) {
				callback(null, failure(service, "strict preferred port is already occupied"));
			} else {
				attempt(service, candidate + 1, alternatives + 1, callback);
			}
		});
		server.listen(candidate, "127.0.0.1", () -> {
			if (settled) {
				return;
			}
			settled = true;
			server.close(() -> {
				used.set(candidate, true);
				callback(candidate, null);
			});
		});
	}

	static function failure(service:DevelopmentService, message:String):CliFailure {
		return new CliFailure("WPHX2320", "development service " + service.id + ": " + message, 7, "service-start", null, [
			service.port.strict ? "Free the configured port or set strictPort to false in the Haxe declaration." : "Free a loopback port near the preferred value and restart the development loop."
		]);
	}
}
