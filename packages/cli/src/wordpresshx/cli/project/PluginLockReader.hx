package wordpresshx.cli.project;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonParser;
import wordpresshx.cli.closedjson.JsonParser.JsonParseError;
import wordpresshx.cli.closedjson.JsonReader;
import wordpresshx.cli.closedjson.JsonReader.JsonReadError;

/** Convert the authenticated project lock to the plugin producer's closed view. */
class PluginLockReader {
	public static function read(context:ProjectContext):PluginLockIdentity {
		try {
			final root = JsonReader.from(JsonParser.parse(context.lockBytes.toString("utf8")), "project lock", "WPHX3305");
			final generatedBy = root.object("generatedBy", "WPHX3305");
			final profile = root.object("profile", "WPHX3305");
			var sdkLockEntry:Null<String> = null;
			for (value in root.array("components", "WPHX3305")) {
				final component = JsonReader.from(value, "project lock component", "WPHX3305");
				if (component.string("id", "WPHX3305") == "sdk.wordpress-hx") {
					sdkLockEntry = component.string("lockEntrySha256", "WPHX3305");
				}
			}
			if (sdkLockEntry == null) {
				return invalid("project lock is missing sdk.wordpress-hx");
			}
			return new PluginLockIdentity(root.string("lockDigest", "WPHX3305"), sdkLockEntry, generatedBy.string("sdkVersion", "WPHX3305"),
				generatedBy.string("cliVersion", "WPHX3305"), profile.string("catalogRevision", "WPHX3305"), profile.string("catalogSha256", "WPHX3305"));
		} catch (error:JsonParseError) {
			return invalid("project lock is malformed: " + error.message);
		} catch (error:JsonReadError) {
			return invalid(error.message);
		}
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX3305", message, 3, "profile-resolution", ".wphx/project.lock.json",
			["Restore the exact project lock before emitting a native plugin."]);
	}
}
