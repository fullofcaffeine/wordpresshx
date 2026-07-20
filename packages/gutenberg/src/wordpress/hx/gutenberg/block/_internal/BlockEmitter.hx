package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.build._internal.JsonValue.JsonField;
import wordpress.hx.gutenberg.block._internal.BlockInputs.digestBytes;
import wordpress.hx.gutenberg.block._internal.BlockInputs.fail;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockContextProvider;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockDraft;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockSession;
import wordpress.hx.gutenberg.block._internal.BlockModel.OwnedAsset;

private typedef EmittedBlock = {
	final name:String;
	final metadataPath:String;
	final metadataSha256:String;
	final registrationPath:String;
	final registrationSha256:String;
	final isDynamic:Bool;
}

/** Native block.json and registration-parity projection. */
class BlockEmitter {
	public static function emit(session:BlockSession):Void {
		final seenNames:Map<String, Bool> = [];
		final usedAssets:Map<String, Bool> = [];
		final emitted:Array<EmittedBlock> = [];
		final drafts = session.drafts.copy();
		drafts.sort((left, right) -> compareText(left.name, right.name));
		for (draft in drafts) {
			if (seenNames.exists(draft.name)) {
				fail("WPX6031", "duplicate block declaration " + draft.name, draft.position);
			}
			seenNames.set(draft.name, true);
			for (asset in draft.assets) {
				if (usedAssets.exists(asset.id)) {
					fail("WPX6031", "owned block asset is consumed more than once: " + asset.id, draft.position);
				}
				usedAssets.set(asset.id, true);
			}
			emitted.push(emitBlock(session, draft));
		}
		if (emitted.length == 0) {
			fail("WPX6031", "block metadata compilation declared no blocks", Context.currentPos());
		}
		for (assetId in session.assets.keys()) {
			if (!usedAssets.exists(assetId)) {
				fail("WPX6032", "owned block asset manifest entry is unused: " + assetId, Context.currentPos());
			}
		}
		emitManifest(session, emitted);
	}

	static function emitBlock(session:BlockSession, draft:BlockDraft):EmittedBlock {
		final slug = draft.name.substr(draft.name.indexOf("/") + 1);
		final blockRoot = Path.join([session.outputRoot, "blocks", slug]);
		if (!FileSystem.exists(blockRoot)) {
			FileSystem.createDirectory(blockRoot);
		}
		final metadataPath = "blocks/" + slug + "/block.json";
		final registrationPath = "blocks/" + slug + "/registration-plan.json";
		final physicalMetadata = Path.join([session.outputRoot, metadataPath]);
		final physicalRegistration = Path.join([session.outputRoot, registrationPath]);
		for (path in [physicalMetadata, physicalRegistration]) {
			if (FileSystem.exists(path)) {
				fail("WPX6033", "block compiler refuses to overwrite staged output " + path, draft.position);
			}
		}

		final metadataContent = BlockJson.encode(metadata(session, draft)) + "\n";
		File.saveContent(physicalMetadata, metadataContent);
		final metadataSha256 = digestBytes(Bytes.ofString(metadataContent));
		final isDynamic = [for (asset in draft.assets) asset.metadataKey].contains("render");
		final registrationContent = BlockJson.encode(registration(session, draft, metadataPath, metadataSha256, isDynamic)) + "\n";
		File.saveContent(physicalRegistration, registrationContent);
		return {
			name: draft.name,
			metadataPath: metadataPath,
			metadataSha256: metadataSha256,
			registrationPath: registrationPath,
			registrationSha256: digestBytes(Bytes.ofString(registrationContent)),
			isDynamic: isDynamic
		};
	}

