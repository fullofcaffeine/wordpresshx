package wordpresshx.cli;

import wordpresshx.cli.project.ProjectContract;

/** Small closed parser: command first, options in any subsequent position. **/
class CliArguments {
	static final COMMANDS = ["build", "check", "inspect", "clean", "doctor", "dev"];

	public static function parse(arguments:Array<String>):CliInvocation {
		if (arguments.length == 0) {
			usage("a command is required");
		}
		final command = arguments[0];
		if (COMMANDS.indexOf(command) < 0) {
			usage("unknown command: " + command);
		}
		var projectPath:Null<String> = null;
		var profile:Null<String> = null;
		var json = false;
		var dryRun = false;
		var services:Null<String> = null;
		final positionals:Array<String> = [];
		var index = 1;
		while (index < arguments.length) {
			final option = arguments[index];
			switch (option) {
				case "--json":
					if (json) {
						usage("--json may be supplied only once");
					}
					json = true;
					index++;
				case "--dry-run":
					if (dryRun) {
						usage("--dry-run may be supplied only once");
					}
					dryRun = true;
					index++;
				case "--project", "--profile", "--services":
					if (index + 1 >= arguments.length) {
						usage("missing value for " + option);
					}
					final value = arguments[index + 1];
					switch (option) {
						case "--project":
							if (projectPath != null) {
								usage("--project may be supplied only once");
							}
							projectPath = value;
						case "--profile":
							if (profile != null || !ProjectContract.STABLE_ID.match(value)) {
								usage("--profile requires one stable profile ID");
							}
							profile = value;
						case "--services":
							if (services != null || value != "none") {
								usage("--services currently accepts only none");
							}
							services = value;
						case _:
					}
					index += 2;
				case _ if (StringTools.startsWith(option, "--services=")):
					final value = option.substr("--services=".length);
					if (services != null || value != "none") {
						usage("--services currently accepts only none");
					}
					services = value;
					index++;
				case _ if (StringTools.startsWith(option, "--")):
					usage("unknown option: " + option);
				case _:
					positionals.push(option);
					index++;
			}
		}
		if (dryRun && command != "build") {
			usage("--dry-run is supported by build; check and doctor are already read-only");
		}
		if (services != null && command != "dev") {
			usage("--services is supported only by dev");
		}
		if (command != "inspect" && positionals.length != 0) {
			usage(command + " does not accept positional arguments");
		}
		return new CliInvocation(command, projectPath, profile, json, dryRun, services, positionals);
	}

	static function usage(message:String):Dynamic {
		throw new CliFailure("WPHX0001", message, 2, "command", null, [
			"Use: wphx <build|check|inspect|clean|doctor|dev> [--project <path>] [--profile <id>] [--json]."
		]);
	}
}
