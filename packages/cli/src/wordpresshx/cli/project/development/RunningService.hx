package wordpresshx.cli.project.development;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.Timer;
import js.Syntax;
import js.lib.Error;
import js.node.ChildProcess;
import js.node.child_process.ChildProcess as NodeChildProcess;
import js.node.child_process.ChildProcess.ChildProcessEvent;
import js.node.events.EventEmitter.Event;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.project.ProjectFiles;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentCommand;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentServiceKind;
import wordpresshx.cli.project.development.DevelopmentProcessLaunch.DevelopmentProcessOwnership;

private typedef OwnedSpawnOptions = {
	> js.node.ChildProcessSpawnOptions,
	final windowsHide:Bool;
}

/** One owned no-shell process with bounded output retained only for readiness. */
class RunningService {
	static inline final LOG_WINDOW = 65536;
	static inline final STOP_TIMEOUT_MS = 3000;
	static final OPERATIONAL_ENVIRONMENT = ["COMSPEC", "PATH", "PATHEXT", "SystemRoot", "TEMP", "TMP"];

	public final service:DevelopmentService;
	public final port:Int;
	public final url:String;
	public final wordpressPluginEntry:Null<String>;
	public var alive(default, null) = true;
	public var stopping(default, null) = false;

	final child:NodeChildProcess;
	final treeOwned:Bool;
	final windowsOwned:Bool;
	final events:DevelopmentEvents;
	final onFailure:RunningService->CliFailure->Void;
	final cleanup:Null<(Void->Void)->Void>;
	var logWindow = "";
	var failureReported = false;
	var cleanupStarted = false;
	var stopCallback:Null<Void->Void>;
	var stopReason = "stopped";
	var stopTimer:Null<Timer>;
	var forceSent = false;
	var hostAlive = true;

	public static function start(project:DevelopmentProject, service:DevelopmentService, port:Int, reload:Null<WordPressReloadAdapter>,
			events:DevelopmentEvents, onFailure:RunningService->CliFailure->Void):RunningService {
		final environment = environmentFor(project, service, port);
		final workingDirectory = service.workingDirectory == "." ? project.root : ProjectFiles.requireDirectory(project.root, service.workingDirectory,
			"development service working directory", "service-start");
		final launch = switch service.kind {
			case External: externalLaunch(service, port, workingDirectory, environment);
			case WordPress: WordPressProvider.launch(project, service, port, workingDirectory, environment, reload);
		};
		final treeOwned = launch.ownership == OwnedProcessTree;
		final nodeProcess = NodeGlobals.process();
		final windowsOwned = treeOwned && nodeProcess.platform == "win32";
		final executable = if (windowsOwned) {
			WindowsServiceHost.executable(nodeProcess.argv[1]);
		} else if (treeOwned) {
			nodeProcess.execPath;
		} else {
			launch.executable;
		};
		final arguments = if (windowsOwned) {
			WindowsServiceHost.arguments(launch.executable, launch.arguments);
		} else if (treeOwned) {
			ServiceHost.arguments(nodeProcess.argv[1], launch.executable, launch.arguments);
		} else {
			launch.arguments;
		};
		final spawnOptions:OwnedSpawnOptions = {
			cwd: launch.workingDirectory,
			detached: treeOwned,
			env: launch.environment,
			shell: false,
			stdio: windowsOwned ? ["pipe", "pipe", "pipe"] : treeOwned ? ["ignore", "pipe", "pipe", "ipc"] : ["ignore", "pipe", "pipe"],
			windowsHide: windowsOwned
		};
		final child = ChildProcess.spawn(executable, arguments, spawnOptions);
		try {
			final plugin = project.deployablePlugin;
			return new RunningService(service, port, child, treeOwned, windowsOwned, events, onFailure, launch.cleanup, plugin == null ? null : plugin.entry);
		} catch (error:Exception) {
			child.kill("SIGKILL");
			throw error;
		}
	}

	function new(service:DevelopmentService, port:Int, child:NodeChildProcess, treeOwned:Bool, windowsOwned:Bool, events:DevelopmentEvents,
			onFailure:RunningService->CliFailure->Void, cleanup:Null<(Void->Void)->Void>, wordpressPluginEntry:Null<String>) {
		this.service = service;
		this.port = port;
		this.child = child;
		this.treeOwned = treeOwned;
		this.windowsOwned = windowsOwned;
		this.events = events;
		this.onFailure = onFailure;
		this.cleanup = cleanup;
		this.wordpressPluginEntry = wordpressPluginEntry;
		this.url = service.url.scheme + "://127.0.0.1:" + port + service.url.path;
		capture(child.stdout);
		capture(child.stderr);
		if (treeOwned && !windowsOwned) {
			final messageEvent:Event<String->Void> = "message";
			child.on(messageEvent, processHostMessage);
		}
		child.once(ChildProcessEvent.Error, processError);
		child.once(ChildProcessEvent.Exit, processExit);
	}

	public function containsLog(text:String):Bool {
		return logWindow.indexOf(text) >= 0;
	}

	public function stop(reason:String, callback:Void->Void):Void {
		if (stopCallback != null) {
			callback();
			return;
		}
		stopping = true;
		stopReason = reason;
		stopCallback = callback;
		if (!alive) {
			if (!treeOwned) {
				finishStop();
			} else {
				beginGroupStop();
			}
			return;
		}
		if (!treeOwned) {
			child.kill("SIGTERM");
			stopTimer = Timer.delay(() -> {
				if (alive) {
					child.kill("SIGKILL");
				}
			}, STOP_TIMEOUT_MS);
			return;
		}
		beginGroupStop();
	}

