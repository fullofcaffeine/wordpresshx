package wordpresshx.cli.project;

import haxe.Exception;
import haxe.Timer;
import js.node.events.EventEmitter.Event;
import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliInvocation;
import wordpresshx.cli.CliJson;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.project.development.DevelopmentPlanReader;
import wordpresshx.cli.project.development.DevelopmentProject;
import wordpresshx.cli.project.development.EffectiveInputSnapshot;
import wordpresshx.cli.project.development.ServiceSupervisor;

/** Serialized development orchestrator: build, watch, retain, and cleanly stop. **/
class DevEngine {
	static inline final DEBOUNCE_MS = 100;
	static var active:Null<DevEngine>;

	final invocation:CliInvocation;
	final events:CliEventStream;
	final compiler:ManagedCompiler;
	final watcher:WatchGraph;
	final services:ServiceSupervisor;
	final pending:Map<String, Bool> = [];
	final sigintEvent:Event<Void->Void> = "SIGINT";
	final sigtermEvent:Event<Void->Void> = "SIGTERM";
	var context:ProjectContext;
	var debounce:Null<Timer>;
	var building = false;
	var shuttingDown = false;
	var generation = 0;
	var buildSequence = 0;
	var lastManifestDigest:Null<String>;

	public static function start(context:ProjectContext, invocation:CliInvocation, events:CliEventStream):Void {
		if (active != null) {
			throw new CliFailure("WPHX2101", "a development engine is already active in this process", 7, "watching");
		}
		final engine = new DevEngine(context, invocation, events);
		active = engine;
		engine.begin();
	}

	function new(context:ProjectContext, invocation:CliInvocation, events:CliEventStream) {
		this.context = context;
		this.invocation = invocation;
		this.events = events;
		this.compiler = new ManagedCompiler(message -> warning(message));
		this.watcher = new WatchGraph(context.bootstrap.root, path -> changed(path), message -> watcherProblem(message));
		this.services = new ServiceSupervisor(events, failure -> serviceFatal(failure));
	}

	function begin():Void {
		final nodeProcess = NodeGlobals.process();
		nodeProcess.on(sigintEvent, onSigint);
		nodeProcess.on(sigtermEvent, onSigterm);
		compiler.ensure(context, (available, started) -> {
			if (shuttingDown) {
				return;
			}
			if (available && started) {
				emitCompilerReady(context);
			}
			initialBuild();
		});
	}

	function initialBuild():Void {
		building = true;
		final attempt = context;
		final buildId = nextBuildId();
		try {
			prepareServicePlan(attempt);
			final result = ProjectBuild.run(attempt, events, "initial", buildId, compiler.typeProject, true, false, generation + 1);
			if (result != null) {
				generation++;
				lastManifestDigest = result.manifestDigest;
				reconcileServices(attempt, buildId, false, () -> {
					activateWatcher(attempt);
					finishAttempt(attempt);
				});
				return;
			}
		} catch (failure:CliFailure) {
			retain(attempt, buildId, "initial", failure);
		} catch (_:Exception) {
			retain(attempt, buildId, "initial", internalFailure());
		}
		activateWatcher(attempt);
		finishAttempt(attempt);
	}

	function activateWatcher(attempt:ProjectContext):Void {
		try {
			watcher.refresh(attempt);
		} catch (_:Exception) {
			watcherProblem("could not subscribe to the complete effective-input graph");
		}
		if (invocation.services == "none") {
			events.stageSkipped("service-start", "development services disabled by --services=none", "initial");
		} else if (services.serviceCount() == 0) {
			events.stageSkipped("service-start", "current compiler generation contains no admitted development services", "initial");
		}
		events.emit("watch-ready", "watching", "ready", CliJson.object([
			"reason" =>
			CliJson.text(invocation.services == "none" ? "effective input graph subscribed after the initial transaction; compile/watch-only mode" : services.serviceCount() == 0 ? "effective input graph subscribed after the initial transaction; no typed services were declared" : "effective input graph subscribed after the initial transaction; typed services are ready")
		]));
	}

	function changed(path:String):Void {
		if (shuttingDown) {
			return;
		}
		pending.set(path, true);
		if (debounce != null) {
			debounce.stop();
		}
		debounce = Timer.delay(flush, DEBOUNCE_MS);
	}

