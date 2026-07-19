package wordpresshx.cli.generatedoutput;

import js.node.Buffer;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.closedjson.JsonDocument;
import wordpresshx.cli.closedjson.JsonReader;

/** Exact identities needed to authenticate generated-manifest provenance. */
class GeneratedOutputLockIdentity {
	public final lockDigest:String;
	public final sdkVersion:String;
	public final cliVersion:String;
	public final sdkLockEntrySha256:String;
	public final profileId:String;
	public final catalogRevision:String;
	public final catalogSha256:String;

	public static function read(bytes:Buffer):GeneratedOutputLockIdentity {
		try {
			final root = JsonReader.from(JsonDocument.parseCanonical(bytes, "project lock", "WPHX3415"), "project lock", "WPHX3415");
			final generatedBy = root.object("generatedBy", "WPHX3415");
			generatedBy.exact(["sdkVersion", "cliVersion"], "WPHX3415");
			final profile = root.object("profile", "WPHX3415");
			profile.exact(["id", "catalogRevision", "catalogSha256"], "WPHX3415");
			var sdkEntry:Null<String> = null;
			final components = root.array("components", "WPHX3415");
			for (index in 0...components.length) {
				final component = JsonReader.from(components[index], "project lock.components[" + index + "]", "WPHX3415");
				component.exact(["id", "role", "version", "source", "identity", "lockEntrySha256"], "WPHX3415");
				if (component.string("id", "WPHX3415") == "sdk.wordpress-hx") {
					sdkEntry = component.string("lockEntrySha256", "WPHX3415");
				}
			}
			if (sdkEntry == null) {
				throw new CliFailure("WPHX3415", "project lock lacks the WordPressHx SDK generator identity", 5, "generated-output-provenance");
			}
			return new GeneratedOutputLockIdentity(root.string("lockDigest", "WPHX3415"), generatedBy.string("sdkVersion", "WPHX3415"),
				generatedBy.string("cliVersion", "WPHX3415"), sdkEntry, profile.string("id", "WPHX3415"), profile.string("catalogRevision", "WPHX3415"),
				profile.string("catalogSha256", "WPHX3415"));
		} catch (failure:CliFailure) {
			throw failure;
		} catch (failure:haxe.Exception) {
			throw new CliFailure("WPHX3415", failure.message, 5, "generated-output-provenance", ".wphx/project.lock.json",
				["Restore the exact project lock and regenerate with its matching CLI."], failure);
		}
	}

	function new(lockDigest:String, sdkVersion:String, cliVersion:String, sdkLockEntrySha256:String, profileId:String, catalogRevision:String,
			catalogSha256:String) {
		this.lockDigest = lockDigest;
		this.sdkVersion = sdkVersion;
		this.cliVersion = cliVersion;
		this.sdkLockEntrySha256 = sdkLockEntrySha256;
		this.profileId = profileId;
		this.catalogRevision = catalogRevision;
		this.catalogSha256 = catalogSha256;
	}
}
