package wordpresshx.cli.project.development;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.Timer;
import js.Syntax;
import js.node.ChildProcess;
import js.node.child_process.ChildProcess.ChildProcessEvent;
import js.node.events.EventEmitter.Event;
import wordpresshx.cli.NodeGlobals;

/** Typed view of the SDK-owned Node IPC channel available only to this host. */
private extern class ServiceHostProcess {
	public var connected(default, never):Bool;
	public function send(message:String):Bool;
	public function on(event:Event<String->Void>, listener:String->Void):ServiceHostProcess;
}

/**
 * Stable POSIX process-group leader for one external development service.
 *
 * The user command is a child in this host's process group. The host ignores
 * graceful group termination, reports payload exit over its private IPC
 * channel, and remains alive until WordPressHx sends the final group-wide
 * forced signal. That pins the process-group identity across rapid payload
 * exit without exposing the IPC channel to the payload.
 */
class ServiceHost {
	public static inline final INTERNAL_COMMAND = "__wordpresshx-service-host-v1";
	public static inline final PAYLOAD_EXITED = "wordpresshx-service-payload-exited-v1";
	public static inline final PAYLOAD_FAILED = "wordpresshx-service-payload-failed-v1";
	public static inline final GRACEFUL_STOP = "wordpresshx-service-graceful-stop-v1";
	public static inline final FORCE_STOP = "wordpresshx-service-force-stop-v1";
	static var keepAlive:Null<Timer>;
	static var notified = false;

	public static function arguments(entryPath:String, executable:String, payloadArguments:Array<String>):Array<String> {
		return [entryPath, INTERNAL_COMMAND, executable].concat(payloadArguments);
	}

	public static function run(arguments:Array<String>):Void {
		if (arguments.length < 2 || arguments[0] != INTERNAL_COMMAND) {
			throw new Exception("invalid internal service-host invocation");
		}
		final nodeProcess = NodeGlobals.process();
		if (nodeProcess.platform == "win32") {
			throw new Exception("POSIX service host cannot run on Windows");
		}
		if (!processChannel().connected) {
			throw new Exception("POSIX service host requires its private parent IPC channel");
		}
		notified = false;
		keepAlive = new Timer(60000);
		keepAlive.run = () -> {};
		final gracefulEvent:Event<Void->Void> = "SIGTERM";
		nodeProcess.on(gracefulEvent, () -> {});
		final messageEvent:Event<String->Void> = "message";
		processChannel().on(messageEvent, processCommand);
		final disconnectEvent:Event<Void->Void> = "disconnect";
		nodeProcess.once(disconnectEvent, terminateOwnedGroup);

		final payload = ChildProcess.spawn(arguments[1], arguments.slice(2), {
			cwd: nodeProcess.cwd(),
			env: copyEnvironment(nodeProcess.env),
			detached: false,
			shell: false,
			stdio: ["ignore", "inherit", "inherit"]
		});
		payload.once(ChildProcessEvent.Error, _ -> notify(PAYLOAD_FAILED));
		payload.once(ChildProcessEvent.Exit, (_, _) -> notify(PAYLOAD_EXITED));
	}

	static function notify(message:String):Void {
		if (notified) {
			return;
		}
		notified = true;
		try {
			processChannel().send(message);
		} catch (_:Exception) {
			terminateOwnedGroup();
		}
	}

	static function processCommand(command:String):Void {
		switch command {
			case GRACEFUL_STOP:
				signalOwnedGroup("SIGTERM");
			case FORCE_STOP:
				terminateOwnedGroup();
			default:
		}
	}

	static function terminateOwnedGroup():Void {
		signalOwnedGroup("SIGKILL");
	}

	static function signalOwnedGroup(signal:String):Void {
		final nodeProcess = NodeGlobals.process();
		try {
			nodeProcess.kill(-nodeProcess.pid, signal);
		} catch (_:Exception) {
			nodeProcess.exit(70);
		}
	}

	static function copyEnvironment(source:DynamicAccess<String>):DynamicAccess<String> {
		final result = new DynamicAccess<String>();
		for (name in source.keys()) {
			final value = source.get(name);
			if (value != null) {
				result.set(name, value);
			}
		}
		return result;
	}

	static inline function processChannel():ServiceHostProcess {
		return Syntax.code("process");
	}
}
