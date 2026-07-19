package wordpresshx.cli.scaffold;

import wordpresshx.cli.CliFailure;

class ScaffoldIdentity {
	static final SLUG = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
	static final RESERVED = [
		"abstract",
		"break",
		"case",
		"ca" + "st",
		"catch",
		"class",
		"continue",
		"default",
		"do",
		"dynamic",
		"else",
		"enum",
		"extern",
		"extends",
		"false",
		"final",
		"for",
		"from",
		"function",
		"if",
		"implements",
		"import",
		"in",
		"inline",
		"interface",
		"macro",
		"new",
		"null",
		"operator",
		"overload",
		"override",
		"package",
		"private",
		"public",
		"return",
		"static",
		"super",
		"switch",
		"this",
		"throw",
		"to",
		"true",
		"try",
		"typedef",
		"un" + "typed",
		"using",
		"var",
		"while"
	];

	public static function projectId(value:String):String {
		if (value.length > 64 || !SLUG.match(value)) {
			throw new CliFailure("WPHX3003", "project name must be a lowercase hyphenated slug of at most 64 characters", 2, "scaffold-plan", null,
				["Use a name such as acme-observatory."]);
		}
		return value;
	}

	public static function profile(value:String):String {
		if (value != "wp70-release") {
			throw new CliFailure("WPHX3004", "site scaffolding currently supports only the exact wp70-release profile", 2, "scaffold-plan", null, [
				"Use --profile wp70-release; other profiles need their own complete consumer evidence."
			]);
		}
		return value;
	}

	public static function packageName(projectId:String):String {
		return [for (segment in projectId.split("-")) packageSegment(segment)].join(".");
	}

	public static function entryPoint(projectId:String):String {
		return packageName(projectId) + ".Site";
	}

	public static function displayName(projectId:String):String {
		return [
			for (segment in projectId.split("-"))
				segment.charAt(0).toUpperCase() + segment.substr(1)
		].join(" ");
	}

	static function packageSegment(value:String):String {
		final safeStart = value.charAt(0) >= "0" && value.charAt(0) <= "9" ? "p_" + value : value;
		return RESERVED.indexOf(safeStart) >= 0 ? safeStart + "_site" : safeStart;
	}
}
