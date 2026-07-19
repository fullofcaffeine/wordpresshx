package wordpresshx.cli.project.development;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.Resource;
import js.lib.Error;
import js.node.Crypto;
import js.node.Http;
import js.node.http.IncomingMessage;
import js.node.http.Server;
import js.node.http.ServerResponse;
import js.node.http.ServerResponse.ServerResponseEvent;
import js.node.net.Server.ServerEvent;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReloadKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentServiceKind;

/** Loopback-only, capability-authenticated full-page reload transport. */
class BrowserReloadServer {
	static inline final RESOURCE_NAME = "wordpresshx-development-reload-client";
	public static inline final ROUTE_PREFIX = "/wordpresshx/reload/";

	final channels:Map<String, BrowserReloadChannel> = [];
	final startWaiters:Array<Null<CliFailure>->Void> = [];
	var server:Null<Server>;
	var port:Null<Int>;
	var starting = false;
	var stopping = false;

	public function new() {}

	public function prepare(service:DevelopmentService, servicePort:Int, callback:(Null<WordPressReloadAdapter>, Null<CliFailure>) -> Void):Void {
		if (service.kind != WordPress || service.reload != FullPage) {
			callback(null, null);
			return;
		}
		ensureStarted(failure -> {
			if (failure != null || port == null) {
				callback(null, failure == null ? unavailable("did not bind its loopback endpoint") : failure);
				return;
			}
			remove(service.id);
			final token = Crypto.randomBytes(32).toString("hex");
			final origin = service.url.scheme + "://127.0.0.1:" + Std.string(servicePort);
			final base = "http://127.0.0.1:" + Std.string(port) + ROUTE_PREFIX + token;
			final channel = new BrowserReloadChannel(service.id, origin, token, base + "/client.js", base + "/events");
			channels.set(service.id, channel);
			callback(new WordPressReloadAdapter(channel.clientUrl, channel.eventsUrl), null);
		});
	}

	public function broadcast(serviceId:String):Bool {
		final channel = channels.get(serviceId);
		if (channel == null) {
			return false;
		}
		channel.broadcast();
		return true;
	}

	public function remove(serviceId:String):Void {
		final channel = channels.get(serviceId);
		if (channel == null) {
			return;
		}
		channels.remove(serviceId);
		channel.close();
	}

	public function shutdown(callback:Void->Void):Void {
		if (stopping) {
			callback();
			return;
		}
		stopping = true;
		for (channel in channels) {
			channel.close();
		}
		channels.clear();
		final active = server;
		server = null;
		port = null;
		if (active == null) {
			callback();
			return;
		}
		try {
			active.close(callback);
		} catch (_:Exception) {
			callback();
		}
	}

	function ensureStarted(callback:Null<CliFailure>->Void):Void {
		if (stopping) {
			callback(unavailable("is already shutting down"));
			return;
		}
		if (server != null && port != null) {
			callback(null);
			return;
		}
		startWaiters.push(callback);
		if (starting) {
			return;
		}
		starting = true;
		final candidate = Http.createServer((request, response) -> handle(request, response));
		server = candidate;
		var settled = false;
		candidate.once(ServerEvent.Error, (_:Error) -> {
			if (settled) {
				return;
			}
			settled = true;
			server = null;
			port = null;
			completeStart(unavailable("could not reserve a loopback endpoint"));
		});
		candidate.listen(0, "127.0.0.1", () -> {
			if (settled) {
				return;
			}
			settled = true;
			candidate.timeout = 0;
			port = candidate.address().port;
			completeStart(null);
		});
	}

	function completeStart(failure:Null<CliFailure>):Void {
		starting = false;
		final callbacks = startWaiters.copy();
		startWaiters.resize(0);
		for (callback in callbacks) {
			callback(failure);
		}
	}

	function handle(request:IncomingMessage, response:ServerResponse):Void {
		if (request.method != "GET") {
			plain(response, 405, "method not allowed\n");
			return;
		}
		for (channel in channels) {
			if (request.url == channel.clientPath) {
				serveClient(request, response, channel);
				return;
			}
			if (request.url == channel.eventsPath) {
				serveEvents(request, response, channel);
				return;
			}
		}
		plain(response, 404, "not found\n");
	}

