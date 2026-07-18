package wordpresshx.cli.project;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Closed bootstrap/lock helpers which never include absolute paths in errors. **/
class ProjectContract {
	public static final STABLE_ID = new EReg("^[a-z][a-z0-9]*(?:[._:/-][a-z0-9]+)*$", "");
	public static final HAXE_TYPE = new EReg("^(?:[a-z][A-Za-z0-9_]*\\.)+[A-Z][A-Za-z0-9_]*$", "");
	public static final ENVIRONMENT_NAME = new EReg("^[A-Z][A-Z0-9_]*$", "");
	public static final EXACT_VERSION = new EReg("^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$", "");
	public static final SHA256 = new EReg("^[0-9a-f]{64}$", "");
	static final PORTABLE_SEGMENT = new EReg("^[A-Za-z0-9._@+-]+$", "");
	static final WINDOWS_RESERVED = [
		"con", "prn", "aux", "nul", "clock$", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5",
		"lpt6", "lpt7", "lpt8", "lpt9"
	];

	public static function object(value:Dynamic, label:String):Dynamic {
		if (value == null || !Reflect.isObject(value) || Std.isOfType(value, Array) || Std.isOfType(value, String)) {
			fail("WPHX1002", label + " must be an object", 3, "configuration");
		}
		return value;
	}

	public static function exactFields(value:Dynamic, expected:Array<String>, label:String, stage:String = "configuration"):Void {
		object(value, label);
		final actual = Reflect.fields(value);
		actual.sort(Reflect.compare);
		final wanted = expected.copy();
		wanted.sort(Reflect.compare);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail("WPHX1003", label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "), 3, stage);
		}
	}

	public static function string(value:Dynamic, field:String, label:String, stage:String = "configuration"):String {
		final child = Reflect.field(object(value, label), field);
		if (!Std.isOfType(child, String) || child.length == 0) {
			fail("WPHX1003", label + "." + field + " must be a non-empty string", 3, stage);
		}
		return cast child;
	}

	public static function boolean(value:Dynamic, field:String, label:String, stage:String = "configuration"):Bool {
		final child = Reflect.field(object(value, label), field);
		if (!Std.isOfType(child, Bool)) {
			fail("WPHX1003", label + "." + field + " must be a boolean", 3, stage);
		}
		return cast child;
	}

	public static function integer(value:Dynamic, field:String, label:String, stage:String = "configuration"):Int {
		final child = Reflect.field(object(value, label), field);
		if (!OwnershipJson.isSafeInteger(child)) {
			fail("WPHX1003", label + "." + field + " must be a safe integer", 3, stage);
		}
		return cast child;
	}

	public static function array(value:Dynamic, field:String, label:String, stage:String = "configuration"):Array<Dynamic> {
		final child = Reflect.field(object(value, label), field);
		if (!Std.isOfType(child, Array)) {
			fail("WPHX1003", label + "." + field + " must be an array", 3, stage);
		}
		return cast child;
	}

	public static function fieldObject(value:Dynamic, field:String, label:String):Dynamic {
		return object(Reflect.field(object(value, label), field), label + "." + field);
	}

	public static function expect(value:String, expected:String, label:String, stage:String = "configuration"):Void {
		if (value != expected) {
			fail("WPHX1004", label + " must equal " + expected + ", found " + value, 3, stage);
		}
	}

	public static function stableId(value:String, label:String, stage:String = "configuration"):String {
		if (!STABLE_ID.match(value)) {
			fail("WPHX1003", label + " is not a stable ID", 3, stage);
		}
		return value;
	}

	public static function sha256(value:String, label:String, stage:String = "profile-resolution"):String {
		if (!SHA256.match(value)) {
			fail("WPHX1012", label + " is not a lowercase SHA-256", 3, stage);
		}
		return value;
	}

	public static function exactVersion(value:String, label:String, stage:String = "profile-resolution"):String {
		if (!EXACT_VERSION.match(value)) {
			fail("WPHX1013", label + " must be an exact semantic version", 3, stage);
		}
		return value;
	}

	public static function relativePath(value:String, label:String):String {
		if (value == null || value.length == 0 || OwnershipJson.nfc(value) != value || StringTools.startsWith(value, "/") || value.indexOf("\\") >= 0
			|| value.indexOf("\x00") >= 0) {
			fail("WPHX1005", label + " must be an NFC project-relative POSIX path", 3, "configuration", value);
		}
		for (segment in value.split("/")) {
			final stem = segment.split(".")[0].toLowerCase();
			if (segment.length == 0 || segment == "." || segment == ".." || !PORTABLE_SEGMENT.match(segment) || StringTools.endsWith(segment, ".")
				|| StringTools.endsWith(segment, " ") || WINDOWS_RESERVED.indexOf(stem) >= 0) {
				fail("WPHX1005", label + " is outside the portable path policy", 3, "configuration", value);
			}
		}
		return value;
	}

	public static function sortedUniqueStrings(values:Array<Dynamic>, label:String, validator:(String, String) -> String):Array<String> {
		final result:Array<String> = [];
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			if (!Std.isOfType(values[index], String)) {
				fail("WPHX1003", label + "[" + index + "] must be a string", 3, "configuration");
			}
			final value:String = cast values[index];
			validator(value, label + "[" + index + "]");
			if (previous != null && Reflect.compare(previous, value) >= 0) {
				fail("WPHX1006", label + " must be a sorted unique set", 3, "configuration");
			}
			previous = value;
			result.push(value);
		}
		return result;
	}

	public static function nested(parent:String, candidate:String):Bool {
		final parentParts = parent.split("/");
		final candidateParts = candidate.split("/");
		if (parentParts.length >= candidateParts.length) {
			return false;
		}
		for (index in 0...parentParts.length) {
			if (parentParts[index] != candidateParts[index]) {
				return false;
			}
		}
		return true;
	}

	public static function fail(code:String, message:String, exitCode:Int, stage:String, ?path:String, ?remediations:Array<String>):Dynamic {
		throw new CliFailure(code, message, exitCode, stage, path, remediations);
	}
}
