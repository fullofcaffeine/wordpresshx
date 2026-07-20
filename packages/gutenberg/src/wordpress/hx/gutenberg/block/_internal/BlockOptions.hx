package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.TypeTools;
import wordpress.hx.build._internal.JsonValue;
import wordpress.hx.build._internal.JsonValue.JsonField;
import wordpress.hx.gutenberg.block._internal.BlockInputs.fail;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockAttribute;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockContextProvider;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockDraft;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockSession;
import wordpress.hx.gutenberg.block._internal.BlockModel.OwnedAsset;

/** Parses the closed ergonomic Haxe authoring object into a typed block draft. */
class BlockOptions {
	static final BLOCK_NAME = ~/^[a-z][a-z0-9-]*\/[a-z][a-z0-9-]*$/;
	static final SLUG = ~/^[a-z][a-z0-9-]*$/;
	static final SEMVER = ~/^[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[0-9A-Za-z.-]+)?$/;
	static final ATTRIBUTE_NAME = ~/^[A-Za-z][A-Za-z0-9]*$/;
	static final AUTHORING_FIELDS = [
		"name",
		"title",
		"apiVersion",
		"category",
		"description",
		"icon",
		"keywords",
		"version",
		"textdomain",
		"parent",
		"ancestor",
		"allowedBlocks",
		"usesContext",
		"providesContext",
		"supports",
		"assets"
	];
	static final BOOLEAN_SUPPORTS = [
		"anchor",
		"alignWide",
		"allowedBlocks",
		"className",
		"customClassName",
		"customCSS",
		"html",
		"inserter",
		"renaming",
		"visibility",
		"multiple",
		"reusable",
		"lock",
		"contentRole",
		"listView",
		"splitting"
	];
	static final NESTED_SUPPORTS:Map<String, Array<String>> = [
		"color" => [
			"background",
			"gradients",
			"link",
			"text",
			"heading",
			"button",
			"enableContrastChecker"
		],
		"dimensions" => ["aspectRatio", "height", "minHeight", "width"],
		"filter" => ["duotone"],
		"spacing" => ["background", "blockGap", "margin", "padding"],
		"typography" => [
			"fontSize",
			"lineHeight",
			"textAlign",
			"textColumns",
			"textDecoration",
			"textIndent",
			"textTransform",
			"writingMode",
			"fitText"
		]
	];