	function serveClient(request:IncomingMessage, response:ServerResponse, channel:BrowserReloadChannel):Void {
		final referer = header(request, "referer");
		if (referer != null && referer != channel.origin && !StringTools.startsWith(referer, channel.origin + "/")) {
			plain(response, 403, "forbidden\n");
			return;
		}
		final source = Resource.getString(RESOURCE_NAME);
		if (source == null) {
			plain(response, 503, "reload client unavailable\n");
			return;
		}
		response.writeHead(200, headers([
			"Access-Control-Allow-Origin" => channel.origin,
			"Cache-Control" => "no-store, no-transform",
			"Content-Security-Policy" => "default-src 'none'",
			"Content-Type" => "text/javascript; charset=utf-8",
			"Cross-Origin-Resource-Policy" => "cross-origin",
			"Referrer-Policy" => "no-referrer",
			"X-Content-Type-Options" => "nosniff"
		]));
		response.end(source);
	}

	function serveEvents(request:IncomingMessage, response:ServerResponse, channel:BrowserReloadChannel):Void {
		if (header(request, "origin") != channel.origin) {
			plain(response, 403, "forbidden\n");
			return;
		}
		response.writeHead(200, headers([
			"Access-Control-Allow-Origin" => channel.origin,
			"Cache-Control" => "no-store, no-transform",
			"Connection" => "keep-alive",
			"Content-Type" => "text/event-stream; charset=utf-8",
			"X-Accel-Buffering" => "no",
			"X-Content-Type-Options" => "nosniff"
		]));
		response.write(": wordpresshx connected\n\n");
		channel.add(response);
	}

	static function plain(response:ServerResponse, status:Int, body:String):Void {
		response.writeHead(status, headers([
			"Cache-Control" => "no-store",
			"Content-Type" => "text/plain; charset=utf-8",
			"X-Content-Type-Options" => "nosniff"
		]));
		response.end(body);
	}

	static function header(request:IncomingMessage, name:String):Null<String> {
		final values = request.rawHeaders;
		var index = 0;
		while (index + 1 < values.length) {
			if (values[index].toLowerCase() == name) {
				return values[index + 1];
			}
			index += 2;
		}
		return null;
	}

	static function headers(values:Map<String, String>):DynamicAccess<String> {
		final result = new DynamicAccess<String>();
		for (name => value in values) {
			result.set(name, value);
		}
		return result;
	}

	static function unavailable(message:String):CliFailure {
		return new CliFailure("WPHX2331", "WordPress browser reload transport " + message, 7, "service-start", null, [
			"Restart the development loop; use --services=none only when browser reload is intentionally disabled."
		]);
	}
}

private class BrowserReloadChannel {
	public final serviceId:String;
	public final origin:String;
	public final clientUrl:String;
	public final eventsUrl:String;
	public final clientPath:String;
	public final eventsPath:String;

	final clients:Array<ServerResponse> = [];

	public function new(serviceId:String, origin:String, token:String, clientUrl:String, eventsUrl:String) {
		this.serviceId = serviceId;
		this.origin = origin;
		this.clientUrl = clientUrl;
		this.eventsUrl = eventsUrl;
		this.clientPath = BrowserReloadServer.ROUTE_PREFIX + token + "/client.js";
		this.eventsPath = BrowserReloadServer.ROUTE_PREFIX + token + "/events";
	}

	public function add(response:ServerResponse):Void {
		clients.push(response);
		response.once(ServerResponseEvent.Close, () -> clients.remove(response));
	}

	public function broadcast():Void {
		for (response in clients.copy()) {
			if (response.finished) {
				clients.remove(response);
			} else {
				response.write("event: wordpresshx-reload\ndata: reload\n\n");
			}
		}
	}

	public function close():Void {
		for (response in clients.copy()) {
			if (!response.finished) {
				response.end();
			}
		}
		clients.resize(0);
	}
}
