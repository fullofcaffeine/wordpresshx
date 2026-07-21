package wordpress.hx.gutenberg.browser;

#if macro
import haxe.Json;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Declares a Haxe facade as a retained public ESM root.
 *
 * This SDK directive owns stable export identity and evidence metadata. It
 * projects retention to the generic Genes library profile without teaching
 * Genes about WordPress names, profiles, or manifests.
 */
class BrowserExport {
	#if macro
	private static final EXPORT_ID = ~/^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)+$/;
	private static final CAPABILITY_ID = ~/^[a-z][A-Za-z0-9._@\/-]*[A-Za-z0-9]$/;

	private static var callbackInstalled = false;
	private static var entries:Array<BrowserExportEntry> = [];

	public static macro function build(stableExportId:String, profileCapabilityRefs:Array<String>):Array<Field> {
		if (!EXPORT_ID.match(stableExportId)) {
			Context.error('WPX3100: invalid browser export ID ${stableExportId}.', Context.currentPos());
		}

		final selectedProfile = Context.definedValue("wordpress_hx_profile");
		if (selectedProfile == null || selectedProfile.length == 0) {
			Context.error("WPX3101: browser exports require an exact wordpress_hx_profile define.", Context.currentPos());
		}

		final capabilityRefs = profileCapabilityRefs.copy();
		capabilityRefs.sort(compareText);
		for (index in 0...capabilityRefs.length) {
			final capabilityId = capabilityRefs[index];
			if (!CAPABILITY_ID.match(capabilityId)) {
				Context.error('WPX3102: invalid browser export capability ID ${capabilityId}.', Context.currentPos());
			}
			if (index > 0 && capabilityRefs[index - 1] == capabilityId) {
				Context.error('WPX3103: duplicate browser export capability ID ${capabilityId}.', Context.currentPos());
			}
		}

		final localClass = Context.getLocalClass().get();
		if (!localClass.meta.has(":genes.library")) {
			localClass.meta.add(":genes.library", [], localClass.pos);
		}
		localClass.meta.add(":wordpress.browserExport", [macro $v{stableExportId}], localClass.pos);

		final position = Context.getPosInfos(localClass.pos);
		final sourcePath = normalizeSourcePath(position.file);
		final typeIdentity = localClass.pack.concat([localClass.name]).join(".");
		final generatedModule = localClass.module.split(".").join("/");
		for (entry in entries) {
			if (entry.stableExportId == stableExportId) {
				Context.error('WPX3104: duplicate browser export ID ${stableExportId}.', localClass.pos);
			}
			if (entry.generatedModule == generatedModule && entry.exportName == localClass.name) {
				Context.error('WPX3105: duplicate browser export target ${typeIdentity}.', localClass.pos);
			}
		}
		entries.push({
			stableExportId: stableExportId,
			haxeSource: sourcePath,
			generatedModule: generatedModule,
			exportName: localClass.name,
			typeIdentity: typeIdentity,
			retentionRule: "genes-library-root",
			profileCapabilityRefs: capabilityRefs,
			sourceSpan: {
				start: position.min,
				end: position.max
			}
		});

		if (!callbackInstalled) {
			callbackInstalled = true;
			Context.onAfterGenerate(emitManifest);
		}
		return Context.getBuildFields();
	}

	private static function normalizeSourcePath(sourcePath:String):String {
		final normalized = sourcePath.split("\\").join("/");
		final workingDirectory = Sys.getCwd().split("\\").join("/");
		return if (StringTools.startsWith(normalized, workingDirectory + "/")) {
			normalized.substr(workingDirectory.length + 1);
		} else {
			normalized;
		}
	}

	private static function emitManifest():Void {
		if (!Context.defined("genes.library")) {
			return;
		}
		final outputPath = Context.definedValue("wordpress_hx_browser_export_manifest");
		if (outputPath == null || outputPath.length == 0) {
			Context.error("WPX3106: genes.library requires wordpress_hx_browser_export_manifest.", Context.currentPos());
		}

		entries.sort((left, right) -> compareText(left.stableExportId, right.stableExportId));
		final parent = Path.directory(outputPath);
		if (parent.length > 0 && !FileSystem.exists(parent)) {
			FileSystem.createDirectory(parent);
		}
		final payload = {
			schemaVersion: 1,
			profileId: Context.definedValue("wordpress_hx_profile"),
			compilerProfile: Context.defined("genes.ts") ? "strict-typescript-source" : "classic-genes-esm",
			entries: entries
		};
		File.saveContent(outputPath, Json.stringify(payload, null, "  ") + "\n");
	}

	private static function compareText(left:String, right:String):Int {
		return left == right ? 0 : left < right ? -1 : 1;
	}
	#end
}

#if macro
private typedef BrowserExportEntry = {
	final stableExportId:String;
	final haxeSource:String;
	final generatedModule:String;
	final exportName:String;
	final typeIdentity:String;
	final retentionRule:String;
	final profileCapabilityRefs:Array<String>;
	final sourceSpan:{
		final start:Int;
		final end:Int;
	};
}
#end
