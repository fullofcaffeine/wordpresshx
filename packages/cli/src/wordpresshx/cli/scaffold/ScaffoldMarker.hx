package wordpresshx.cli.scaffold;

import wordpresshx.cli.CliFailure;

/** Exact marker ownership for bounded edits to hand-owned text files. */
class ScaffoldMarker {
	public static inline final BEGIN = "# BEGIN wordpress-hx managed ignores";
	public static inline final END = "# END wordpress-hx managed ignores";

	public static function block():Array<String> {
		return [
			BEGIN,
			"/.wphx/runtime/",
			"/.wphx/transactions/",
			"/build/*",
			"/dist/",
			"/node_modules/",
			END
		];
	}

	public static function newDocument():String {
		return block().join("\n") + "\n";
	}

	public static function replace(source:String):String {
		if (source.indexOf("\r") >= 0 || !StringTools.endsWith(source, "\n")) {
			return fail("existing .gitignore must use LF lines and one final LF before marker replacement");
		}
		final lines = source.substr(0, source.length - 1).split("\n");
		final begins:Array<Int> = [];
		final ends:Array<Int> = [];
		for (index in 0...lines.length) {
			if (lines[index] == BEGIN) {
				begins.push(index);
			}
			if (lines[index] == END) {
				ends.push(index);
			}
		}
		if (begins.length != 1 || ends.length != 1 || begins[0] >= ends[0]) {
			return fail("existing .gitignore must contain exactly one ordered WordPressHx marker pair");
		}
		return lines.slice(0, begins[0])
			.concat(block())
			.concat(lines.slice(ends[0] + 1))
			.join("\n") + "\n";
	}

	static function fail<T>(message:String):T {
		throw new CliFailure("WPHX3005", message, 5, "scaffold-preflight", ".gitignore", [
			"Add exactly one empty " + BEGIN + " / " + END + " pair, then review the dry-run before retrying."
		]);
	}
}