	function capture(stream:js.node.stream.Readable.IReadable):Void {
		stream.setEncoding("utf8");
		final dataEvent:Event<String->Void> = "data";
		stream.on(dataEvent, chunk -> {
			logWindow += chunk;
			if (logWindow.length > LOG_WINDOW) {
				logWindow = logWindow.substr(logWindow.length - LOG_WINDOW);
			}
		});
	}

	function processError(_:Error):Void {
		if (stopping || failureReported) {
			return;
		}
		failureReported = true;
		onFailure(this, failure("could not start or supervise its admitted executable"));
	}

	function processHostMessage(message:String):Void {
		if (message != ServiceHost.PAYLOAD_EXITED && message != ServiceHost.PAYLOAD_FAILED) {
			return;
		}
		alive = false;
		if (stopping) {
			forceGroupStop();
			return;
		}
		if (failureReported) {
			return;
		}
		failureReported = true;
		onFailure(this, failure(message == ServiceHost.PAYLOAD_FAILED ? "could not start its admitted executable" : "exited before shutdown"));
	}

	function processExit(code:Int, signal:String):Void {
		hostAlive = false;
		alive = false;
		if (stopping) {
			finishStop();
			return;
		}
		if (!failureReported) {
			failureReported = true;
			final reason = signal == null || signal.length == 0 ? "exited before shutdown" : "was terminated before shutdown";
			onFailure(this, failure(reason));
		}
	}

	function finishStop():Void {
		if (cleanupStarted) {
			return;
		}
		cleanupStarted = true;
		if (stopTimer != null) {
			stopTimer.stop();
			stopTimer = null;
		}
		if (cleanup != null) {
			cleanup(completeStop);
			return;
		}
		completeStop();
	}

	function beginGroupStop():Void {
		if (!treeOwned) {
			finishStop();
			return;
		}
		if (!hostAlive) {
			finishStop();
			return;
		}
		forceSent = false;
		sendHostCommand(ServiceHost.GRACEFUL_STOP);
		if (!alive) {
			forceGroupStop();
			return;
		}
		stopTimer = Timer.delay(() -> {
			stopTimer = null;
			forceGroupStop();
		}, STOP_TIMEOUT_MS);
	}

	function forceGroupStop():Void {
		if (!hostAlive) {
			finishStop();
			return;
		}
		if (forceSent) {
			return;
		}
		forceSent = true;
		if (stopTimer != null) {
			stopTimer.stop();
			stopTimer = null;
		}
		if (!treeOwned) {
			finishStop();
			return;
		}
		sendHostCommand(ServiceHost.FORCE_STOP);
	}

	function sendHostCommand(command:String):Void {
		if (!hostAlive) {
			return;
		}
		try {
			if (windowsOwned) {
				final windowsCommand = command == ServiceHost.GRACEFUL_STOP ? WindowsServiceHost.GRACEFUL_STOP : WindowsServiceHost.FORCE_STOP;
				WindowsServiceHost.send(child, windowsCommand);
			} else if (hostChannelConnected(child)) {
				sendIpc(child, command);
			}
		} catch (_:Exception) {}
	}

	function completeStop():Void {
		events.stopped(service, stopReason);
		final callback = stopCallback;
		stopCallback = null;
		if (callback != null) {
			callback();
		}
	}

	static function externalLaunch(service:DevelopmentService, port:Int, workingDirectory:String, environment:DynamicAccess<String>):DevelopmentProcessLaunch {
		final command = requireCommand(service);
		return {
			executable: command.executable,
			arguments: [
				for (argument in command.arguments)
					StringTools.replace(argument, "{port}", Std.string(port))
			],
			workingDirectory: workingDirectory,
			environment: environment,
			ownership: OwnedProcessTree,
			cleanup: null
		};
	}

	function failure(message:String):CliFailure {
		return new CliFailure("WPHX2321", "development service " + service.id + " " + message, 7, "service-start", null, [
			"Fix the typed service declaration or its exact locked tool, then restart the development loop."
		]);
	}

	static function environmentFor(project:DevelopmentProject, service:DevelopmentService, port:Int):DynamicAccess<String> {
		final result = new DynamicAccess<String>();
		final source = NodeGlobals.process().env;
		for (name in OPERATIONAL_ENVIRONMENT) {
			final value = source.get(name);
			if (value != null) {
				result.set(name, value);
			}
		}
		result.set("PORT", Std.string(port));
		for (name in service.environment) {
			final rule = project.environmentRule(name);
			if (rule == null) {
				return environmentFailure(service, "requested an environment name outside project policy");
			}
			final value = source.get(name);
			if (value == null) {
				if (rule.required) {
					return environmentFailure(service, "requires a runtime environment value that is not set");
				}
				continue;
			}
			result.set(name, value);
		}
		return result;
	}

	static function requireCommand(service:DevelopmentService):DevelopmentCommand {
		if (service.command == null) {
			return environmentFailure(service, "does not have an external command adapter");
		}
		return service.command;
	}

	static inline function hostChannelConnected(child:NodeChildProcess):Bool {
		return Syntax.code("{0}.connected === true", child);
	}

	static inline function sendIpc(child:NodeChildProcess, message:String):Bool {
		return Syntax.code("{0}.send({1})", child, message);
	}

	static function environmentFailure<T>(service:DevelopmentService, message:String):T {
		throw new CliFailure("WPHX2322", "development service " + service.id + " " + message, 7, "service-start", null, [
			"Declare and provide only the runtime environment names required by this service."
		]);
	}
}
