package wordpresshx.cli.project;

import js.Syntax;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;

typedef DoctorResult = {
	final report:JsonValue;
	final passed:Bool;
	final status:String;
	final checks:Array<DoctorCheck>;
}

typedef DoctorCheck = {
	final id:String;
	final actual:String;
	final status:String;
	final remediation:String;
	final json:JsonValue;
}

/** Read-only exact-pin and ownership diagnosis; it never installs or recovers. **/
class Doctor {
	static final LIX_CLI_BY_PACKAGE:Map<String, String> = ["15.12.4" => "15.12.2"];

	public static function inspect(context:ProjectContext):DoctorResult {
		final checks:Array<DoctorCheck> = [];
		var passed = true;
		final components = new Map<String, JsonValue>();
		for (component in ProjectContract.array(context.lock, "components", "project lock", "profile-resolution")) {
			components.set(ProjectContract.string(component, "id", "project lock component", "profile-resolution"), component);
		}

		final nodeExpected = version(components, "runtime.node");
		final nodeActual:String = Syntax.code("process.versions.node");
		passed = add(checks, "runtime.node", nodeExpected, nodeActual, "Use the exact project-local Node runtime selected by the lock.")
			&& passed;
		final haxeExpected = version(components, "compiler.haxe");
		final haxeActual = CompilerRunner.version("haxe");
		passed = add(checks, "compiler.haxe", haxeExpected, haxeActual, "Restore the project-local Haxe 4.3.7/Lix scope.") && passed;
		final npmExpected = version(components, "tool.npm");
		final npmActual = CompilerRunner.version("npm");
		passed = add(checks, "tool.npm", npmExpected, npmActual, "Invoke wphx through the exact project-local Node/npm toolchain.")
			&& passed;
		final lixPackage = version(components, "tool.lix");
		final lixExpected = LIX_CLI_BY_PACKAGE.get(lixPackage);
		final lixActual = CompilerRunner.version("lix");
		if (lixExpected == null) {
			checks.push(check("tool.lix", "known CLI mapping for package " + lixPackage, lixActual, "failed",
				"Upgrade the CLI adapter before accepting a different Lix package version."));
			passed = false;
		} else {
			passed = add(checks, "tool.lix-cli", lixExpected, lixActual, "Restore Lix package "
				+ lixPackage
				+ " (reported CLI "
				+ lixExpected
				+ ").")
				&& passed;
		}

		try {
			final manifest = OwnershipPreflight.inspect(context);
			checks.push(check("ownership.current", "exact manifest-owned bytes",
				manifest == null ? "no published generation" : "manifest " + manifest.manifestDigest, "passed", "No action required."));
		} catch (failure:CliFailure) {
			checks.push(check("ownership.current", "exact manifest-owned bytes", failure.code + ": " + failure.message, "failed",
				failure.remediations.length == 0 ? "Diagnose the ownership manifest." : failure.remediations[0]));
			passed = false;
		}
		checks.sort((left, right) -> ProjectJson.compareText(left.id, right.id));
		final status = passed ? "passed" : "failed";
		final report = OwnershipJson.object([
			"schema" => "wordpress-hx.doctor.v1",
			"projectId" => ProjectContract.string(context.bootstrap.config, "projectId", "project configuration"),
			"profile" => context.profileId(),
			"fingerprint" => context.fingerprint(),
			"status" => status,
			"checks" => [for (check in checks) check.json]
		]);
		return {
			report: report,
			passed: passed,
			status: status,
			checks: checks
		};
	}

	static function version(components:Map<String, JsonValue>, id:String):String {
		final component = components.get(id);
		if (component == null) {
			throw new CliFailure("WPHX1014", "project lock is missing component " + id, 3, "profile-resolution");
		}
		return ProjectContract.string(component, "version", "project lock component", "profile-resolution");
	}

	static function add(checks:Array<DoctorCheck>, id:String, expected:String, actual:Null<String>, remediation:String):Bool {
		final ok = actual == expected;
		checks.push(check(id, expected, actual == null ? "not found" : actual, ok ? "passed" : "failed", ok ? "No action required." : remediation));
		return ok;
	}

	static function check(id:String, expected:String, actual:String, status:String, remediation:String):DoctorCheck {
		return {
			id: id,
			actual: actual,
			status: status,
			remediation: remediation,
			json: OwnershipJson.object([
				"id" => id,
				"expected" => expected,
				"actual" => actual,
				"status" => status,
				"remediation" => remediation
			])
		};
	}
}
