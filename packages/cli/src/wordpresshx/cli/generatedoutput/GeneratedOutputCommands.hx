package wordpresshx.cli.generatedoutput;

import js.node.Buffer;
import js.node.Fs;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.generatedoutput.GeneratedOutputRequest.GeneratedOutputOperation;
import wordpresshx.cli.project.ProjectFiles;
import wordpresshx.cli.scaffold.ScaffoldFile;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldFileAction;
import wordpresshx.cli.scaffold.ScaffoldFile.ScaffoldOwnership;
import wordpresshx.cli.scaffold.ScaffoldPublisher;

/** Deliberate policy enablement and clean-HEAD regeneration comparison. */
class GeneratedOutputCommands {
	public static function run(arguments:Array<String>):Int {
		final request = GeneratedOutputArguments.parse(arguments);
		final start = request.projectPath == null ? NodeGlobals.process().cwd() : request.projectPath;
		final project = GeneratedOutputProject.load(start);
		return switch request.operation {
			case Enable: enable(project, request);
			case Check: check(project, request);
		};
	}

	static function enable(project:GeneratedOutputProject, request:GeneratedOutputRequest):Int {
		final roots = project.select(request.rootIds);
		final git = GeneratedOutputGit.open(project);
		git.requireClean();
		git.validateAuthorityTracked(project);
		final workflow = GeneratedOutputWorkflow.create(project.projectId, git.projectPrefix);
		final policy = GeneratedOutputPolicy.create(project.projectId, roots, workflow);
		if (Fs.existsSync(Path.join(project.context.bootstrap.root, GeneratedOutputPolicy.PATH))) {
			final existing = GeneratedOutputPolicy.parse(ProjectFiles.read(project.context.bootstrap.root, GeneratedOutputPolicy.PATH,
				"generated-output policy", "generated-output-policy"));
			project.validatePolicy(existing);
			if (!existing.sameSelection(project.projectId, roots)
				|| !existing.sameWorkflow(workflow)
				|| existing.policyDigest != policy.policyDigest) {
				throw new CliFailure("WPHX3419", "existing generated-output policy differs from the requested roots", 5, "generated-output-policy",
					GeneratedOutputPolicy.PATH, ["Review and remove the old policy before selecting a different exact root set."]);
			}
			GeneratedOutputIgnore.validate(readText(project.context.bootstrap.root, ".gitignore"), roots);
			workflow.validate(git.repositoryRoot);
			final manifest = GeneratedOutputManifest.inspect(project, roots, false);
			final tree = GeneratedOutputTree.scan(project.context.bootstrap.root, roots);
			emit(request.json, GeneratedOutputReceipt.create("enable", "already-enabled", project, existing, git, manifest, tree, true));
			return 0;
		}

		final beforeIgnore = readText(project.context.bootstrap.root, ".gitignore");
		final afterIgnore = GeneratedOutputIgnore.enable(beforeIgnore, roots);
		if (request.dryRun) {
			final proof = buildPlanInClone(git, roots);
			git.requireClean();
			emit(request.json, GeneratedOutputReceipt.create("enable", "planned", project, policy, git, proof.manifest, proof.tree, true));
			return 0;
		}

		GeneratedOutputProcess.build(project.context.bootstrap.root, true);
		git.requireClean();
		final manifest = GeneratedOutputManifest.inspect(project, roots, true);
		final tree = GeneratedOutputTree.scan(project.context.bootstrap.root, roots);
		final files = [
			new ScaffoldFile(git.projectRepositoryPath(GeneratedOutputPolicy.PATH), policy.document(), CliOwned, Create),
			new ScaffoldFile(git.projectRepositoryPath(".gitignore"), afterIgnore, Authored, UpdateMarker(Content.digest(beforeIgnore))),
			new ScaffoldFile(workflow.path, workflow.content, CliOwned, Create)
		];
		ScaffoldPublisher.publishFiles(git.repositoryRoot, files);
		emit(request.json, GeneratedOutputReceipt.create("enable", "enabled", project, policy, git, manifest, tree, false));
		return 0;
	}

