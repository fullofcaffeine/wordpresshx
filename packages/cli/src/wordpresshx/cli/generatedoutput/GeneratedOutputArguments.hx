package wordpresshx.cli.generatedoutput;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.generatedoutput.GeneratedOutputRequest.GeneratedOutputOperation;
import wordpresshx.cli.project.ProjectContract;

/** Closed parser for deliberate generated-output VCS operations. */
class GeneratedOutputArguments {
	public static function parse(arguments:Array<String>):GeneratedOutputRequest {
		if (arguments.length < 2 || arguments[0] != "generated-output") {
			return usage("generated-output requires enable or check");
		}
		final operation = switch arguments[1] {
			case "enable": Enable;
			case "check": Check;
			case value: return usage("unknown generated-output operation: " + value);
		};
		final roots:Array<String> = [];
		var projectPath:Null<String> = null;
		var dryRun = false;
		var json = false;
		var index = 2;
		while (index < arguments.length) {
			final option = arguments[index];
			switch option {
				case "--json":
					if (json) {
						return usage("--json may be supplied only once");
					}
					json = true;
					index++;
				case "--dry-run":
					if (dryRun) {
						return usage("--dry-run may be supplied only once");
					}
					dryRun = true;
					index++;
				case "--project", "--root":
					if (index + 1 >= arguments.length) {
						return usage("missing value for " + option);
					}
					final value = arguments[index + 1];
					if (option == "--project") {
						if (projectPath != null || value.length == 0) {
							return usage("--project requires one directory");
						}
						projectPath = value;
					} else {
						ProjectContract.stableId(value, "generated-output root ID", "command");
						if (roots.indexOf(value) >= 0) {
							return usage("duplicate --root ID: " + value);
						}
						roots.push(value);
					}
					index += 2;
				case _:
					return usage("unknown generated-output option: " + option);
			}
		}
		roots.sort(compareText);
		if (operation == Enable && roots.length == 0) {
			return usage("generated-output enable requires at least one explicit --root ID");
		}
		if (operation == Check && roots.length != 0) {
			return usage("generated-output check reads roots from the committed policy");
		}
		if (operation == Check && dryRun) {
			return usage("generated-output check is already read-only");
		}
		return new GeneratedOutputRequest(operation, roots, projectPath, dryRun, json);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function usage<T>(message:String):T {
		throw new CliFailure("WPHX3400", message, 2, "generated-output-command", null, [
			"Use: wphx generated-output enable --root <id> [--root <id>...] [--project <path>] [--dry-run] [--json], or wphx generated-output check [--project <path>] [--json]."
		]);
	}
}