	public static function parse(session:BlockSession, attributes:Array<BlockAttribute>, options:Expr):BlockDraft {
		final fields = objectFields(options);
		for (name in fields.keys()) {
			if (!AUTHORING_FIELDS.contains(name)) {
				if (session.profile.forbiddenMetadata.exists(name)) {
					fail("WPX6021", "metadata key " + name + " is forbidden by wp70-release: " + session.profile.forbiddenMetadata.get(name),
						fields.get(name).pos);
				}
				fail("WPX6020", "unknown block declaration key " + name, fields.get(name).pos);
			}
		}
		for (required in ["name", "title", "category", "assets"]) {
			if (!fields.exists(required)) {
				fail("WPX6022", "block declaration is missing required field " + required, options.pos);
			}
		}
		final name = literalString(fields.get("name"), "WPX6023", "block name");
		if (!BLOCK_NAME.match(name)) {
			fail("WPX6023", "block name must use namespace/slug lowercase syntax", fields.get("name").pos);
		}
		final title = printableText(fields.get("title"), "WPX6024", "block title");
		if (fields.exists("apiVersion")
			&& literalInteger(fields.get("apiVersion"), "WPX6025", "apiVersion") != session.profile.apiVersion) {
			fail("WPX6025", "wp70-release block apiVersion must be " + session.profile.apiVersion, fields.get("apiVersion").pos);
		}
		final category = categoryValue(fields.get("category"));
		final description = fields.exists("description") ? printableText(fields.get("description"), "WPX6024", "block description") : null;
		final icon = fields.exists("icon") ? literalString(fields.get("icon"), "WPX6024", "block icon") : null;
		if (icon != null && !SLUG.match(icon)) {
			fail("WPX6024", "block icon must be a Dashicon-style slug", fields.get("icon").pos);
		}
		final keywords = fields.exists("keywords") ? stringArray(fields.get("keywords"), "WPX6024", "block keywords") : [];
		final version = fields.exists("version") ? literalString(fields.get("version"), "WPX6024", "block version") : null;
		if (version != null && !SEMVER.match(version)) {
			fail("WPX6024", "block version must be semantic version text", fields.get("version").pos);
		}
		final namespace = name.substr(0, name.indexOf("/"));
		final textdomain = fields.exists("textdomain") ? literalString(fields.get("textdomain"), "WPX6024", "block textdomain") : namespace;
		if (!SLUG.match(textdomain)) {
			fail("WPX6024", "block textdomain must be a lowercase slug", fields.exists("textdomain") ? fields.get("textdomain").pos : fields.get("name").pos);
		}

		final parent = optionalBlockNames(fields, "parent");
		final ancestor = optionalBlockNames(fields, "ancestor");
		final allowedBlocks = optionalBlockNames(fields, "allowedBlocks");
		final usesContext = fields.exists("usesContext") ? contextNames(fields.get("usesContext"), "usesContext") : [];
		final providesContext = fields.exists("providesContext") ? contextProviders(fields.get("providesContext"), attributes) : [];
		final supports = fields.exists("supports") ? supportsValue(session, fields.get("supports")) : null;
		final assets = assetValues(session, name, fields.get("assets"));
		if (![for (asset in assets) asset.metadataKey].contains("editorScript")) {
			fail("WPX6026", "every SDK-060 block needs an owned editorScript so client registration can be proven", fields.get("assets").pos);
		}

		return {
			name: name,
			title: title,
			category: category,
			description: description,
			icon: icon,
			keywords: keywords,
			version: version,
			textdomain: textdomain,
			parent: parent,
			ancestor: ancestor,
			allowedBlocks: allowedBlocks,
			usesContext: usesContext,
			providesContext: providesContext,
			supports: supports,
			attributes: attributes,
			assets: assets,
			position: options.pos
		};
	}

	static function objectFields(expression:Expr):Map<String, Expr> {
		final result:Map<String, Expr> = [];
		switch expression.expr {
			case EObjectDecl(fields):
				for (field in fields) {
					if (result.exists(field.field)) {
						fail("WPX6020", "duplicate block declaration key " + field.field, field.expr.pos);
					}
					result.set(field.field, field.expr);
				}
			case _:
				fail("WPX6020", "Block.define metadata must be a closed object literal", expression.pos);
		}
		return result;
	}

	static function categoryValue(expression:Expr):String {
		requireType(expression, "wordpress.hx.gutenberg.block.BlockCategory", "WPX6027", "block category");
		final value = switch terminalName(expression) {
			case "Text": "text";
			case "Media": "media";
			case "Design": "design";
			case "Widgets": "widgets";
			case "Theme": "theme";
			case "Embed": "embed";
			case _: fail("WPX6027", "category must use a typed BlockCategory value", expression.pos);
		};
		return value;
	}

	static function optionalBlockNames(fields:Map<String, Expr>, name:String):Array<String> {
		if (!fields.exists(name)) {
			return [];
		}
		final values = stringArray(fields.get(name), "WPX6028", name);
		for (value in values) {
			if (!BLOCK_NAME.match(value)) {
				fail("WPX6028", name + " contains an invalid block name " + value, fields.get(name).pos);
			}
		}
		return values;
	}

	static function contextNames(expression:Expr, label:String):Array<String> {
		final values = stringArray(expression, "WPX6028", label);
		for (value in values) {
			if (!BLOCK_NAME.match(value)) {
				fail("WPX6028", label + " contains an invalid namespaced context " + value, expression.pos);
			}
		}
		return values;
	}

