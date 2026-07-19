package wordpresshx.cli.project;

import wordpresshx.cli.ownership.OwnershipJson;

/** Deterministically place global ownership metadata inside one declared root. **/
class OwnershipPaths {
	public static function resolve(bootstrap:ProjectBootstrap):ProjectOwnershipPaths {
		final roots = bootstrap.outputRoots.copy();
		roots.sort((left, right) -> {
			final byPath = Reflect.compare(left.path, right.path);
			return byPath == 0 ? Reflect.compare(left.id, right.id) : byPath;
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

	public static function manifestRoots(bootstrap:ProjectBootstrap, paths:ProjectOwnershipPaths):Array<Dynamic> {
		final roots:Array<Dynamic> = [
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
			final leftKey = Reflect.field(left, "path") + "\x00" + Reflect.field(left, "rootId");
			final rightKey = Reflect.field(right, "path") + "\x00" + Reflect.field(right, "rootId");
			return Reflect.compare(leftKey, rightKey);
		});
		return roots;
	}

	public static function isAdditiveRootSet(current:Array<Dynamic>, expected:Array<Dynamic>):Bool {
		if (expected.length <= current.length) {
			return false;
		}
		final expectedById = new Map<String, Dynamic>();
		for (root in expected) {
			expectedById.set(cast Reflect.field(root, "rootId"), root);
		}
		for (root in current) {
			final candidate = expectedById.get(cast Reflect.field(root, "rootId"));
			if (candidate == null || OwnershipJson.encode(root) != OwnershipJson.encode(candidate)) {
				return false;
			}
		}
		return true;
	}
}