	function flush():Void {
		debounce = null;
		if (shuttingDown || pending.keys().hasNext() == false) {
			return;
		}
		if (building) {
			return;
		}
		final observedPaths = drainPending();
		building = true;
		var attempt:ProjectContext;
		final buildId = nextBuildId();
		try {
			attempt = ProjectLoader.resolve(ProjectLoader.discover(context.bootstrap.root), invocation.profile);
			watcher.refresh(attempt);
		} catch (failure:CliFailure) {
			emitChanges(observedPaths);
			events.diagnostic(failure, context.profileId(), buildId);
			emitRetained(context, buildId, "rebuild", context.fingerprint(), "effective input graph resolution failed; last-good generation remains live");
			building = false;
			schedulePending();
			return;
		} catch (_:Exception) {
			emitChanges(observedPaths);
			final failure = internalFailure();
			events.diagnostic(failure, context.profileId(), buildId);
			emitRetained(context, buildId, "rebuild", context.fingerprint(), "unexpected graph resolution failure; last-good generation remains live");
			building = false;
			schedulePending();
			return;
		}
		final effectivePaths = changedPaths(context, attempt, false);
		final paths = effectivePaths.length == 0 ? observedPaths : effectivePaths;
		emitChanges(paths);

		if (attempt.fingerprint() == context.fingerprint()) {
			context = attempt;
			events.stageSkipped("watching", "filesystem event did not change the authenticated effective-input fingerprint", "rebuild");
			building = false;
			schedulePending();
			return;
		}
		events.emit("rebuild-scheduled", "watching", "running", CliJson.object([
			"mode" => CliJson.text("rebuild"),
			"buildId" => CliJson.text(buildId),
			"fingerprint" => CliJson.text(attempt.fingerprint()),
			"changedPaths" => CliJson.texts(paths),
			"coalescedChanges" => CliJson.number(paths.length)
		]));
		context = attempt;
		compiler.ensure(attempt, (available, started) -> {
			if (shuttingDown) {
				return;
			}
			if (available && started) {
				emitCompilerReady(attempt);
			}
			rebuild(attempt, buildId);
		});
	}

	function rebuild(attempt:ProjectContext, buildId:String):Void {
		try {
			prepareServicePlan(attempt);
			final result = ProjectBuild.run(attempt, events, "rebuild", buildId, compiler.typeProject, true, false, generation + 1);
			if (result != null) {
				generation++;
				lastManifestDigest = result.manifestDigest;
				reconcileServices(attempt, buildId, true, () -> finishAttempt(attempt));
				return;
			}
		} catch (failure:CliFailure) {
			retain(attempt, buildId, "rebuild", failure);
		} catch (_:Exception) {
			retain(attempt, buildId, "rebuild", internalFailure());
		}
		finishAttempt(attempt);
	}

	function retain(attempt:ProjectContext, buildId:String, mode:String, failure:CliFailure):Void {
		events.diagnostic(failure, attempt.profileId(), buildId);
		if (lastManifestDigest == null) {
			lastManifestDigest = safeManifestDigest(attempt);
		}
		if (lastManifestDigest != null) {
			emitRetained(attempt, buildId, mode, attempt.fingerprint(), "build failed before publication; the exact last-good manifest remains live");
		}
	}

	function emitRetained(attempt:ProjectContext, buildId:String, mode:String, fingerprint:String, reason:String):Void {
		if (lastManifestDigest == null) {
			return;
		}
		events.emit("build-retained", "ownership-publish", "retained", CliJson.object([
			"mode" => CliJson.text(mode),
			"buildId" => CliJson.text(buildId),
			"fingerprint" => CliJson.text(fingerprint),
			"retainedManifestDigest" => CliJson.text(lastManifestDigest),
			"reason" => CliJson.text(reason)
		]));
	}

	function finishAttempt(attempt:ProjectContext):Void {
		try {
			final latest = ProjectLoader.resolve(ProjectLoader.discover(attempt.bootstrap.root), invocation.profile);
			watcher.refresh(latest);
			if (latest.fingerprint() != attempt.fingerprint()) {
				for (path in changedPaths(attempt, latest)) {
					pending.set(path, true);
				}
			} else {
				context = latest;
			}
		} catch (_:Exception) {
			try {
				watcher.refresh(attempt);
			} catch (_:Exception) {}
		}
		building = false;
		schedulePending();
	}

	function schedulePending():Void {
		if (!shuttingDown && pending.keys().hasNext() && debounce == null) {
			debounce = Timer.delay(flush, 0);
		}
	}

	function drainPending():Array<String> {
		final result = [for (path in pending.keys()) path];
		pending.clear();
		result.sort(compareText);
		return result;
	}

	function emitChanges(paths:Array<String>):Void {
		events.emit("change-detected", "watching", "running", CliJson.object([
			"changedPaths" => CliJson.texts(paths),
			"coalescedChanges" => CliJson.number(paths.length)
		]));
	}

	function watcherProblem(message:String):Void {
		warning(message + "; watcher subscriptions will be refreshed on the next graph pass");
		changed("wordpress-hx.json");
	}

	function warning(message:String):Void {
		final failure = new CliFailure("WPHX2100", message, 7, "compiler-server", null, [
			"The development loop remains correct with direct compilation; run wphx doctor before the next session."
		]);
		events.diagnostic(failure, context.profileId(), null, "warning");
	}

