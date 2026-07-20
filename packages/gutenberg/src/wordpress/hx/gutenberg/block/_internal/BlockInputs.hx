package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.Exception;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr.Position;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.build._internal.JsonObjectReader;
import wordpress.hx.build._internal.JsonObjectReader.JsonReadError;
import wordpress.hx.build._internal.JsonParser;
import wordpress.hx.build._internal.JsonParser.JsonParseError;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.gutenberg.block._internal.BlockModel.AssetReferenceKind;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockProfile;
import wordpress.hx.gutenberg.block._internal.BlockModel.OwnedAsset;

/** Closed exact-profile and owned-asset inputs for the block compiler. */
class BlockInputs {
	static final SHA256 = ~/^[0-9a-f]{64}$/;
	static final BLOCK_NAME = ~/^[a-z][a-z0-9-]*\/[a-z][a-z0-9-]*$/;
	static final STABLE_ID = ~/^[a-z][a-z0-9]*(?:[._:\/-][a-z0-9]+)*$/;
	static final HANDLE = ~/^[a-z0-9]+(?:-[a-z0-9]+)*$/;

	public static function profile(path:String, position:Position):BlockProfile {
		final reader = object(read(path, "WPX6001", "block profile", position), "block profile", "WPX6001", position);
		try {
			reader.exact([
				"schemaVersion",
				"profileId",
				"catalogRevision",
				"source",
				"policy",
				"allowedMetadataKeys",
				"forbiddenMetadataKeys",
				"allowedSupportsKeys",
				"assetKeys",
				"allowedHandles"
			], "WPX6001");
			if (reader.integer("schemaVersion", "WPX6001") != 1) {
				fail("WPX6001", "block profile schemaVersion must be 1", position);
			}
			final profileId = reader.string("profileId", "WPX6001");
			if (profileId != "wp70-release") {
				fail("WPX6002", "SDK-060 admits only the exact wp70-release block profile", position);
			}
			final source = reader.object("source", "WPX6001");
			source.exact(["repository", "commit", "tree", "path", "blob", "sha256", "schemaUrl"], "WPX6001");
			if (source.string("repository", "WPX6001") != "https://github.com/WordPress/gutenberg.git"
				|| source.string("commit", "WPX6001") != "a2a354cf35e5b69c3330d6c1cfd42d8dc2efb9fd"
				|| source.string("tree", "WPX6001") != "8bd91d6b490d79ef991d388409705b5cd06fdc94"
				|| source.string("path", "WPX6001") != "schemas/json/block.json"
				|| source.string("blob", "WPX6001") != "246cb4ed9d2e07da32c80c24d1201c72a420cb54") {
				fail("WPX6003", "block profile source identity drifted from the WordPress 7.0 embedded Gutenberg schema", position);
			}
			final schemaSha256 = source.string("sha256", "WPX6001");
			if (!SHA256.match(schemaSha256)) {
				fail("WPX6003", "block profile source digest is invalid", position);
			}
			final policy = reader.object("policy", "WPX6001");
			policy.exact([
				"apiVersion",
				"additionalProperties",
				"experimentalMetadata",
				"scriptModules",
				"manualBlockJsonEditing"
			], "WPX6001");
			if (policy.integer("apiVersion", "WPX6001") != 3
				|| policy.boolean("additionalProperties", "WPX6001")
				|| policy.boolean("experimentalMetadata", "WPX6001")
				|| policy.boolean("scriptModules", "WPX6001")
				|| policy.boolean("manualBlockJsonEditing", "WPX6001")) {
				fail("WPX6004", "wp70-release block policy must remain API v3, closed, stable, and generator-owned", position);
			}

			final allowedMetadata = stringSet(reader.strings("allowedMetadataKeys", "WPX6001"), "metadata key", position);
			for (required in ["apiVersion", "name", "title", "attributes", "supports"]) {
				if (!allowedMetadata.exists(required)) {
					fail("WPX6004", "block profile omitted required capability " + required, position);
				}
			}
			final forbiddenMetadata:Map<String, String> = [];
			for (value in reader.array("forbiddenMetadataKeys", "WPX6001")) {
				final entry = object(value, "forbidden metadata key", "WPX6001", position);
				entry.exact(["key", "reason"], "WPX6001");
				final key = entry.string("key", "WPX6001");
				if (forbiddenMetadata.exists(key)) {
					fail("WPX6004", "duplicate forbidden metadata key " + key, position);
				}
				forbiddenMetadata.set(key, entry.string("reason", "WPX6001"));
			}
			final allowedSupports = stringSet(reader.strings("allowedSupportsKeys", "WPX6001"), "supports key", position);

			final allowedAssetKeys:Map<String, String> = [];
			for (value in reader.array("assetKeys", "WPX6001")) {
				final entry = object(value, "asset key", "WPX6001", position);
				entry.exact(["key", "kind"], "WPX6001");
				final key = entry.string("key", "WPX6001");
				final kind = entry.string("kind", "WPX6001");
				if (!allowedMetadata.exists(key) || allowedAssetKeys.exists(key) || !["script", "style", "render"].contains(kind)) {
					fail("WPX6004", "invalid block asset key " + key, position);
				}
				allowedAssetKeys.set(key, kind);
			}

			final allowedHandles:Map<String, String> = [];
			for (value in reader.array("allowedHandles", "WPX6001")) {
				final entry = object(value, "allowed handle", "WPX6001", position);
				entry.exact(["reference", "capabilityId"], "WPX6001");
				final reference = entry.string("reference", "WPX6001");
				final capabilityId = entry.string("capabilityId", "WPX6001");
				if (!HANDLE.match(reference) || allowedHandles.exists(reference) || !STABLE_ID.match(capabilityId)) {
					fail("WPX6004", "invalid or duplicate profile-owned handle " + reference, position);
				}
				allowedHandles.set(reference, capabilityId);
			}

			return {
				profileId: profileId,
				catalogRevision: reader.string("catalogRevision", "WPX6001"),
				schemaUrl: source.string("schemaUrl", "WPX6001"),
				schemaSha256: schemaSha256,
				apiVersion: 3,
				allowedMetadata: allowedMetadata,
				forbiddenMetadata: forbiddenMetadata,
				allowedSupports: allowedSupports,
				allowedAssetKeys: allowedAssetKeys,
				allowedHandles: allowedHandles
			};
		} catch (error:JsonReadError) {
			return fail(error.code, error.message, position);
		}
	}

