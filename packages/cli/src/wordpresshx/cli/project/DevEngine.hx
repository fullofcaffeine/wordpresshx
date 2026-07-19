package wordpresshx.cli.project;

import haxe.Timer;
import js.node.events.EventEmitter.Event;
import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliInvocation;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.ownership.OwnershipJson;

/** Serialized development orchestrator: build, watch, retain, and cleanly stop. **/
class DevEngine {
	static inline final DEBOUNCE_MS = 100;
	static var active:Null<DevEngine>;

	final invocation:CliInvocation;
	final events:CliEventStream;
	final compiler:ManagedCompiler;
	final watcher:WatchGraph;
	final pending:Map<String, Bool> = [];
	final sigintEvent:Event<Void->Void> = cast "SIGINT";
	final sigtermEvent:Event<Void->Void> = cast "SIGTERM";
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
			final result = ProjectBuild.run(attempt, events, "initial", buildId, compiler.typeProject, true, false, generation + 1);
			if (result != null) {
				generation++;
				lastManifestDigest = result.manifestDigest;
			}
		} catch (failure:CliFailure) {
			retain(attempt, buildId, "initial", failure);
		} catch (_:Dynamic) {
			retain(attempt, buildId, "initial", internalFailure());
		}
		activateWatcher(attempt);
		finishAttempt(attempt);
	}

	function activateWatcher(attempt:ProjectContext):Void {
		try {
			watcher.refresh(attempt);
		} catch (_:Dynamic) {
			watcherProblem("could not subscribe to the complete effective-input graph");
		}
		final serviceReason = invocation.services == "none" ? "development services disabled by --services=none" : "validated semantic plan contains no admitted development services";
		events.stageSkipped("service-start", serviceReason, "initial");
		events.emit("watch-ready", "watching", "ready", OwnershipJson.object([
			"reason" =>
			invocation.services == "none" ? "effective input graph subscribed after the initial transaction; compile/watch-only mode" : "effective input graph subscribed after the initial transaction; no typed services were declared"
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
		} catch (_:Dynamic) {
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
		events.emit("rebuild-scheduled", "watching", "running", OwnershipJson.object([
			"mode" => "rebuild",
			"buildId" => buildId,
			"fingerprint" => attempt.fingerprint(),
			"changedPaths" => paths,
			"coalescedChanges" => paths.length
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
			final result = ProjectBuild.run(attempt, events, "rebuild", buildId, compiler.typeProject, true, false, generation + 1);
			if (result != null) {
				generation++;
				lastManifestDigest = result.manifestDigest;
				events.stageSkipped("watching", "published generation has no admitted reload adapter", "rebuild");
			}
		} catch (failure:CliFailure) {
			retain(attempt, buildId, "rebuild", failure);
		} catch (_:Dynamic) {
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
		events.emit("build-retained", "ownership-publish", "retained", OwnershipJson.object([
			"mode" => mode,
			"buildId" => buildId,
			"fingerprint" => fingerprint,
			"retainedManifestDigest" => lastManifestDigest,
			"reason" => reason
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
		} catch (_:Dynamic) {
			try {
				watcher.refresh(attempt);
			} catch (_:Dynamic) {}
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
		result.sort(Reflect.compare);
		return result;
	}

	function emitChanges(paths:Array<String>):Void {
		events.emit("change-detected", "watching", "running", OwnershipJson.object(["changedPaths" => paths, "coalescedChanges" => paths.length]));
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
		final server = ProjectContract.fieldObject(serverContext.effectiveInputs, "compileServer", "effective inputs");
		events.emit("compiler-server-ready", "compiler-server", "ready", OwnershipJson.object([
			"serviceId" => "compiler",
			"serviceKind" => "compiler",
			"processOwnership" => "owned",
			"serverCompatibilityDigest" => ProjectContract.string(server, "compatibilityDigest", "compile server")
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
		events.emit("shutdown-started", "shutdown", "interrupted", OwnershipJson.object(["mode" => "shutdown", "reason" => signal]));
		final ownedCompiler = compiler.ownsServer();
		compiler.shutdown(() -> {
			if (ownedCompiler) {
				events.emit("service-stopped", "shutdown", "stopped", OwnershipJson.object([
					"serviceId" => "compiler",
					"serviceKind" => "compiler",
					"processOwnership" => "owned"
				]));
			}
			events.emit("command-completed", "command", "interrupted", OwnershipJson.object([
				"exitCode" => exitCode,
				"reason" => signal + " handled; all owned development processes stopped"
			]));
			final nodeProcess = NodeGlobals.process();
			nodeProcess.removeListener(sigintEvent, onSigint);
			nodeProcess.removeListener(sigtermEvent, onSigterm);
			nodeProcess.exitCode = exitCode;
			active = null;
		});
	}

	function nextBuildId():String {
		buildSequence++;
		return "dev-build-" + StringTools.lpad(Std.string(buildSequence), "0", 6);
	}

	static function safeManifestDigest(context:ProjectContext):Null<String> {
		try {
			return BuildPublisher.currentManifestDigest(context);
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function changedPaths(before:ProjectContext, after:ProjectContext, fallback:Bool = true):Array<String> {
		final oldFiles = fileDigests(before.effectiveInputs);
		final newFiles = fileDigests(after.effectiveInputs);
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
		result.sort(Reflect.compare);
		return result;
	}

	static function fileDigests(effectiveInputs:Dynamic):Map<String, String> {
		final result:Map<String, String> = [];
		for (file in ProjectContract.array(effectiveInputs, "files", "effective inputs")) {
			result.set(ProjectContract.string(file, "path", "effective input file"), ProjectContract.string(file, "sha256", "effective input file"));
		}
		return result;
	}

	static function internalFailure():CliFailure {
		return new CliFailure("WPHX9001", "unexpected internal development-loop failure", 70, "watching", null, [
			"Stop the loop, run wphx doctor, and report the redacted event stream if the failure repeats."
		]);
	}
}
