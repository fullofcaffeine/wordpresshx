package adoption.ownership;

import js.node.Buffer;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;
import wordpresshx.cli.ownership.OwnershipContract;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;

/** Trusted generator intent embedded in the owner before candidate bytes exist. */
final class ExpectedAdoptionStage {
	public final ownershipManifestSha256:String;
	public final ownershipManifestSizeBytes:Int;
	public final ownershipManifestDigest:String;
	public final files:Array<ExpectedAdoptionFile>;
	public final bundleDigest:String;
	public final provider:JsonValue;
	public final bundleMembers:JsonValue;
	public final contractBindings:JsonValue;
	public final capabilities:JsonValue;

	public static function parse(source:String, label:String):ExpectedAdoptionStage {
		final root = object(OwnershipJson.parseCanonical(Buffer.from(source, "utf8"), label), label);
		exact(root, [
			"bundleDigest",
			"bundleMembers",
			"capabilities",
			"contractBindings",
			"files",
			"ownershipManifest",
			"provider",
			"schema",
			"schemaVersion"
		], label);
		if (text(field(root, "schema"), label + ".schema") != "wordpress-hx.expected-adoption-stage.v1"
			|| integer(field(root, "schemaVersion"), label + ".schemaVersion") != 1) {
			fail(label + " schema identity differs");
		}
		final manifest = object(field(root, "ownershipManifest"), label + ".ownershipManifest");
		exact(manifest, ["manifestDigest", "sha256", "sizeBytes"], label + ".ownershipManifest");
		final files:Array<ExpectedAdoptionFile> = [];
		for (raw in array(field(root, "files"), label + ".files")) {
			final value = object(raw, label + ".file");
			exact(value, ["path", "sha256", "sizeBytes"], label + ".file");
			final relative = OwnershipContract.relative(text(field(value, "path"), label + ".file.path"), label + ".file.path");
			if (containsPath(files, relative)) {
				fail(label + " contains a duplicate file path");
			}
			files.push(new ExpectedAdoptionFile(relative, text(field(value, "sha256"), label + ".file.sha256"),
				integer(field(value, "sizeBytes"), label + ".file.sizeBytes")));
		}
		return new ExpectedAdoptionStage(text(field(manifest, "sha256"), label + ".ownershipManifest.sha256"),
			integer(field(manifest, "sizeBytes"), label + ".ownershipManifest.sizeBytes"),
			text(field(manifest, "manifestDigest"), label + ".ownershipManifest.manifestDigest"), files,
			text(field(root, "bundleDigest"), label + ".bundleDigest"), field(root, "provider"), field(root, "bundleMembers"),
			field(root, "contractBindings"), field(root, "capabilities"));
	}

	static function containsPath(files:Array<ExpectedAdoptionFile>, path:String):Bool {
		for (file in files) {
			if (file.path == path) {
				return true;
			}
		}
		return false;
	}

	function new(ownershipManifestSha256:String, ownershipManifestSizeBytes:Int, ownershipManifestDigest:String, files:Array<ExpectedAdoptionFile>,
			bundleDigest:String, provider:JsonValue, bundleMembers:JsonValue, contractBindings:JsonValue, capabilities:JsonValue) {
		this.ownershipManifestSha256 = ownershipManifestSha256;
		this.ownershipManifestSizeBytes = ownershipManifestSizeBytes;
		this.ownershipManifestDigest = ownershipManifestDigest;
		this.files = files;
		this.bundleDigest = bundleDigest;
		this.provider = provider;
		this.bundleMembers = bundleMembers;
		this.contractBindings = contractBindings;
		this.capabilities = capabilities;
	}

	static function object(value:JsonValue, label:String):Array<JsonField>
		return switch value {
			case ObjectValue(fields): fields;
			case _: fail(label + " must be an object");
		};

	static function array(value:JsonValue, label:String):Array<JsonValue>
		return switch value {
			case ArrayValue(values): values;
			case _: fail(label + " must be an array");
		};

	static function field(fields:Array<JsonField>, name:String):JsonValue {
		for (value in fields) {
			if (value.name == name) {
				return value.value;
			}
		}
		return fail("missing expected-stage field: " + name);
	}

	static function exact(fields:Array<JsonField>, expected:Array<String>, label:String):Void {
		final actual = [for (value in fields) value.name];
		actual.sort(compareText);
		final wanted = expected.copy();
		wanted.sort(compareText);
		if (actual.join("\x00") != wanted.join("\x00")) {
			fail(label + " has unexpected fields");
		}
	}

	static function text(value:JsonValue, label:String):String
		return switch value {
			case StringValue(source) if (source.length > 0): source;
			case _: fail(label + " must be non-empty text");
		};

	static function integer(value:JsonValue, label:String):Int
		return switch value {
			case NumberValue(source):
				if (!~/^(0|[1-9][0-9]*)$/.match(source)) {
					fail(label + " must be a non-negative integer");
				}
				final parsed = Std.parseInt(source);
				parsed == null ? fail(label + " must be a non-negative integer") : parsed;
			case _: fail(label + " must be an integer");
		};

	static function compareText(left:String, right:String):Int
		return left < right ? -1 : left > right ? 1 : 0;

	static function fail<T>(message:String):T
		throw new OwnershipFailure(message, "validator-failed");
}

final class ExpectedAdoptionFile {
	public final path:String;
	public final sha256:String;
	public final sizeBytes:Int;

	public function new(path:String, sha256:String, sizeBytes:Int) {
		this.path = path;
		this.sha256 = sha256;
		this.sizeBytes = sizeBytes;
	}
}
