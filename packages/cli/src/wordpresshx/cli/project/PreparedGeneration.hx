package wordpresshx.cli.project;

typedef PreparedGeneration = {
	final paths:ProjectOwnershipPaths;
	final artifacts:Array<PreparedArtifact>;
	final packagePayloads:Array<ReproduciblePayload>;
	final manifest:Dynamic;
}