	static function contextProviders(expression:Expr, attributes:Array<BlockAttribute>):Array<BlockContextProvider> {
		final attributeNames = [for (attribute in attributes) attribute.name];
		final result:Array<BlockContextProvider> = [];
		switch expression.expr {
			case EArrayDecl(values):
				for (value in values) {
					final fields = objectFields(value);
					for (name in fields.keys()) {
						if (!["name", "attribute"].contains(name)) {
							fail("WPX6028", "unknown providesContext field " + name, fields.get(name).pos);
						}
					}
					if (!fields.exists("name") || !fields.exists("attribute")) {
						fail("WPX6028", "providesContext entries need name and attribute", value.pos);
					}
					final name = literalString(fields.get("name"), "WPX6028", "context name");
					final attribute = literalString(fields.get("attribute"), "WPX6028", "context attribute");
					if (!BLOCK_NAME.match(name) || !ATTRIBUTE_NAME.match(attribute) || !attributeNames.contains(attribute)) {
						fail("WPX6028", "provided context must reference a declared attribute by a namespaced name", value.pos);
					}
					if ([for (entry in result) entry.name].contains(name)) {
						fail("WPX6028", "duplicate provided context " + name, value.pos);
					}
					result.push({name: name, attribute: attribute});
				}
			case _:
				fail("WPX6028", "providesContext must be an array of typed context mappings", expression.pos);
		}
		result.sort((left, right) -> compareText(left.name, right.name));
		return result;
	}

	static function supportsValue(session:BlockSession, expression:Expr):JsonValue {
		final fields = objectFields(expression);
		final values:Array<JsonField> = [];
		for (name in fields.keys()) {
			if (!session.profile.allowedSupports.exists(name)) {
				fail("WPX6029", "supports key " + name + " is unavailable in wp70-release", fields.get(name).pos);
			}
			final value = if (BOOLEAN_SUPPORTS.contains(name)) {
				BoolValue(literalBoolean(fields.get(name), "WPX6029", "supports." + name));
			} else if (name == "align") {
				alignmentValue(fields.get(name));
			} else if (NESTED_SUPPORTS.exists(name)) {
				nestedBooleanObject(fields.get(name), NESTED_SUPPORTS.get(name), "supports." + name);
			} else {
				fail("WPX6029", "supports key " + name + " is profile-known but not part of the stable SDK-060 typed subset", fields.get(name).pos);
			};
			values.push({name: name, value: value});
		}
		return ObjectValue(values);
	}

	static function alignmentValue(expression:Expr):JsonValue {
		return switch expression.expr {
			case EConst(CIdent("true")): BoolValue(true);
			case EConst(CIdent("false")): BoolValue(false);
			case EArrayDecl(values):
				final alignments:Array<JsonValue> = [];
				final seen:Map<String, Bool> = [];
				for (value in values) {
					requireType(value, "wordpress.hx.gutenberg.block.BlockAlignment", "WPX6029", "supports.align entry");
					final alignment = switch terminalName(value) {
						case "Wide": "wide";
						case "Full": "full";
						case "Left": "left";
						case "Center": "center";
						case "Right": "right";
						case _: fail("WPX6029", "align entries must use typed BlockAlignment values", value.pos);
					};
					if (seen.exists(alignment)) {
						fail("WPX6029", "duplicate block alignment " + alignment, value.pos);
					}
					seen.set(alignment, true);
					alignments.push(StringValue(alignment));
				}
				ArrayValue(alignments);
			case _:
				fail("WPX6029", "supports.align must be a boolean or typed BlockAlignment array", expression.pos);
		};
	}

	static function nestedBooleanObject(expression:Expr, allowed:Array<String>, label:String):JsonValue {
		final fields = objectFields(expression);
		final values:Array<JsonField> = [];
		for (name in fields.keys()) {
			if (!allowed.contains(name)) {
				fail("WPX6029", "unknown " + label + " key " + name, fields.get(name).pos);
			}
			values.push({name: name, value: BoolValue(literalBoolean(fields.get(name), "WPX6029", label + "." + name))});
		}
		return ObjectValue(values);
	}

