package wordpresshx.cli.project.development;

import haxe.Timer;
import js.lib.Error;
import js.node.Http as NodeHttp;
import js.node.Net;
import js.node.net.Socket.SocketEvent;
import js.node.stream.Writable.WritableEvent;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReadinessKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentServiceKind;

/** Bounded readiness polling for one owned service process. */
class ReadinessProbe {
	public static function wait(service:RunningService, callback:Null<CliFailure>->Void):Void {
		final deadline = Date.now().getTime() + service.service.readiness.timeoutMs;
		attempt(service, deadline, new ReadinessObservation(), callback);
	}

	static function attempt(service:RunningService, deadline:Float, observation:ReadinessObservation, callback:Null<CliFailure>->Void):Void {
		if (!service.alive || service.stopping) {
			callback(failure(service, "stopped before readiness completed"));
			return;
		}
		probe(service, observation, ready -> {
			if (ready) {
				callback(null);
				return;
			}
			if (Date.now().getTime() >= deadline) {
				final details = service.service.kind == WordPress && service.wordpressPluginEntry != null ? observation.description() : "";
				callback(failure(service, "did not become ready before its bounded timeout" + details));
				return;
			}
			Timer.delay(() -> attempt(service, deadline, observation, callback), service.service.readiness.intervalMs);
		});
	}

	static function probe(service:RunningService, observation:ReadinessObservation, callback:Bool->Void):Void {
		switch service.service.readiness.kind {
			case Http:
				http(service, observation, callback);
			case Log:
				callback(service.containsLog(service.service.readiness.text));
			case Process:
				Timer.delay(() -> callback(service.alive && !service.stopping), service.service.readiness.intervalMs);
			case Tcp:
				tcp(service, callback);
		}
	}

	static function http(service:RunningService, observation:ReadinessObservation, callback:Bool->Void):Void {
		var settled = false;
		final complete = (ready:Bool) -> {
			if (settled) {
				return;
			}
			settled = true;
			callback(ready);
		};
		final request = NodeHttp.get({
			host: "127.0.0.1",
			port: service.port,
			path: service.service.readiness.path
		}, response -> {
			final status = response.statusCode;
			final pluginEntry = service.wordpressPluginEntry;
			final pluginHeader = response.headers.get("x-wordpresshx-plugin");
			final statusReady = status >= 200 && status < (service.service.kind == WordPress ? 300 : 400);
			final bootstrapReady = observation.observeBootstrap(service.service.kind != WordPress
				|| service.service.readiness.text.length == 0
				|| service.containsLog(service.service.readiness.text));
			final pluginReady = pluginEntry == null || pluginHeader == pluginEntry;
			observation.record(status, statusReady, bootstrapReady, pluginHeader != null, pluginReady);
			response.resume();
			complete(statusReady && bootstrapReady && pluginReady);
		});
		request.once(WritableEvent.Error, (_:Error) -> complete(false));
		request.setTimeout(probeTimeout(service), () -> {
			request.abort();
			complete(false);
		});
	}

	static function tcp(service:RunningService, callback:Bool->Void):Void {
		var settled = false;
		final socket = Net.createConnection(service.port, "127.0.0.1");
		socket.once(SocketEvent.Connect, () -> {
			if (settled) {
				return;
			}
			settled = true;
			socket.destroy();
			callback(true);
		});
		socket.once(SocketEvent.Error, (_:Error) -> {
			if (settled) {
				return;
			}
			settled = true;
			callback(false);
		});
		socket.setTimeout(probeTimeout(service), () -> {
			if (settled) {
				return;
			}
			settled = true;
			socket.destroy();
			callback(false);
		});
	}

	static function probeTimeout(service:RunningService):Int {
		return service.service.readiness.intervalMs < 1000 ? service.service.readiness.intervalMs : 1000;
	}

	static function failure(service:RunningService, message:String):CliFailure {
		return new CliFailure("WPHX2323", "development service " + service.service.id + " " + message, 7, "service-readiness", null, [
			"Correct the typed readiness declaration or service startup behavior and restart the development loop."
		]);
	}
}

private class ReadinessObservation {
	var responseSeen = false;
	var status = 0;
	var statusReady = false;
	var bootstrapReady = false;
	var pluginHeaderPresent = false;
	var pluginHeaderReady = false;

	public function new() {}

	public function record(status:Int, statusReady:Bool, bootstrapReady:Bool, pluginHeaderPresent:Bool, pluginHeaderReady:Bool):Void {
		responseSeen = true;
		this.status = status;
		this.statusReady = statusReady;
		this.bootstrapReady = this.bootstrapReady || bootstrapReady;
		this.pluginHeaderPresent = pluginHeaderPresent;
		this.pluginHeaderReady = pluginHeaderReady;
	}

	public function observeBootstrap(observed:Bool):Bool {
		bootstrapReady = bootstrapReady || observed;
		return bootstrapReady;
	}

	public function description():String {
		if (!responseSeen) {
			return "; no HTTP response was observed";
		}
		final header = !pluginHeaderPresent ? "absent" : pluginHeaderReady ? "matched" : "mismatched";
		return "; last HTTP probe status " + Std.string(status) + (statusReady ? " accepted" : " rejected") + ", bootstrap sentinel "
			+ (bootstrapReady ? "observed" : "missing") + ", active-plugin header " + header;
	}
}