	public static function assets(path:String, outputRoot:String, profile:BlockProfile, position:Position):Map<String, OwnedAsset> {
		final reader = object(read(path, "WPX6005", "block asset manifest", position), "block asset manifest", "WPX6005", position);
		try {
			reader.exact(["schemaVersion", "profileId", "artifacts"], "WPX6005");
			if (reader.integer("schemaVersion", "WPX6005") != 1 || reader.string("profileId", "WPX6005") != profile.profileId) {
				fail("WPX6005", "block asset manifest profile identity is invalid", position);
			}
			final result:Map<String, OwnedAsset> = [];
			for (value in reader.array("artifacts", "WPX6005")) {
				final entry = object(value, "block asset", "WPX6005", position);
				entry.exact([
					"id",
					"blockName",
					"metadataKey",
					"kind",
					"referenceKind",
					"reference",
					"path",
					"owner",
					"capabilityId",
					"sha256"
				], "WPX6005");
				final id = entry.string("id", "WPX6005");
				final blockName = entry.string("blockName", "WPX6005");
				final metadataKey = entry.string("metadataKey", "WPX6005");
				final kind = entry.string("kind", "WPX6005");
				final reference = entry.string("reference", "WPX6005");
				final artifactPath = entry.string("path", "WPX6005");
				final owner = entry.string("owner", "WPX6005");
				final capabilityId = entry.string("capabilityId", "WPX6005");
				final expectedSha256 = entry.string("sha256", "WPX6005");
				if (!STABLE_ID.match(id) || result.exists(id) || !BLOCK_NAME.match(blockName)) {
					fail("WPX6006", "block asset identity is invalid or duplicated: " + id, position);
				}
				if (!profile.allowedAssetKeys.exists(metadataKey) || profile.allowedAssetKeys.get(metadataKey) != kind) {
					fail("WPX6006", "block asset " + id + " contradicts profile metadata key " + metadataKey, position);
				}
				if (!STABLE_ID.match(owner) || !SHA256.match(expectedSha256)) {
					fail("WPX6006", "block asset " + id + " has invalid ownership evidence", position);
				}
				final referenceKind = switch entry.string("referenceKind", "WPX6005") {
					case "file":
						validateFileAsset(id, blockName, reference, artifactPath, capabilityId, expectedSha256, outputRoot, position);
						FileReference;
					case "handle":
						validateHandleAsset(id, reference, artifactPath, capabilityId, expectedSha256, owner, profile, position);
						HandleReference;
					case other:
						fail("WPX6006", "block asset " + id + " has unknown reference kind " + other, position);
				};
				result.set(id, {
					id: id,
					blockName: blockName,
					metadataKey: metadataKey,
					kind: kind,
					referenceKind: referenceKind,
					reference: reference,
					path: artifactPath,
					owner: owner,
					capabilityId: capabilityId,
					sha256: expectedSha256
				});
			}
			return result;
		} catch (error:JsonReadError) {
			return fail(error.code, error.message, position);
		}
	}

