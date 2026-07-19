package wordpresshx.cli.scaffold;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldKind;
import wordpresshx.cli.scaffold.ScaffoldRequest.ScaffoldMode;

/** Closed parser for project-creation mutations. */
class ScaffoldArguments {
	static final KNOWN_UNAVAILABLE = ["island", "mu-plugin", "block", "block-collection", "theme", "solution"];

	public static function parse(arguments:Array<String>):ScaffoldRequest {
		if (arguments.length == 0) {
			return usage("a scaffold command is required");
		}
		final command = arguments[0];
		if (command != "new" && command != "init") {
			return usage("unsupported scaffold command: " + command);
		}
		var profile = "wp70-release";
		var projectPath:Null<String> = null;
		var profileSeen = false;
		var dryRun = false;
		var json = false;
		final positionals:Array<String> = [];
		var index = 1;
		while (index < arguments.length) {
			final argument = arguments[index];
			switch argument {
				case "--dry-run":
					if (dryRun) {
						return usage("--dry-run may be supplied only once");
					}
					dryRun = true;
					index++;
				case "--json":
					if (json) {
						return usage("--json may be supplied only once");
					}
					json = true;
					index++;
				case "--profile", "--project":
					if (index + 1 >= arguments.length) {
						return usage("missing value for " + argument);
					}
					final value = arguments[index + 1];
					if (argument == "--profile") {
						if (profileSeen) {
							return usage("--profile may be supplied only once");
						}
						profileSeen = true;
						profile = ScaffoldIdentity.profile(value);
					} else {
						if (projectPath != null || value.length == 0) {
							return usage("--project requires one directory");
						}
						projectPath = value;
					}
					index += 2;
				case _ if (StringTools.startsWith(argument, "--")):
					return usage("unknown option: " + argument);
				case _:
					positionals.push(argument);
					index++;
			}
		}
		ScaffoldIdentity.profile(profile);
		if (command == "new") {
			if (positionals.length != 2) {
				return usage("new requires a kind and project name");
			}
			final kind = positionals[0];
			final scaffoldKind = switch kind {
				case "site": Site;
				case "plugin": Plugin;
				case _: null;
			};
			if (scaffoldKind == null) {
				if (KNOWN_UNAVAILABLE.indexOf(kind) >= 0) {
					throw new CliFailure("WPHX3002", "new " + kind + " is unavailable until its native producer passes the real consumer path", 2,
						"scaffold-plan", null, [
							"Use new site or new plugin for a proven project foundation, or wait for the named target producer."
						]);
				}
				return usage("unknown scaffold kind: " + kind);
			}
			return new ScaffoldRequest(NewProject, scaffoldKind, ScaffoldIdentity.projectId(positionals[1]), profile, projectPath, dryRun, json);
		}
		if (positionals.length > 1) {
			return usage("init accepts at most one project name");
		}
		final requested = positionals.length == 0 ? null : ScaffoldIdentity.projectId(positionals[0]);
		return new ScaffoldRequest(ExistingProject, Site, requested, profile, projectPath, dryRun, json);
	}

	static function usage<T>(message:String):T {
		throw new CliFailure("WPHX3001", message, 2, "scaffold-plan", null, [
			"Use: wphx new <site|plugin> <name> [--profile wp70-release] [--project <parent>] [--dry-run] [--json], or wphx init [name]."
		]);
	}
}
