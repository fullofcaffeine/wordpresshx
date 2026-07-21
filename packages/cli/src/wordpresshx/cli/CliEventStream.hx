package wordpresshx.cli;

import js.node.Crypto;
import wordpresshx.cli.closedjson.JsonValue;

/** Canonical JSONL event stream with a compact human rendering. */
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

	public function emit(event:String, stage:String, status:String, payload:JsonValue):Void {
		sequence++;
		final value = CliJson.object([
			"schema" => CliJson.text("wordpress-hx.cli-event.v1"),
			"runId" => CliJson.text(runId),
			"sequence" => CliJson.number(sequence),
			"elapsedMs" => CliJson.number(Std.int(Date.now().getTime() - started)),
			"command" => CliJson.text(command),
			"event" => CliJson.text(event),
			"stage" => CliJson.text(stage),
			"status" => CliJson.text(status),
			"payload" => payload
		]);
		if (json) {
			NodeGlobals.process().stdout.write(CanonicalJson.encode(value) + "\n");
			return;
		}
		switch (event) {
			case "stage-started":
				NodeGlobals.process().stdout.write("→ " + stage + "\n");
			case "stage-completed":
				NodeGlobals.process().stdout.write("✓ " + stage + "\n");
			case "stage-skipped":
				NodeGlobals.process().stdout.write("– " + stage + ": " + Contract.string(payload, "reason", "stage-skipped payload") + "\n");
			case "build-published":
				NodeGlobals.process().stdout.write("✓ published generation " + Contract.string(payload, "manifestDigest", "build-published payload") + "\n");
			case "build-retained":
				NodeGlobals.process().stdout.write("! rebuild failed; last-good generation retained\n");
			case "compiler-server-ready":
				NodeGlobals.process().stdout.write("✓ project compiler cache ready\n");
			case "change-detected":
				NodeGlobals.process().stdout.write("↻ " + Contract.integer(payload, "coalescedChanges", "change-detected payload") + " changed path(s)\n");
			case "watch-ready":
				NodeGlobals.process().stdout.write("✓ watching effective inputs\n");
			case "shutdown-started":
				NodeGlobals.process().stdout.write("→ shutting down development services\n");
			case "dry-run-planned":
				NodeGlobals.process().stdout.write("✓ dry-run validated; project files unchanged\n");
			case _:
		}
	}

	public function stageStarted(stage:String, payload:JsonValue):Void {
		emit("stage-started", stage, "running", payload);
	}

	public function stageCompleted(stage:String, payload:JsonValue):Void {
		emit("stage-completed", stage, "passed", payload);
	}

	public function stageSkipped(stage:String, reason:String, ?mode:String):Void {
		final fields:Map<String, JsonValue> = ["reason" => CliJson.text(reason)];
		if (mode != null) {
			fields.set("mode", CliJson.text(mode));
		}
		emit("stage-skipped", stage, "skipped", CliJson.object(fields));
	}

	public function failure(failure:CliFailure, profile:String):Void {
		diagnostic(failure, profile);
		if (json) {
			emit("command-completed", "command", "failed", CliJson.object([
				"exitCode" => CliJson.number(failure.exitCode),
				"reason" => CliJson.text(failure.code + ": " + failure.message)
			]));
		}
	}

	public function diagnostic(failure:CliFailure, profile:String, ?buildId:String, severity:String = "error"):Void {
		final path = diagnosticPath(failure.relativePath);
		final remediations = failure.remediations.length == 0 ? ["Run wphx doctor for the exact failing contract."] : failure.remediations;
		if (json) {
			final diagnostic = CliJson.object([
				"code" => CliJson.text(failure.code),
				"severity" => CliJson.text(severity),
				"message" => CliJson.text(failure.message),
				"profile" => CliJson.text(profile),
				"source" => CliJson.object([
					"path" => CliJson.text(path),
					"line" => CliJson.number(1),
					"column" => CliJson.number(0)
				]),
				"remediations" => CliJson.texts(remediations),
				"reference" => CliJson.text("wphx doctor")
			]);
			final payload:Map<String, JsonValue> = ["diagnostic" => diagnostic];
			if (buildId != null) {
				payload.set("buildId", CliJson.text(buildId));
			}
			emit("diagnostic", failure.stage, severity == "error" ? "failed" : "running", CliJson.object(payload));
			return;
		}
		final label = severity == "error" ? "wphx" : "wphx warning";
		NodeGlobals.process().stderr.write(label + " " + failure.code + " [" + failure.stage + "]: " + failure.message + "\n");
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