	static function metadata(session:BlockSession, draft:BlockDraft):JsonValue {
		final fields:Array<JsonField> = [
			field("$schema", StringValue(session.profile.schemaUrl)),
			field("apiVersion", NumberValue(Std.string(session.profile.apiVersion))),
			field("name", StringValue(draft.name)),
			field("title", StringValue(draft.title)),
			field("category", StringValue(draft.category)),
			field("textdomain", StringValue(draft.textdomain)),
			field("attributes", BlockSchema.value(draft.attributes))
		];
		optionalString(fields, "description", draft.description);
		optionalString(fields, "icon", draft.icon);
		optionalString(fields, "version", draft.version);
		optionalStrings(fields, "keywords", draft.keywords);
		optionalStrings(fields, "parent", draft.parent);
		optionalStrings(fields, "ancestor", draft.ancestor);
		optionalStrings(fields, "allowedBlocks", draft.allowedBlocks);
		optionalStrings(fields, "usesContext", draft.usesContext);
		if (draft.providesContext.length > 0) {
			fields.push(field("providesContext", contextObject(draft.providesContext)));
		}
		if (draft.supports != null) {
			fields.push(field("supports", draft.supports));
		}
		for (assetField in assetFields(draft.assets)) {
			fields.push(assetField);
		}
		for (entry in fields) {
			if (!session.profile.allowedMetadata.exists(entry.name) && entry.name != "$schema") {
				fail("WPX6034", "emitter produced metadata key outside wp70-release: " + entry.name, draft.position);
			}
		}
		return ObjectValue(fields);
	}

	static function contextObject(contexts:Array<BlockContextProvider>):JsonValue {
		return ObjectValue([for (context in contexts) field(context.name, StringValue(context.attribute))]);
	}

	static function assetFields(assets:Array<OwnedAsset>):Array<JsonField> {
		final grouped:Map<String, Array<String>> = [];
		for (asset in assets) {
			if (!grouped.exists(asset.metadataKey)) {
				grouped.set(asset.metadataKey, []);
			}
			grouped.get(asset.metadataKey).push(asset.reference);
		}
		final result:Array<JsonField> = [];
		for (metadataKey in grouped.keys()) {
			final values = grouped.get(metadataKey);
			result.push(field(metadataKey, values.length == 1 ? StringValue(values[0]) : ArrayValue([for (value in values) StringValue(value)])));
		}
		return result;
	}

	static function registration(session:BlockSession, draft:BlockDraft, metadataPath:String, metadataSha256:String, isDynamic:Bool):JsonValue {
		final identity = [
			field("blockName", StringValue(draft.name)),
			field("metadataPath", StringValue(metadataPath)),
			field("metadataSha256", StringValue(metadataSha256))
		];
		return ObjectValue([
			field("schemaVersion", NumberValue("1")),
			field("profileId", StringValue(session.profile.profileId)),
			field("kind", StringValue(isDynamic ? "dynamic" : "static")),
			field("client", ObjectValue(identity.concat([
				field("api", StringValue("registerBlockType")),
				field("capabilityId", StringValue("gutenberg.export.@wordpress/blocks.registerBlockType"))
			]))),
			field("server", ObjectValue(identity.concat([
				field("api", StringValue("register_block_type")),
				field("capabilityId", StringValue("wordpress.php.function.register_block_type"))
			])))
		]);
	}

	static function emitManifest(session:BlockSession, blocks:Array<EmittedBlock>):Void {
		final path = Path.join([session.outputRoot, "block-generation-manifest.json"]);
		if (FileSystem.exists(path)) {
			fail("WPX6033", "block compiler refuses to overwrite staged output " + path, Context.currentPos());
		}
		final value = ObjectValue([
			field("schemaVersion", NumberValue("1")),
			field("profileId", StringValue(session.profile.profileId)),
			field("catalogRevision", StringValue(session.profile.catalogRevision)),
			field("blockSchemaSha256", StringValue(session.profile.schemaSha256)),
			field("generator", StringValue("wordpresshx-sdk060-block-metadata-v1")),
			field("blocks", ArrayValue([
				for (block in blocks)
					ObjectValue([
						field("name", StringValue(block.name)),
						field("kind", StringValue(block.isDynamic ? "dynamic" : "static")),
						field("metadataPath", StringValue(block.metadataPath)),
						field("metadataSha256", StringValue(block.metadataSha256)),
						field("registrationPath", StringValue(block.registrationPath)),
						field("registrationSha256", StringValue(block.registrationSha256))
					])
			]))
		]);
		File.saveContent(path, BlockJson.encode(value) + "\n");
	}

	static function optionalString(fields:Array<JsonField>, name:String, value:Null<String>):Void {
		if (value != null) {
			fields.push(field(name, StringValue(value)));
		}
	}

	static function optionalStrings(fields:Array<JsonField>, name:String, values:Array<String>):Void {
		if (values.length > 0) {
			fields.push(field(name, ArrayValue([for (value in values) StringValue(value)])));
		}
	}

	static function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
#end
