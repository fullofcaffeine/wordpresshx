package sdk044.windows;

import js.node.events.EventEmitter.Event;
import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.CliJson;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.project.ProjectLoader;
import wordpresshx.cli.project.development.DevelopmentPlan;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReadinessKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentReloadKind;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentServiceKind;
import wordpresshx.cli.project.development.DevelopmentProject;
import wordpresshx.cli.project.development.ServiceHost;
import wordpresshx.cli.project.development.ServiceSupervisor;

/**
 * Focused production-service supervisor used by the hosted Windows Job proof.
 *
 * It intentionally bypasses the separately withheld Windows generated-output
 * durability profile while exercising the real typed service supervisor,
 * RunningService, readiness, restart, and native ownership adapter.
 */
class Main {
	final sigintEvent:Event<Void->Void> = "SIGINT";
	final sigtermEvent:Event<Void->Void> = "SIGTERM";
	final sigbreakEvent:Event<Void->Void> = "SIGBREAK";
	final events:CliEventStream;
	final project:DevelopmentProject;
	final supervisor:ServiceSupervisor;
	var shuttingDown = false;

	static function main():Void {
		final arguments = NodeGlobals.process().argv.slice(2);
		if (arguments.length > 0 && arguments[0] == ServiceHost.INTERNAL_COMMAND) {
			ServiceHost.run(arguments);
			return;
		}
		if (arguments.length != 2) {
			throw new CliFailure("WPHX2327", "Windows service-host proof requires project root and service ID", 2, "service-start", null, []);
		}
		final serviceId = arguments[1];
		if (serviceId != "process-tree" && serviceId != "process-tree-rapid") {
			throw new CliFailure("WPHX2327", "Windows service-host proof received an unknown service ID", 2, "service-start", null, []);
		}
		new Main(arguments[0]).start(serviceId);
	}

	function new(root:String) {
		final context = ProjectLoader.resolve(ProjectLoader.discover(root));
		project = DevelopmentProject.from(context);
		events = new CliEventStream("dev", true);
		supervisor = new ServiceSupervisor(events, onFatal);
	}

	function start(serviceId:String):Void {
		final nodeProcess = NodeGlobals.process();
		nodeProcess.on(sigintEvent, onSigint);
		nodeProcess.on(sigtermEvent, onSigterm);
		if (nodeProcess.platform == "win32") {
			nodeProcess.on(sigbreakEvent, onSigbreak);
		}
		events.emit("command-started", "command", "started", CliJson.object([]));
		final service = new DevelopmentService(serviceId, DevelopmentServiceKind.External, [], ".", {
			component: "runtime.node",
			executable: "node",
			arguments: ["src/dev-service.mjs", serviceId, "{port}", ".wphx/runtime/service-trace.jsonl"]
		}, ["WPHX_TREE_SECRET"], {
			preferred: 44100,
			strict: false
		}, {
			kind: DevelopmentReadinessKind.Http,
			path: "/health",
			text: "",
			timeoutMs: 3000,
			intervalMs: 50
		}, {
			maxAttempts: 1,
			backoffMs: 50
		}, {
			scheme: "http",
			path: "/"
		}, DevelopmentReloadKind.NoReload);
		supervisor.reconcile(project, new DevelopmentPlan("sdk044/" + serviceId, [service]), failure -> {
			if (failure != null) {
				onFatal(failure);
				return;
			}
			events.emit("watch-ready", "watching", "ready", CliJson.object(["reason" => CliJson.text("focused production service supervisor is ready")]));
		});
	}

	function onSigint():Void {
		shutdown("SIGINT");
	}

	function onSigterm():Void {
		shutdown("SIGTERM");
	}

	function onSigbreak():Void {
		shutdown("SIGBREAK");
	}

	function shutdown(signal:String):Void {
		if (shuttingDown) {
			return;
		}
		shuttingDown = true;
		supervisor.shutdown(() -> {
			events.emit("command-completed", "command", "passed", CliJson.object([
				"exitCode" => CliJson.number(130),
				"reason" => CliJson.text("focused service supervisor stopped after " + signal)
			]));
			removeSignalListeners();
			NodeGlobals.process().exitCode = 130;
		});
	}

	function onFatal(failure:CliFailure):Void {
		events.failure(failure, project.profileId);
		removeSignalListeners();
		NodeGlobals.process().exitCode = failure.exitCode;
	}

	function removeSignalListeners():Void {
		final nodeProcess = NodeGlobals.process();
		nodeProcess.removeListener(sigintEvent, onSigint);
		nodeProcess.removeListener(sigtermEvent, onSigterm);
		if (nodeProcess.platform == "win32") {
			nodeProcess.removeListener(sigbreakEvent, onSigbreak);
		}
	}
}
