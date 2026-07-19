package wordpresshx.cli.generatedoutput;

import js.node.Buffer;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonDocument;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectContract;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Static, content-bound admission policy for selected generated roots. */
class GeneratedOutputPolicy {
	public static inline final PATH = ".wphx/generated-output-vcs.json";
	public static inline final SCHEMA = "wordpress-hx.generated-output-vcs-project.v1";
	public static inline final MODE = "consumer-committed-output-opt-in";
	public static inline final DIGEST_ALGORITHM = "sha256-canonical-json-without-policyDigest-v1";

	public final projectId:String;
	public final roots:Array<GeneratedOutputRoot>;
	public final workflowPath:String;
	public final workflowSha256:String;
	public final policyDigest:String;
	public final value:JsonValue;

	public static function create(projectId:String, roots:Array<GeneratedOutputRoot>, workflow:GeneratedOutputWorkflow):GeneratedOutputPolicy {
		validateProjectId(projectId);
		validateRoots(roots);
		final material = materialValue(projectId, roots, workflow.path, workflow.sha256);
		final digest = CanonicalJson.digest(material);
		return new GeneratedOutputPolicy(projectId, copyRoots(roots), workflow.path, workflow.sha256, digest,
			completeValue(projectId, roots, workflow.path, workflow.sha256, digest));
	}

	public static function parse(bytes:Buffer):GeneratedOutputPolicy {
		try {
			final value = JsonDocument.parseCanonical(bytes, PATH, "WPHX3410");
			final reader = JsonReader.from(value, "generated-output policy", "WPHX3410");
			reader.exact([
				"schema",
				"canonicalization",
				"policyDigestAlgorithm",
				"policyDigest",
				"mode",
				"projectId",
				"authority",
				"outputRoots",
				"manifestSchema",
				"continuousIntegration",
				"verification"
			], "WPHX3410");
			expect(reader.string("schema", "WPHX3410"), SCHEMA, "policy schema");
			expect(reader.string("canonicalization", "WPHX3410"), "wordpress-hx.canonical-json.v1", "policy canonicalization");
			expect(reader.string("policyDigestAlgorithm", "WPHX3410"), DIGEST_ALGORITHM, "policy digest algorithm");
			expect(reader.string("mode", "WPHX3410"), MODE, "policy mode");
			expect(reader.string("manifestSchema", "WPHX3410"), "wordpress-hx.generated-files.v1", "manifest schema");
			final projectId = reader.string("projectId", "WPHX3410");
			validateProjectId(projectId);
			validateAuthority(reader.object("authority", "WPHX3410"));
			validateVerification(reader.object("verification", "WPHX3410"));
			final roots = parseRoots(reader.array("outputRoots", "WPHX3410"));
			final ci = parseContinuousIntegration(reader.object("continuousIntegration", "WPHX3410"));
			final digest = reader.string("policyDigest", "WPHX3410");
			if (!ProjectContract.SHA256.match(digest)) {
				fail("policy digest must be a lowercase SHA-256");
			}
			if (digest != CanonicalJson.digest(CanonicalJson.withoutField(value, "policyDigest"))) {
				fail("policy digest does not bind the canonical policy");
			}
			return new GeneratedOutputPolicy(projectId, roots, ci.path, ci.sha256, digest, value);
		} catch (failure:CliFailure) {
			throw failure;
		} catch (failure:haxe.Exception) {
			throw new CliFailure("WPHX3410", failure.message, 5, "generated-output-policy", PATH, [
				"Restore the exact generated-output policy or rerun the deliberate enable command after removing it."
			], failure);
		}
	}

	public function document():String {
		return JsonDocument.encode(value);
	}

	public function sameSelection(project:String, selected:Array<GeneratedOutputRoot>):Bool {
		if (projectId != project || roots.length != selected.length) {
			return false;
		}
		for (index in 0...roots.length) {
			if (roots[index].id != selected[index].id || roots[index].path != selected[index].path) {
				return false;
			}
		}
		return true;
	}

	public function sameWorkflow(workflow:GeneratedOutputWorkflow):Bool {
		return workflowPath == workflow.path && workflowSha256 == workflow.sha256;
	}

	static function materialValue(projectId:String, roots:Array<GeneratedOutputRoot>, workflowPath:String, workflowSha256:String):JsonValue {
		return documentValue(projectId, roots, workflowPath, workflowSha256, null);
	}

