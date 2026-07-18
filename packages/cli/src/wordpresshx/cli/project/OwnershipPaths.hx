package wordpresshx.cli.project;

/** Deterministically place global ownership metadata inside one declared root. **/
class OwnershipPaths {
	public static function resolve(bootstrap:ProjectBootstrap):ProjectOwnershipPaths {
		final roots = bootstrap.outputRoots.copy();
		roots.sort((left, right) -> {
			final byPath = Reflect.compare(left.path, right.path);
			return byPath == 0 ? Reflect.compare(left.id, right.id) : byPath;
		});
		final metadataRoot = roots[0];
		return {
			layout: {
				manifestPath: metadataRoot.path + "/_GeneratedFiles.json",
				transactionRoot: metadataRoot.path + "/.wphx-transactions"
			},
			metadataPath: metadataRoot.path + "/.wphx/effective-inputs.json",
			metadataRootId: metadataRoot.id
		};
	}
}
