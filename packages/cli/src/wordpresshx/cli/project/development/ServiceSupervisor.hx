package wordpresshx.cli.project.development;

import haxe.Exception;
import haxe.Timer;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReloadKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;

/** Dependency-ordered owned-process lifecycle for validated development plans. */
class ServiceSupervisor {
	final events:DevelopmentEvents;
	final allocator = new PortAllocator();
	final reloads = new BrowserReloadServer();
	final onFatal:CliFailure->Void;
	final running:Array<RunningService> = [];
	final restartCounts:Map<String, Int> = [];
	var project:Null<DevelopmentProject>;
	var plan:Null<DevelopmentPlan>;
	var activeDigest:Null<String>;
	var transitionCallback:Null<Null<CliFailure>->Void>;
	var transitionToken = 0;
	var transitioning = false;
	var restartTransition = false;
	var stopping = false;

	public function new(eventStream:CliEventStream, onFatal:CliFailure->Void) {
		events = new DevelopmentEvents(eventStream);
		this.onFatal = onFatal;
	}

	public function reconcile(nextProject:DevelopmentProject, nextPlan:DevelopmentPlan, callback:Null<CliFailure>->Void):Void {
		if (stopping) {
			callback(failure("cannot reconcile services while shutdown is in progress"));
			return;
		}
		if (transitioning) {
			callback(failure("another service transition is already in progress"));
			return;
		}
		project = nextProject;
		plan = nextPlan;
		if (activeDigest != null && activeDigest == nextPlan.serviceDigest) {
			callback(null);
			return;
		}
		restartCounts.clear();
		beginTransition(callback, false, "validated service plan changed");
	}

	public function requestReloads():Void {
		if (transitioning || stopping) {
			return;
		}
		for (service in running) {
			if (service.service.reload == FullPage) {
				reloads.broadcast(service.service.id);
				events.reload(service.service, service.url);
			}
		}
	}

	public function shutdown(callback:Void->Void):Void {
		if (stopping) {
			callback();
			return;
		}
		stopping = true;
		transitionToken++;
		transitioning = false;
		transitionCallback = null;
		stopAll("development loop shutdown", () -> {
			reloads.shutdown(() -> {
				activeDigest = null;
				callback();
			});
		});
	}

	public function serviceCount():Int {
		return running.length;
	}

	function beginTransition(callback:Null<CliFailure>->Void, restart:Bool, stopReason:String):Void {
		transitioning = true;
		restartTransition = restart;
		transitionCallback = callback;
		transitionToken++;
		final token = transitionToken;
		stopAll(stopReason, () -> startPlan(token));
	}

	function startPlan(token:Int):Void {
		if (!currentTransition(token)) {
			return;
		}
		final currentPlan = plan;
		final currentProject = project;
		if (currentPlan == null || currentProject == null) {
			abortTransition(token, failure("validated service plan context is unavailable"));
			return;
		}
		final ordered = dependencyOrder(currentPlan.services);
		startAt(token, currentProject, currentPlan, ordered, 0);
	}

	function startAt(token:Int, currentProject:DevelopmentProject, currentPlan:DevelopmentPlan, ordered:Array<DevelopmentService>, index:Int):Void {
		if (!currentTransition(token)) {
			return;
		}
		if (index >= ordered.length) {
			activeDigest = currentPlan.serviceDigest;
			transitioning = false;
			restartTransition = false;
			final callback = transitionCallback;
			transitionCallback = null;
			if (callback != null) {
				callback(null);
			}
			return;
		}
		final service = ordered[index];
		allocator.allocate(service, (port, portFailure) -> {
			if (!currentTransition(token)) {
				return;
			}
			if (portFailure != null || port == null) {
				abortTransition(token, portFailure == null ? failure("port allocation returned no result") : portFailure);
				return;
			}
			reloads.prepare(service, port, (reload, reloadFailure) -> {
				if (!currentTransition(token)) {
					reloads.remove(service.id);
					allocator.release(port);
					return;
				}
				if (reloadFailure != null) {
					allocator.release(port);
					abortTransition(token, reloadFailure);
					return;
				}
				events.starting(service);
				var started:RunningService;
				try {
					started = RunningService.start(currentProject, service, port, reload, events, serviceFailure);
				} catch (failure:CliFailure) {
					reloads.remove(service.id);
					allocator.release(port);
					abortTransition(token, failure);
					return;
				} catch (error:Exception) {
					reloads.remove(service.id);
					allocator.release(port);
					abortTransition(token, failure("could not start an admitted development process"));
					return;
				}
				running.push(started);
				ReadinessProbe.wait(started, readinessFailure -> {
					if (!currentTransition(token)) {
						return;
					}
					if (readinessFailure != null) {
						abortTransition(token, readinessFailure);
						return;
					}
					events.ready(service, started.url);
					startAt(token, currentProject, currentPlan, ordered, index + 1);
				});
			});
		});
	}

