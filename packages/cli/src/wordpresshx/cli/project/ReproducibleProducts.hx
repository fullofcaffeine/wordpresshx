package wordpresshx.cli.project;

import js.node.Buffer;

typedef ReproducibleProducts = {
	final report:Dynamic;
	final reportBytes:Buffer;
	final archiveBytes:Buffer;
	final archiveEntries:Array<String>;
}