	static function buildPlanInClone(git:GeneratedOutputGit, roots:Array<GeneratedOutputRoot>):GeneratedOutputProof {
		final clone = git.cloneAtHead();
		try {
			GeneratedOutputProcess.build(clone.projectRoot, true);
			final freshProject = GeneratedOutputProject.load(clone.projectRoot);
			final proof = new GeneratedOutputProof(GeneratedOutputManifest.inspect(freshProject, roots, true),
				GeneratedOutputTree.scan(clone.projectRoot, roots));
			clone.dispose();
			return proof;
		} catch (failure:haxe.Exception) {
			clone.dispose();
			throw failure;
		}
	}

	static function check(project:GeneratedOutputProject, request:GeneratedOutputRequest):Int {
		final policy = GeneratedOutputPolicy.parse(ProjectFiles.read(project.context.bootstrap.root, GeneratedOutputPolicy.PATH, "generated-output policy",
			"generated-output-policy"));
		project.validatePolicy(policy);
		final git = GeneratedOutputGit.open(project);
		final workflow = GeneratedOutputWorkflow.create(project.projectId, git.projectPrefix);
		if (!policy.sameWorkflow(workflow)) {
			throw new CliFailure("WPHX3420", "generated-output CI workflow identity differs from the project policy", 5, "generated-output-ci",
				policy.workflowPath);
		}
		workflow.validate(git.repositoryRoot);
		GeneratedOutputIgnore.validate(readText(project.context.bootstrap.root, ".gitignore"), policy.roots);
		git.requireClean();
		git.validateAuthorityTracked(project);
		final manifest = GeneratedOutputManifest.inspect(project, policy.roots, false);
		final expected = GeneratedOutputTree.scan(project.context.bootstrap.root, policy.roots);
		git.validateCommittedProjection(project, policy, expected);

		final clone = git.cloneAtHead();
		try {
			GeneratedOutputTree.removeSelectedRoots(clone.projectRoot, policy.roots);
			GeneratedOutputProcess.build(clone.projectRoot, true);
			final freshProject = GeneratedOutputProject.load(clone.projectRoot);
			freshProject.validatePolicy(policy);
			GeneratedOutputManifest.inspect(freshProject, policy.roots, true);
			final actual = GeneratedOutputTree.scan(clone.projectRoot, policy.roots);
			GeneratedOutputTree.compare(expected, actual);
		} catch (failure:haxe.Exception) {
			clone.dispose();
			throw failure;
		}
		clone.dispose();
		git.requireClean();
		emit(request.json, GeneratedOutputReceipt.create("check", "passed", project, policy, git, manifest, expected, true));
		return 0;
	}

	static function readText(root:String, relative:String):String {
		final bytes = ProjectFiles.read(root, relative, "generated-output policy input", "generated-output-policy");
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			throw new CliFailure("WPHX3419", "generated-output policy input must be valid UTF-8", 5, "generated-output-policy", relative);
		}
		return source;
	}

	static function emit(json:Bool, value:wordpresshx.cli.closedjson.JsonValue):Void {
		if (json) {
			NodeGlobals.process().stdout.write(GeneratedOutputReceipt.document(value));
			return;
		}
		final reader = wordpresshx.cli.closedjson.JsonReader.from(value, "generated-output result", "WPHX3419");
		NodeGlobals.process().stdout.write("Generated output " + reader.string("status", "WPHX3419") + ".\n");
	}
}

private class GeneratedOutputProof {
	public final manifest:GeneratedOutputManifest;
	public final tree:GeneratedOutputTree;

	public function new(manifest:GeneratedOutputManifest, tree:GeneratedOutputTree) {
		this.manifest = manifest;
		this.tree = tree;
	}
}