	static function completeValue(projectId:String, roots:Array<GeneratedOutputRoot>, workflowPath:String, workflowSha256:String, digest:String):JsonValue {
		return documentValue(projectId, roots, workflowPath, workflowSha256, digest);
	}

	static function documentValue(projectId:String, roots:Array<GeneratedOutputRoot>, workflowPath:String, workflowSha256:String,
			digest:Null<String>):JsonValue {
		final fields = [
			ScaffoldJson.field("schema", ScaffoldJson.text(SCHEMA)),
			ScaffoldJson.field("canonicalization", ScaffoldJson.text("wordpress-hx.canonical-json.v1")),
			ScaffoldJson.field("policyDigestAlgorithm", ScaffoldJson.text(DIGEST_ALGORITHM))
		];
		if (digest != null) {
			fields.push(ScaffoldJson.field("policyDigest", ScaffoldJson.text(digest)));
		}
		fields.push(ScaffoldJson.field("mode", ScaffoldJson.text(MODE)));
		fields.push(ScaffoldJson.field("projectId", ScaffoldJson.text(projectId)));
		fields.push(ScaffoldJson.field("authority", ScaffoldJson.object([
			ScaffoldJson.field("applicationSource", ScaffoldJson.text("haxe")),
			ScaffoldJson.field("exactProjectLockRequired", ScaffoldJson.boolean(true)),
			ScaffoldJson.field("generatedOutputRole", ScaffoldJson.text("derived-inspectable-non-authoritative")),
			ScaffoldJson.field("handEditsAllowed", ScaffoldJson.boolean(false)),
			ScaffoldJson.field("releaseRegenerationRequired", ScaffoldJson.boolean(true))
		])));
		fields.push(ScaffoldJson.field("outputRoots", ScaffoldJson.array([
			for (root in roots)
				ScaffoldJson.object([
					ScaffoldJson.field("id", ScaffoldJson.text(root.id)),
					ScaffoldJson.field("path", ScaffoldJson.text(root.path))
				])
		])));
		fields.push(ScaffoldJson.field("manifestSchema", ScaffoldJson.text("wordpress-hx.generated-files.v1")));
		fields.push(ScaffoldJson.field("continuousIntegration", ScaffoldJson.object([
			ScaffoldJson.field("provider", ScaffoldJson.text("github-actions")),
			ScaffoldJson.field("workflowPath", ScaffoldJson.text(workflowPath)),
			ScaffoldJson.field("workflowSha256", ScaffoldJson.text(workflowSha256)),
			ScaffoldJson.field("command", ScaffoldJson.array([
				ScaffoldJson.text("./node_modules/.bin/wphx"),
				ScaffoldJson.text("generated-output"),
				ScaffoldJson.text("check"),
				ScaffoldJson.text("--project"),
				ScaffoldJson.text("."),
				ScaffoldJson.text("--json")
			]))
		])));
		fields.push(ScaffoldJson.field("verification", ScaffoldJson.object([
			ScaffoldJson.field("command",
				ScaffoldJson.array([
					ScaffoldJson.text("wphx"),
					ScaffoldJson.text("generated-output"),
					ScaffoldJson.text("check"),
					ScaffoldJson.text("--json")
				])),
			ScaffoldJson.field("comparison", ScaffoldJson.text("exact-path-size-sha256-and-bytes")),
			ScaffoldJson.field("freshSource", ScaffoldJson.text("clean-head-local-clone"))
		])));
		return ScaffoldJson.object(fields);
	}

	static function parseRoots(values:Array<JsonValue>):Array<GeneratedOutputRoot> {
		final roots:Array<GeneratedOutputRoot> = [];
		for (index in 0...values.length) {
			final reader = JsonReader.from(values[index], "generated-output policy.outputRoots[" + index + "]", "WPHX3410");
			reader.exact(["id", "path"], "WPHX3410");
			roots.push(new GeneratedOutputRoot(reader.string("id", "WPHX3410"), reader.string("path", "WPHX3410")));
		}
		validateRoots(roots);
		return roots;
	}

