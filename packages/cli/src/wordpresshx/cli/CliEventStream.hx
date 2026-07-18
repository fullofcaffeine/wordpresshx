package wordpresshx.cli;

import js.node.Crypto;
import wordpresshx.cli.ownership.OwnershipJson;

/** Canonical JSONL event stream with a compact human rendering. **/
class CliEventStream {
	final command:String;
	final json:Bool;
	final runId:String;
	final started:Float;
	var sequence:Int = 0;

	public function new(command:String, json:Bool) {
		this.command = command;
		this.json = json;
		this.runId = "run/" + Crypto.randomBytes(12).toString("hex");
		this.started = Date.now().getTime();
	}

	public function emit(event:String, stage:String, status:String, payload:Dynamic):Void {
		sequence++;
		final value = OwnershipJson.object([
			"schema" => "wordpress-hx.cli-event.v1",
			"runId" => runId,
			"sequence" => sequence,
			"elapsedMs" => Std.int(Date.now().getTime() - started),
			"command" => command,
			"event" => event,
			"stage" => stage,
			"status" => status,
			"payload" => payload
		]);
		if (json) {
			NodeGlobals.process().stdout.write(OwnershipJson.encode(value) + "\n");
			return;
		}
		switch (event) {
			case "stage-started":
				NodeGlobals.process().stdout.write("→ " + stage + "\n");
			case "stage-completed":
				NodeGlobals.process().stdout.write("✓ " + stage + "\n");
			case "stage-skipped":
				NodeGlobals.process().stdout.write("– " + stage + ": " + Reflect.field(payload, "reason") + "\n");
			case "build-published":
				NodeGlobals.process().stdout.write("✓ published generation " + Reflect.field(payload, "manifestDigest") + "\n");
			case "dry-run-planned":
				NodeGlobals.process().stdout.write("✓ dry-run validated; project files unchanged\n");
			case _:
		}
	}

	public function stageStarted(stage:String, payload:Dynamic):Void {
		emit("stage-started", stage, "running", payload);
	}

	public function stageCompleted(stage:String, payload:Dynamic):Void {
		emit("stage-completed", stage, "passed", payload);
	}

	public function stageSkipped(stage:String, reason:String, ?mode:String):Void {
		final fields:Map<String, Dynamic> = ["reason" => reason];
		if (mode != null) {
			fields.set("mode", mode);
		}
		emit("stage-skipped", stage, "skipped", OwnershipJson.object(fields));
	}

	public function failure(failure:CliFailure, profile:String):Void {
		final path = diagnosticPath(failure.relativePath);
		final remediations = failure.remediations.length == 0 ? ["Run wphx doctor for the exact failing contract."] : failure.remediations;
		if (json) {
			final diagnostic = OwnershipJson.object([
				"code" => failure.code,
				"severity" => "error",
				"message" => failure.message,
				"profile" => profile,
				"source" => OwnershipJson.object(["path" => path, "line" => 1, "column" => 0]),
				"remediations" => remediations,
				"reference" => "wphx doctor"
			]);
			emit("diagnostic", failure.stage, "failed", OwnershipJson.object(["diagnostic" => diagnostic]));
			emit("command-completed", "command", "failed", OwnershipJson.object([
				"exitCode" => failure.exitCode,
				"reason" => failure.code + ": " + failure.message
			]));
			return;
		}
		NodeGlobals.process().stderr.write("wphx " + failure.code + " [" + failure.stage + "]: " + failure.message + "\n");
		if (failure.relativePath != null) {
			NodeGlobals.process().stderr.write("  at " + failure.relativePath + "\n");
		}
		for (remediation in remediations) {
			NodeGlobals.process().stderr.write("  fix: " + remediation + "\n");
		}
	}

	static function diagnosticPath(candidate:Null<String>):String {
		if (candidate == null || candidate.length == 0 || StringTools.startsWith(candidate, "/") || candidate.indexOf("\\") >= 0) {
			return "wordpress-hx.json";
		}
		for (segment in candidate.split("/")) {
			if (segment.length == 0 || segment == "." || segment == "..") {
				return "wordpress-hx.json";
			}
		}
		return candidate;
	}
}