	static function assetValues(session:BlockSession, blockName:String, expression:Expr):Array<OwnedAsset> {
		final fields = objectFields(expression);
		final result:Array<OwnedAsset> = [];
		final seenIds:Map<String, Bool> = [];
		for (metadataKey in fields.keys()) {
			if (!session.profile.allowedAssetKeys.exists(metadataKey)) {
				fail("WPX6030", "unknown or unsupported block asset metadata key " + metadataKey, fields.get(metadataKey).pos);
			}
			final ids = switch fields.get(metadataKey).expr {
				case EArrayDecl(_): stringArray(fields.get(metadataKey), "WPX6030", "asset ids");
				case _: [literalString(fields.get(metadataKey), "WPX6030", "asset id")];
			};
			for (id in ids) {
				if (seenIds.exists(id) || !session.assets.exists(id)) {
					fail("WPX6030", "block asset id is absent or duplicated: " + id, fields.get(metadataKey).pos);
				}
				seenIds.set(id, true);
				final asset = session.assets.get(id);
				if (asset.blockName != blockName || asset.metadataKey != metadataKey) {
					fail("WPX6030", "block asset " + id + " belongs to " + asset.blockName + "." + asset.metadataKey, fields.get(metadataKey).pos);
				}
				result.push(asset);
			}
		}
		result.sort((left, right) -> {
			final byKey = compareText(left.metadataKey, right.metadataKey);
			return byKey == 0 ? compareText(left.id, right.id) : byKey;
		});
		return result;
	}

	static function stringArray(expression:Expr, code:String, label:String):Array<String> {
		final result:Array<String> = [];
		switch expression.expr {
			case EArrayDecl(values):
				for (value in values) {
					final text = literalString(value, code, label + " entry");
					if (result.contains(text)) {
						fail(code, label + " contains duplicate " + text, value.pos);
					}
					result.push(text);
				}
			case _:
				fail(code, label + " must be an array literal", expression.pos);
		}
		return result;
	}

	static function printableText(expression:Expr, code:String, label:String):String {
		final value = literalString(expression, code, label);
		for (index in 0...value.length) {
			final character = value.charCodeAt(index);
			if (character < 0x20 || character == 0x7f) {
				fail(code, label + " contains a control character", expression.pos);
			}
		}
		return value;
	}

	static function literalString(expression:Expr, code:String, label:String):String {
		return switch expression.expr {
			case EConst(CString(value, _)) if (value != ""): value;
			case _: fail(code, label + " must be a non-empty string literal", expression.pos);
		};
	}

	static function literalInteger(expression:Expr, code:String, label:String):Int {
		return switch expression.expr {
			case EConst(CInt(value, _)):
				final parsed = Std.parseInt(value);
				parsed == null ? fail(code, label + " is outside the supported integer range", expression.pos) : parsed;
			case _: fail(code, label + " must be an integer literal", expression.pos);
		};
	}

	static function literalBoolean(expression:Expr, code:String, label:String):Bool {
		return switch expression.expr {
			case EConst(CIdent("true")): true;
			case EConst(CIdent("false")): false;
			case _: fail(code, label + " must be a boolean literal", expression.pos);
		};
	}

	static function terminalName(expression:Expr):Null<String> {
		return switch expression.expr {
			case EConst(CIdent(name)): name;
			case EField(_, name): name;
			case _: null;
		};
	}

	static function requireType(expression:Expr, expectedName:String, code:String, label:String):Void {
		final actual = Context.typeof(expression);
		final expected = Context.getType(expectedName);
		if (!Context.unify(actual, expected)) {
			fail(code, label + " must use " + expectedName + ", found " + TypeTools.toString(actual), expression.pos);
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
#end
