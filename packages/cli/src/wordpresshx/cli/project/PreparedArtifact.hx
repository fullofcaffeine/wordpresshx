package wordpresshx.cli.project;

import js.node.Buffer;

typedef PreparedArtifact = {
	final path:String;
	final rootId:String;
	final bytes:Buffer;
	final kind:String;
	final projectionIds:Array<String>;
	final validatorIds:Array<String>;
}