	static function validateFileAsset(id:String, blockName:String, reference:String, artifactPath:String, capabilityId:String, expectedSha256:String,
			outputRoot:String, position:Position):Void {
		if (capabilityId != "" || !StringTools.startsWith(reference, "file:./")) {
			fail("WPX6007", "file asset " + id + " must use a relative file: reference and no provider capability", position);
		}
		final relativeReference = reference.substr("file:./".length);
		final slug = blockName.substr(blockName.indexOf("/") + 1);
		final expectedPath = "blocks/" + slug + "/" + relativeReference;
		if (artifactPath != expectedPath || !safeRelativePath(artifactPath)) {
			fail("WPX6007", "file asset " + id + " does not resolve to its block-owned final path", position);
		}
		final physical = Path.join([outputRoot, artifactPath]);
		if (!FileSystem.exists(physical) || FileSystem.isDirectory(physical) || digestBytes(File.getBytes(physical)) != expectedSha256) {
			fail("WPX6007", "file asset " + id + " is absent or differs from its owned final artifact", position);
		}
	}

	static function validateHandleAsset(id:String, reference:String, artifactPath:String, capabilityId:String, expectedSha256:String, owner:String,
			profile:BlockProfile, position:Position):Void {
		if (artifactPath != ""
			|| !HANDLE.match(reference)
			|| !profile.allowedHandles.exists(reference)
			|| profile.allowedHandles.get(reference) != capabilityId) {
			fail("WPX6008", "handle asset " + id + " is not owned by the selected profile", position);
		}
		final identity = owner + "\n" + capabilityId + "\n" + reference;
		if (digestBytes(Bytes.ofString(identity)) != expectedSha256) {
			fail("WPX6008", "handle asset " + id + " ownership digest does not match", position);
		}
	}

	static function stringSet(values:Array<String>, label:String, position:Position):Map<String, Bool> {
		final result:Map<String, Bool> = [];
		for (value in values) {
			if (value == "" || result.exists(value)) {
				fail("WPX6004", "invalid or duplicate " + label + " " + value, position);
			}
			result.set(value, true);
		}
		return result;
	}

	static function read(path:String, code:String, label:String, position:Position):JsonValue {
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) {
			return fail(code, label + " is absent: " + path, position);
		}
		try {
			return JsonParser.parse(File.getContent(path));
		} catch (error:JsonParseError) {
			return fail(code, label + " is invalid JSON: " + error.message, position);
		} catch (error:Exception) {
			return fail(code, label + " could not be read: " + error.message, position);
		}
	}

	static function object(value:JsonValue, label:String, code:String, position:Position):JsonObjectReader {
		try {
			return JsonObjectReader.from(value, label, code);
		} catch (error:JsonReadError) {
			return fail(error.code, error.message, position);
		}
	}

	static function safeRelativePath(path:String):Bool {
		if (path == "" || Path.isAbsolute(path) || path.indexOf("\\") >= 0) {
			return false;
		}
		final parts = path.split("/");
		return !parts.contains("") && !parts.contains(".") && !parts.contains("..");
	}

	public static function digestBytes(bytes:Bytes):String {
		return Sha256.make(bytes).toHex();
	}

	public static function fail<T>(code:String, message:String, position:Position):T {
		Context.error(code + ": " + message, position);
		throw "unreachable";
	}
}
#end
