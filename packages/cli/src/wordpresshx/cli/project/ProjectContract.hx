package wordpresshx.cli.project;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;

/** Checked access to closed project JSON plus portable configuration invariants. **/
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

	public static function object(value:JsonValue, label:String):JsonValue {
		return switch value {
			case ObjectValue(_): value;
			case _: fail("WPHX1002", label + " must be an object", 3, "configuration");
		};
	}

	public static function exactFields(value:JsonValue, expected:Array<String>, label:String, stage:String = "configuration"):Void {
		final actual = fieldNames(value, label);
		actual.sort(ProjectJson.compareText);
		final wanted = expected.copy();
		wanted.sort(ProjectJson.compareText);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail("WPHX1003", label + " fields differ; expected " + wanted.join(", ") + ", found " + actual.join(", "), 3, stage);
		}
	}

	public static function has(value:JsonValue, name:String, label:String):Bool {
		return find(value, name, label) != null;
	}

	public static function field(value:JsonValue, name:String, label:String, stage:String = "configuration"):JsonValue {
		final child = find(value, name, label);
		return child == null ? fail("WPHX1003", label + "." + name + " is required", 3, stage) : child;
	}

	public static function string(value:JsonValue, name:String, label:String, stage:String = "configuration"):String {
		return switch field(value, name, label, stage) {
			case StringValue(child) if (child.length > 0): child;
			case _: fail("WPHX1003", label + "." + name + " must be a non-empty string", 3, stage);
		};
	}

	public static function optionalString(value:JsonValue, name:String, label:String, stage:String = "configuration"):Null<String> {
		final child = find(value, name, label);
		if (child == null) {
			return null;
		}
		return switch child {
			case StringValue(text): text;
			case _: fail("WPHX1003", label + "." + name + " must be a string", 3, stage);
		};
	}

	public static function boolean(value:JsonValue, name:String, label:String, stage:String = "configuration"):Bool {
		return switch field(value, name, label, stage) {
			case BoolValue(child): child;
			case _: fail("WPHX1003", label + "." + name + " must be a boolean", 3, stage);
		};
	}

	public static function integer(value:JsonValue, name:String, label:String, stage:String = "configuration"):Int {
		return switch field(value, name, label, stage) {
			case NumberValue(source):
				final child = Std.parseInt(source);
				if (child == null || Std.string(child) != source) {
					fail("WPHX1003", label + "." + name + " must be a supported integer", 3, stage);
				}
				child;
			case _: fail("WPHX1003", label + "." + name + " must be a safe integer", 3, stage);
		};
	}

	public static function array(value:JsonValue, name:String, label:String, stage:String = "configuration"):Array<JsonValue> {
		return switch field(value, name, label, stage) {
			case ArrayValue(children): children;
			case _: fail("WPHX1003", label + "." + name + " must be an array", 3, stage);
		};
	}

	public static inline function fieldObject(value:JsonValue, name:String, label:String, stage:String = "configuration"):JsonValue {
		return object(field(value, name, label, stage), label + "." + name);
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
		if (value == null || value.length == 0 || ProjectJson.nfc(value) != value || StringTools.startsWith(value, "/") || value.indexOf("\\") >= 0
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

	public static function sortedUniqueStrings(values:Array<JsonValue>, label:String, validator:(String, String) -> String):Array<String> {
		final result:Array<String> = [];
		var previous:Null<String> = null;
		for (index in 0...values.length) {
			final value = switch values[index] {
				case StringValue(text): text;
				case _: fail("WPHX1003", label + "[" + index + "] must be a string", 3, "configuration");
			};
			validator(value, label + "[" + index + "]");
			if (previous != null && ProjectJson.compareText(previous, value) >= 0) {
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

	public static function fail<T>(code:String, message:String, exitCode:Int, stage:String, ?path:String, ?remediations:Array<String>):T {
		throw new CliFailure(code, message, exitCode, stage, path, remediations);
	}

	static function fieldNames(value:JsonValue, label:String):Array<String> {
		return switch value {
			case ObjectValue(fields): [for (field in fields) field.name];
			case _: fail("WPHX1002", label + " must be an object", 3, "configuration");
		};
	}

	static function find(value:JsonValue, name:String, label:String):Null<JsonValue> {
		return switch value {
			case ObjectValue(fields): findIn(fields, name);
			case _: fail("WPHX1002", label + " must be an object", 3, "configuration");
		};
	}

	static function findIn(fields:Array<JsonField>, name:String):Null<JsonValue> {
		for (field in fields) {
			if (field.name == name) {
				return field.value;
			}
		}
		return null;
	}
}