	function serviceFailure(service:RunningService, failure:CliFailure):Void {
		if (stopping) {
			return;
		}
		if (transitioning) {
			abortTransition(transitionToken, failure);
			return;
		}
		final attempts = restartCounts.exists(service.service.id) ? restartCounts.get(service.service.id) : 0;
		if (attempts >= service.service.restart.maxAttempts) {
			stopping = true;
			stopAll("restart policy exhausted",
				() -> onFatal(new CliFailure("WPHX2325", "development service " + service.service.id + " exhausted its bounded restart policy", 7,
					"service-start", null, ["Fix the service crash and restart the development loop."])));
			return;
		}
		restartCounts.set(service.service.id, attempts + 1);
		transitioning = true;
		restartTransition = true;
		transitionCallback = null;
		transitionToken++;
		final token = transitionToken;
		stopAll("owned service graph restart", () -> Timer.delay(() -> startPlan(token), service.service.restart.backoffMs));
	}

	function abortTransition(token:Int, failure:CliFailure):Void {
		if (!currentTransition(token)) {
			return;
		}
		transitionToken++;
		final fatal = restartTransition;
		restartTransition = false;
		final callback = transitionCallback;
		transitionCallback = null;
		stopAll("service transition failed", () -> {
			transitioning = false;
			activeDigest = null;
			if (fatal) {
				onFatal(failure);
			} else if (callback != null) {
				callback(failure);
			}
		});
	}

	function stopAll(reason:String, callback:Void->Void):Void {
		stopAt(running.length - 1, reason, callback);
	}

	function stopAt(index:Int, reason:String, callback:Void->Void):Void {
		if (index < 0) {
			running.resize(0);
			callback();
			return;
		}
		final service = running[index];
		service.stop(reason, () -> {
			reloads.remove(service.service.id);
			allocator.release(service.port);
			stopAt(index - 1, reason, callback);
		});
	}

	static function dependencyOrder(services:Array<DevelopmentService>):Array<DevelopmentService> {
		final byId:Map<String, DevelopmentService> = [];
		for (service in services) {
			byId.set(service.id, service);
		}
		final visited:Map<String, Bool> = [];
		final result:Array<DevelopmentService> = [];
		for (service in services) {
			appendDependencies(service, byId, visited, result);
		}
		return result;
	}

	static function appendDependencies(service:DevelopmentService, byId:Map<String, DevelopmentService>, visited:Map<String, Bool>,
			result:Array<DevelopmentService>):Void {
		if (visited.exists(service.id)) {
			return;
		}
		for (dependency in service.dependsOn) {
			final required = byId.get(dependency);
			if (required != null) {
				appendDependencies(required, byId, visited, result);
			}
		}
		visited.set(service.id, true);
		result.push(service);
	}

	inline function currentTransition(token:Int):Bool {
		return transitioning && !stopping && transitionToken == token;
	}

	static function failure(message:String):CliFailure {
		return new CliFailure("WPHX2326", message, 7, "service-start", null, ["Restart the development loop from a clean current build."]);
	}
}
