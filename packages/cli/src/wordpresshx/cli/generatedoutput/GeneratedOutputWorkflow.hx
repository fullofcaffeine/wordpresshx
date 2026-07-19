package wordpresshx.cli.generatedoutput;

import js.node.Buffer;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.project.ProjectFiles;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Exact GitHub Actions projection for committed-output regeneration. */
class GeneratedOutputWorkflow {
	static inline final CHECKOUT_ACTION = "actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0";
	static inline final SETUP_NODE_ACTION = "actions/setup-node@48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e";
	static inline final SETUP_HAXE_ACTION = "krdlab/setup-haxe@d93667502be3b4f31a94a3308a74388f2e178a8d";

	public final path:String;
	public final content:String;
	public final sha256:String;

	public static function create(projectId:String, projectPrefix:String):GeneratedOutputWorkflow {
		final identity = Content.digest(projectPrefix + "\n" + projectId).substr(0, 24);
		final path = ".github/workflows/wordpresshx-generated-output-" + identity + ".yml";
		final workingDirectory = projectPrefix.length == 0 ? "." : projectPrefix;
		final content = [
			"name: " + yamlText("WordPressHx generated output (" + projectId + ")"),
			"",
			"on:",
			"  pull_request:",
			"  push:",
			"  workflow_dispatch:",
			"",
			"permissions:",
			"  contents: read",
			"",
			"jobs:",
			"  verify-generated-output:",
			"    runs-on: ubuntu-24.04",
			"    timeout-minutes: 20",
			"    defaults:",
			"      run:",
			"        working-directory: " + yamlText(workingDirectory),
			"    steps:",
			"      - name: Check out immutable source",
			"        uses: " + CHECKOUT_ACTION + " # v7.0.0",
			"      - name: Install exact Node.js runtime",
			"        uses: " + SETUP_NODE_ACTION + " # v6.4.0",
			"        with:",
			"          node-version: 22.17.0",
			"          package-manager-cache: false",
			"      - name: Install Haxe 4.3.7",
			"        uses: " + SETUP_HAXE_ACTION + " # v2.1.0",
			"        with:",
			"          haxe-version: 4.3.7",
			"      - name: Verify exact npm",
			"        run: npm --version | grep -Fx 10.9.2",
			"      - name: Install exact project dependencies",
			"        run: npm ci --ignore-scripts --no-audit --no-fund",
			"      - name: Regenerate and compare committed output",
			"        run: ./node_modules/.bin/wphx generated-output check --project . --json",
			""
		].join("\n");
		return new GeneratedOutputWorkflow(path, content, Content.digest(content));
	}

	public function validate(repositoryRoot:String):Void {
		final bytes = ProjectFiles.read(repositoryRoot, path, "generated-output CI workflow", "generated-output-ci");
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0 || source != content || Content.digest(source) != sha256) {
			fail("generated-output CI workflow differs from its exact project projection", path);
		}
	}

	static function yamlText(value:String):String {
		return CanonicalJson.encode(ScaffoldJson.text(value));
	}

	static function fail<T>(message:String, relative:String):T {
		throw new CliFailure("WPHX3420", message, 5, "generated-output-ci", relative, [
			"Restore the exact generated workflow or remove the opt-in and rerun generated-output enable."
		]);
	}

	function new(path:String, content:String, sha256:String) {
		this.path = path;
		this.content = content;
		this.sha256 = sha256;
	}
}
