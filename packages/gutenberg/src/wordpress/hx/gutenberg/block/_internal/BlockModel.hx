package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.macro.Expr.Position;
import wordpress.hx.build._internal.JsonValue;

typedef BlockProfile = {
	final profileId:String;
	final catalogRevision:String;
	final schemaUrl:String;
	final schemaSha256:String;
	final apiVersion:Int;
	final allowedMetadata:Map<String, Bool>;
	final forbiddenMetadata:Map<String, String>;
	final allowedSupports:Map<String, Bool>;
	final allowedAssetKeys:Map<String, String>;
	final allowedHandles:Map<String, String>;
}

enum AssetReferenceKind {
	FileReference;
	HandleReference;
}

typedef OwnedAsset = {
	final id:String;
	final blockName:String;
	final metadataKey:String;
	final kind:String;
	final referenceKind:AssetReferenceKind;
	final reference:String;
	final path:String;
	final owner:String;
	final capabilityId:String;
	final sha256:String;
}

typedef AttributeDefault = {
	final value:JsonValue;
	final position:Position;
}

typedef BlockAttribute = {
	final name:String;
	final typeName:String;
	final enumValues:Array<String>;
	final source:Null<String>;
	final selector:Null<String>;
	final htmlAttribute:Null<String>;
	final role:Null<String>;
	final defaultValue:Null<AttributeDefault>;
}

typedef BlockDraft = {
	final name:String;
	final title:String;
	final category:String;
	final description:Null<String>;
	final icon:Null<String>;
	final keywords:Array<String>;
	final version:Null<String>;
	final textdomain:String;
	final parent:Array<String>;
	final ancestor:Array<String>;
	final allowedBlocks:Array<String>;
	final usesContext:Array<String>;
	final providesContext:Array<BlockContextProvider>;
	final supports:Null<JsonValue>;
	final attributes:Array<BlockAttribute>;
	final assets:Array<OwnedAsset>;
	final position:Position;
}

typedef BlockContextProvider = {
	final name:String;
	final attribute:String;
}

typedef BlockSession = {
	final generation:Int;
	final profile:BlockProfile;
	final profilePath:String;
	final assetManifestPath:String;
	final outputRoot:String;
	final assets:Map<String, OwnedAsset>;
	final drafts:Array<BlockDraft>;
	var finalized:Bool;
}
#end
