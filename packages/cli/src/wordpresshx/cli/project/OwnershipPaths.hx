package wordpresshx.cli.project;

import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;

/** Deterministically place global ownership metadata inside one declared root. **/
class OwnershipPaths {
	public static function resolve(bootstrap:ProjectBootstrap):ProjectOwnershipPaths {
		final roots = bootstrap.outputRoots.copy();
		roots.sort((left, right) -> {
			final byPath = ProjectJson.compareText(left.path, right.path);
			return byPath == 0 ? ProjectJson.compareText(left.id, right.id) : byPath;
		});
		final metadataRoot = roots[0];
		final usedIds = new Map<String, Bool>();
		for (root in roots) {
			usedIds.set(root.id, true);
		}
		var distributionRootId = "wphx.distribution";
		var suffix = 2;
		while (usedIds.exists(distributionRootId)) {
			distributionRootId = "wphx.distribution-" + suffix;
			suffix++;
		}
		return {
			layout: {
				manifestPath: metadataRoot.path + "/_GeneratedFiles.json",
				transactionRoot: metadataRoot.path + "/.wphx-transactions"
			},
			metadataPath: metadataRoot.path + "/.wphx/effective-inputs.json",
			metadataRootId: metadataRoot.id,
			distributionRootId: distributionRootId,
			reproducibilityPath: bootstrap.distributionRoot + "/wordpress-hx-build.json",
			archivePath: bootstrap.distributionRoot + "/wordpress-hx.zip"
		};
	}

	public static function manifestRoots(bootstrap:ProjectBootstrap, paths:ProjectOwnershipPaths):Array<JsonValue> {
		final roots:Array<JsonValue> = [
			for (root in bootstrap.outputRoots)
				OwnershipJson.object([
					"rootId" => root.id,
					"path" => root.path,
					"ownershipMode" => "exact-file-manifest-coexists-with-unowned"
				])
		];
		roots.push(OwnershipJson.object([
			"rootId" => paths.distributionRootId,
			"path" => bootstrap.distributionRoot,
			"ownershipMode" => "exact-file-manifest-coexists-with-unowned"
		]));
		roots.sort((left, right) -> {
			final leftKey = ProjectContract.string(left, "path", "ownership root") + "\x00" + ProjectContract.string(left, "rootId", "ownership root");
			final rightKey = ProjectContract.string(right, "path", "ownership root") + "\x00" + ProjectContract.string(right, "rootId", "ownership root");
			return ProjectJson.compareText(leftKey, rightKey);
		});
		return roots;
	}
}