	function emitCompilerReady(serverContext:ProjectContext):Void {
		final snapshot = EffectiveInputSnapshot.from(serverContext);
		events.emit("compiler-server-ready", "compiler-server", "ready", CliJson.object([
			"serviceId" => CliJson.text("compiler"),
			"serviceKind" => CliJson.text("compiler"),
			"processOwnership" => CliJson.text("owned"),
			"serverCompatibilityDigest" => CliJson.text(snapshot.compilerCompatibilityDigest)
		]));
	}

	function onSigint():Void {
		shutdown("SIGINT", 130);
	}

	function onSigterm():Void {
		shutdown("SIGTERM", 143);
	}

	function shutdown(signal:String, exitCode:Int):Void {
		if (shuttingDown) {
			return;
		}
		shuttingDown = true;
		if (debounce != null) {
			debounce.stop();
			debounce = null;
		}
		watcher.close();
		events.emit("shutdown-started", "shutdown", "interrupted", CliJson.object(["mode" => CliJson.text("shutdown"), "reason" => CliJson.text(signal)]));
		final ownedCompiler = compiler.ownsServer();
		services.shutdown(() -> {
			compiler.shutdown(() -> {
				if (ownedCompiler) {
					events.emit("service-stopped", "shutdown", "stopped", CliJson.object([
						"serviceId" => CliJson.text("compiler"),
						"serviceKind" => CliJson.text("compiler"),
						"processOwnership" => CliJson.text("owned")
					]));
				}
				events.emit("command-completed", "command", "interrupted", CliJson.object([
					"exitCode" => CliJson.number(exitCode),
					"reason" => CliJson.text(signal + " handled; all owned development processes stopped")
				]));
				final nodeProcess = NodeGlobals.process();
				nodeProcess.removeListener(sigintEvent, onSigint);
				nodeProcess.removeListener(sigtermEvent, onSigterm);
				nodeProcess.exitCode = exitCode;
				active = null;
			});
		});
	}

	function nextBuildId():String {
		buildSequence++;
		return "dev-build-" + StringTools.lpad(Std.string(buildSequence), "0", 6);
	}

	static function safeManifestDigest(context:ProjectContext):Null<String> {
		try {
			return BuildPublisher.currentManifestDigest(context);
		} catch (_:Exception) {
			return null;
		}
	}

	static function changedPaths(before:ProjectContext, after:ProjectContext, fallback:Bool = true):Array<String> {
		final oldFiles = EffectiveInputSnapshot.from(before).files;
		final newFiles = EffectiveInputSnapshot.from(after).files;
		final changed:Map<String, Bool> = [];
		for (path => digest in oldFiles) {
			if (!newFiles.exists(path) || newFiles.get(path) != digest) {
				changed.set(path, true);
			}
		}
		for (path => digest in newFiles) {
			if (!oldFiles.exists(path) || oldFiles.get(path) != digest) {
				changed.set(path, true);
			}
		}
		if (fallback && !changed.keys().hasNext()) {
			changed.set("wordpress-hx.json", true);
		}
		final result = [for (path in changed.keys()) path];
		result.sort(compareText);
		return result;
	}

	function prepareServicePlan(attempt:ProjectContext):Void {
		if (invocation.services != "none") {
			DevelopmentPlanReader.prepare(attempt);
		}
	}

	function reconcileServices(attempt:ProjectContext, buildId:String, reload:Bool, callback:Void->Void):Void {
		if (invocation.services == "none") {
			if (reload) {
				events.stageSkipped("watching", "published generation has no admitted reload adapter", "rebuild");
			}
			callback();
			return;
		}
		try {
			final project = DevelopmentProject.from(attempt);
			final plan = DevelopmentPlanReader.load(attempt, project);
			services.reconcile(project, plan, failure -> {
				if (failure != null) {
					events.diagnostic(failure, attempt.profileId(), buildId);
				} else if (reload && services.serviceCount() > 0) {
					services.requestReloads();
				} else if (reload) {
					events.stageSkipped("watching", "published generation has no admitted reload adapter", "rebuild");
				}
				callback();
			});
		} catch (failure:CliFailure) {
			events.diagnostic(failure, attempt.profileId(), buildId);
			callback();
		} catch (_:Exception) {
			events.diagnostic(internalFailure(), attempt.profileId(), buildId);
			callback();
		}
	}

	function serviceFatal(failure:CliFailure):Void {
		events.diagnostic(failure, context.profileId(), null);
		shutdown("service failure", failure.exitCode);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function internalFailure():CliFailure {
		return new CliFailure("WPHX9001", "unexpected internal development-loop failure", 70, "watching", null, [
			"Stop the loop, run wphx doctor, and report the redacted event stream if the failure repeats."
		]);
	}
}