	static function parseContinuousIntegration(reader:JsonReader):GeneratedOutputWorkflowIdentity {
		reader.exact(["provider", "workflowPath", "workflowSha256", "command"], "WPHX3410");
		expect(reader.string("provider", "WPHX3410"), "github-actions", "continuous-integration provider");
		final path = reader.string("workflowPath", "WPHX3410");
		validatePath(path);
		if (!StringTools.startsWith(path, ".github/workflows/wordpresshx-generated-output-") || !StringTools.endsWith(path, ".yml")) {
			fail("continuous-integration workflow path differs");
		}
		final sha256 = reader.string("workflowSha256", "WPHX3410");
		if (!ProjectContract.SHA256.match(sha256)) {
			fail("continuous-integration workflow digest must be a lowercase SHA-256");
		}
		final command = reader.strings("command", "WPHX3410");
		if (command.join("\n") != "./node_modules/.bin/wphx\ngenerated-output\ncheck\n--project\n.\n--json") {
			fail("continuous-integration command differs");
		}
		return {path: path, sha256: sha256};
	}

	static function validateAuthority(reader:JsonReader):Void {
		reader.exact([
			"applicationSource",
			"exactProjectLockRequired",
			"generatedOutputRole",
			"handEditsAllowed",
			"releaseRegenerationRequired"
		], "WPHX3410");
		expect(reader.string("applicationSource", "WPHX3410"), "haxe", "authored source authority");
		expect(reader.string("generatedOutputRole", "WPHX3410"), "derived-inspectable-non-authoritative", "generated-output role");
		if (!reader.boolean("exactProjectLockRequired", "WPHX3410")
			|| reader.boolean("handEditsAllowed", "WPHX3410")
			|| !reader.boolean("releaseRegenerationRequired", "WPHX3410")) {
			fail("policy authority invariants differ");
		}
	}

	static function validateVerification(reader:JsonReader):Void {
		reader.exact(["command", "comparison", "freshSource"], "WPHX3410");
		final command = reader.strings("command", "WPHX3410");
		if (command.join("\n") != "wphx\ngenerated-output\ncheck\n--json") {
			fail("verification command differs");
		}
		expect(reader.string("comparison", "WPHX3410"), "exact-path-size-sha256-and-bytes", "verification comparison");
		expect(reader.string("freshSource", "WPHX3410"), "clean-head-local-clone", "verification source");
	}

	static function validateProjectId(projectId:String):Void {
		if (!ProjectContract.STABLE_ID.match(projectId)) {
			fail("policy project ID must be a stable ID");
		}
	}

	static function validateRoots(roots:Array<GeneratedOutputRoot>):Void {
		if (roots.length == 0) {
			fail("policy must name at least one output root");
		}
		var previousId:Null<String> = null;
		final paths:Array<String> = [];
		for (root in roots) {
			if (!ProjectContract.STABLE_ID.match(root.id)) {
				fail("policy output-root ID must be stable");
			}
			validatePath(root.path);
			if (previousId != null && compareText(previousId, root.id) >= 0) {
				fail("policy output roots must be sorted by unique ID");
			}
			previousId = root.id;
			for (path in paths) {
				if (path == root.path || nested(path, root.path) || nested(root.path, path)) {
					fail("policy output-root paths must be unique and non-nested");
				}
			}
			paths.push(root.path);
		}
	}

	static function validatePath(path:String):Void {
		try {
			ProjectContract.relativePath(path, "generated-output policy root");
		} catch (_:haxe.Exception) {
			fail("policy output-root path is outside the portable project policy");
		}
	}

	static function nested(parent:String, candidate:String):Bool {
		return StringTools.startsWith(candidate, parent + "/");
	}

	static function expect(actual:String, expected:String, label:String):Void {
		if (actual != expected) {
			fail(label + " differs");
		}
	}

	static function copyRoots(roots:Array<GeneratedOutputRoot>):Array<GeneratedOutputRoot> {
		return [for (root in roots) new GeneratedOutputRoot(root.id, root.path)];
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function fail<T>(message:String):T {
		throw new CliFailure("WPHX3410", message, 5, "generated-output-policy", PATH, [
			"Restore the exact policy or remove it and rerun generated-output enable with explicit root IDs."
		]);
	}

	function new(projectId:String, roots:Array<GeneratedOutputRoot>, workflowPath:String, workflowSha256:String, policyDigest:String, value:JsonValue) {
		this.projectId = projectId;
		this.roots = roots;
		this.workflowPath = workflowPath;
		this.workflowSha256 = workflowSha256;
		this.policyDigest = policyDigest;
		this.value = value;
	}
}

private typedef GeneratedOutputWorkflowIdentity = {
	final path:String;
	final sha256:String;
}
