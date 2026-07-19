package wordpresshx.cli.generatedoutput;

import wordpresshx.cli.closedjson.JsonDocument;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Deterministic proof emitted by enable and clean-HEAD comparison. */
class GeneratedOutputReceipt {
	public static function create(operation:String, status:String, project:GeneratedOutputProject, policy:GeneratedOutputPolicy, git:GeneratedOutputGit,
			manifest:GeneratedOutputManifest, tree:GeneratedOutputTree, checkoutUnchanged:Bool):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.generated-output-vcs-result.v1")),
			ScaffoldJson.field("operation", ScaffoldJson.text(operation)),
			ScaffoldJson.field("status", ScaffoldJson.text(status)),
			ScaffoldJson.field("projectId", ScaffoldJson.text(project.projectId)),
			ScaffoldJson.field("policy", ScaffoldJson.object([
				ScaffoldJson.field("path", ScaffoldJson.text(GeneratedOutputPolicy.PATH)),
				ScaffoldJson.field("sha256", ScaffoldJson.text(policy.policyDigest))
			])),
			ScaffoldJson.field("source", ScaffoldJson.object([
				ScaffoldJson.field("commit", ScaffoldJson.text(git.head)),
				ScaffoldJson.field("fingerprint", ScaffoldJson.text(manifest.sourceFingerprint))
			])),
			ScaffoldJson.field("generator", ScaffoldJson.object([
				ScaffoldJson.field("id", ScaffoldJson.text(manifest.generatorId)),
				ScaffoldJson.field("toolchainSha256", ScaffoldJson.text(manifest.toolchainDigest))
			])),
			ScaffoldJson.field("profile", ScaffoldJson.object([
				ScaffoldJson.field("id", ScaffoldJson.text(manifest.profileId)),
				ScaffoldJson.field("catalogRevision", ScaffoldJson.text(manifest.catalogRevision)),
				ScaffoldJson.field("catalogSha256", ScaffoldJson.text(manifest.catalogSha256))
			])),
			ScaffoldJson.field("manifest", ScaffoldJson.object([
				ScaffoldJson.field("path", ScaffoldJson.text(manifest.path)),
				ScaffoldJson.field("sha256", ScaffoldJson.text(manifest.manifestDigest))
			])),
			ScaffoldJson.field("continuousIntegration", ScaffoldJson.object([
				ScaffoldJson.field("provider", ScaffoldJson.text("github-actions")),
				ScaffoldJson.field("path", ScaffoldJson.text(policy.workflowPath)),
				ScaffoldJson.field("sha256", ScaffoldJson.text(policy.workflowSha256)),
				ScaffoldJson.field("command", ScaffoldJson.array([
					ScaffoldJson.text("./node_modules/.bin/wphx"),
					ScaffoldJson.text("generated-output"),
					ScaffoldJson.text("check"),
					ScaffoldJson.text("--project"),
					ScaffoldJson.text("."),
					ScaffoldJson.text("--json")
				]))
			])),
			ScaffoldJson.field("roots",
				ScaffoldJson.array([
					for (root in policy.roots)
						rootResult(root, tree)
				])),
			ScaffoldJson.field("comparison", ScaffoldJson.text("exact-path-size-sha256-and-bytes")),
			ScaffoldJson.field("checkoutUnchanged", ScaffoldJson.boolean(checkoutUnchanged)),
			ScaffoldJson.field("releaseRegenerationRequired", ScaffoldJson.boolean(true))
		]);
	}

	public static function document(value:JsonValue):String {
		return JsonDocument.encode(value);
	}

	static function rootResult(root:GeneratedOutputRoot, tree:GeneratedOutputTree):JsonValue {
		final files = tree.filesBelow(root.path);
		return ScaffoldJson.object([
			ScaffoldJson.field("id", ScaffoldJson.text(root.id)),
			ScaffoldJson.field("path", ScaffoldJson.text(root.path)),
			ScaffoldJson.field("fileCount", ScaffoldJson.number(files.length)),
			ScaffoldJson.field("treeSha256", ScaffoldJson.text(GeneratedOutputTree.digestFiles(files)))
		]);
	}
}
