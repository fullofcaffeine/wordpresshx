package wordpresshx.cli.project;

import wordpresshx.cli.closedjson.JsonValue;

typedef PreparedGeneration = {
	final paths:ProjectOwnershipPaths;
	final artifacts:Array<PreparedArtifact>;
	final packagePayloads:Array<ReproduciblePayload>;
	final manifest:JsonValue;
}
