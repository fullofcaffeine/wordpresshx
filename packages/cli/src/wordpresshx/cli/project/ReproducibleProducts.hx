package wordpresshx.cli.project;

import js.node.Buffer;
import wordpresshx.cli.closedjson.JsonValue;

typedef ReproducibleProducts = {
	final report:JsonValue;
	final reportBytes:Buffer;
	final archiveBytes:Buffer;
	final archiveEntries:Array<String>;
}
