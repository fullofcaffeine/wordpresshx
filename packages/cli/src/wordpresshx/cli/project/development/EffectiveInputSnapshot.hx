package wordpresshx.cli.project.development;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonReader.JsonReadError;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.project.ProjectContext;

/** Typed projection of the legacy effective-input boundary used by the watcher. */
class EffectiveInputSnapshot {
	public final fingerprint:String;
	public final compilerCompatibilityDigest:String;
	public final files:Map<String, String>;

	public static function from(context:ProjectContext):EffectiveInputSnapshot {
		try {
			final root = JsonReader.from(JsonParser.parse(OwnershipJson.encode(context.effectiveInputs)), "effective inputs", "WPHX2301");
			root.exact([
				"canonicalization",
				"compileServer",
				"discoveryRoots",
				"environment",
				"files",
				"fingerprint",
				"fingerprintAlgorithm",
				"ignoredRoots",
				"profile",
				"project",
				"schema",
				"toolchain",
				"watchRoots"
			], "WPHX2301");
			final compiler = root.object("compileServer", "WPHX2301");
			compiler.exact([
				"compatibilityComponents",
				"compatibilityDigest",
				"compatibilityDigestAlgorithm",
				"directBuildDefault",
				"policy",
				"restartFileRoles"
			], "WPHX2301");
			final files:Map<String, String> = [];
			var previous:Null<String> = null;
			for (value in root.array("files", "WPHX2301")) {
				final file = JsonReader.from(value, "effective input file", "WPHX2301");
				file.exact(["byteLength", "path", "role", "sha256", "targets"], "WPHX2301");
				final path = file.string("path", "WPHX2301");
				if (previous != null && compareText(previous, path) >= 0) {
					invalid("effective input files must be sorted and unique");
				}
				previous = path;
				files.set(path, file.string("sha256", "WPHX2301"));
			}
			return new EffectiveInputSnapshot(root.string("fingerprint", "WPHX2301"), compiler.string("compatibilityDigest", "WPHX2301"), files);
		} catch (error:JsonParseError) {
			return invalid(error.message);
		} catch (error:JsonReadError) {
			return invalid(error.message);
		}
	}

	function new(fingerprint:String, compilerCompatibilityDigest:String, files:Map<String, String>) {
		this.fingerprint = fingerprint;
		this.compilerCompatibilityDigest = compilerCompatibilityDigest;
		this.files = files;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX2301", "could not create a typed effective-input snapshot: " + message, 7, "watching", null, [
			"Run wphx doctor and regenerate the project lock before restarting the development loop."
		]);
	}
}
