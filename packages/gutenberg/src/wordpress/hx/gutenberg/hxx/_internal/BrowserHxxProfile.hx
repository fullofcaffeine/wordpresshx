package wordpress.hx.gutenberg.hxx._internal;

#if macro
import haxe.Json;
import haxe.macro.Context;
import sys.io.File;

typedef BrowserHxxComponentProfile = {
	final tag:String;
	final haxeType:String;
	final propsType:String;
	final children:String;
	final request:String;
	final export:String;
}

typedef BrowserHxxProfileData = {
	final schemaVersion:Int;
	final profileId:String;
	final catalogRevision:String;
	final components:Array<BrowserHxxComponentProfile>;
	final hooks:Array<String>;
	final policy:{
		final rawJsxAllowed:Bool;
		final browserHxxRuntimeAllowed:Bool;
		final openAttributeSpreadsAllowed:Bool;
		final profileGeneratedOrCurated:String;
	};
}

typedef BrowserHxxCatalogData = {
	final schemaVersion:Int;
	final profileId:String;
	final catalogId:String;
	final catalogRevision:String;
	final components:Array<BrowserHxxComponentProfile>;
	final policy:{
		final privateApisAllowed:Bool;
		final experimentalApisAllowed:Bool;
		final componentCatalogGeneratedOrCurated:String;
	};
}

/** Loads and validates the exact compile-time browser HXX profile. */
class BrowserHxxProfile {
	private static final PROFILE_ID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$/;
	private static final CATALOG_ID = ~/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
	private static final TAG = ~/^[A-Z][A-Za-z0-9]*$/;
	private static var cache:Map<String, BrowserHxxProfileData> = [];

	public static function current():BrowserHxxProfileData {
		final selected = Context.definedValue("wordpress_hx_profile");
		if (selected == null || !PROFILE_ID.match(selected)) {
			Context.error("WPX3200: browser HXX requires an exact wordpress_hx_profile define.", Context.currentPos());
		}

		final selectedCatalog = Context.definedValue("wordpress_hx_browser_hxx_catalog");
		if (selectedCatalog != null && !CATALOG_ID.match(selectedCatalog)) {
			Context.error('WPX3202: invalid browser HXX catalog ID ${selectedCatalog}.', Context.currentPos());
		}
		final cacheKey = selectedCatalog == null ? selected : '${selected}|${selectedCatalog}';
		final cached = cache[cacheKey];
		if (cached != null) {
			return cached;
		}

		final resource = 'wordpress/hx/gutenberg/profile/${selected}.browser-hxx.json';
		final path = try {
			Context.resolvePath(resource);
		} catch (_:haxe.Exception) {
			Context.error('WPX3201: no browser HXX profile data exists for ${selected}.', Context.currentPos());
		}
		Context.registerModuleDependency(Context.getLocalModule(), path);
		final profile:BrowserHxxProfileData = try {
			Json.parse(File.getContent(path));
		} catch (_:haxe.Exception) {
			Context.error('WPX3202: browser HXX profile data for ${selected} is malformed.', Context.currentPos());
		}
		validate(profile, selected);
		final resolved = selectedCatalog == null ? profile : mergeCatalog(profile, loadCatalog(selected, selectedCatalog));
		cache[cacheKey] = resolved;
		return resolved;
	}

	public static function component(profile:BrowserHxxProfileData, tag:String):Null<BrowserHxxComponentProfile> {
		for (component in profile.components) {
			if (component.tag == tag) {
				return component;
			}
		}
		return null;
	}

	private static function validate(profile:BrowserHxxProfileData, selected:String):Void {
		if (profile.schemaVersion != 1 || profile.profileId != selected || profile.catalogRevision != '${selected}/catalog-v1') {
			Context.error('WPX3202: browser HXX profile identity does not match ${selected}.', Context.currentPos());
		}
		if (profile.policy.rawJsxAllowed || profile.policy.browserHxxRuntimeAllowed || profile.policy.openAttributeSpreadsAllowed) {
			Context.error('WPX3202: browser HXX profile ${selected} weakens a fail-closed policy.', Context.currentPos());
		}

		validateComponents(profile.components, []);
	}

	private static function loadCatalog(selected:String, catalogId:String):BrowserHxxCatalogData {
		final resource = 'wordpress/hx/gutenberg/profile/${selected}.${catalogId}.browser-hxx.json';
		final path = try {
			Context.resolvePath(resource);
		} catch (_:haxe.Exception) {
			Context.error('WPX3201: no browser HXX catalog ${catalogId} exists for ${selected}.', Context.currentPos());
		}
		Context.registerModuleDependency(Context.getLocalModule(), path);
		final catalog:BrowserHxxCatalogData = try {
			Json.parse(File.getContent(path));
		} catch (_:haxe.Exception) {
			Context.error('WPX3202: browser HXX catalog ${catalogId} for ${selected} is malformed.', Context.currentPos());
		}
		if (catalog.schemaVersion != 1
			|| catalog.profileId != selected
			|| catalog.catalogId != catalogId
			|| catalog.catalogRevision != '${selected}/${catalogId}-v1') {
			Context.error('WPX3202: browser HXX catalog identity does not match ${selected}/${catalogId}.', Context.currentPos());
		}
		if (catalog.policy.privateApisAllowed || catalog.policy.experimentalApisAllowed) {
			Context.error('WPX3202: browser HXX catalog ${selected}/${catalogId} admits private or experimental APIs.', Context.currentPos());
		}
		return catalog;
	}

	private static function mergeCatalog(profile:BrowserHxxProfileData, catalog:BrowserHxxCatalogData):BrowserHxxProfileData {
		validateComponents(catalog.components, profile.components);
		return {
			schemaVersion: profile.schemaVersion,
			profileId: profile.profileId,
			catalogRevision: profile.catalogRevision,
			components: profile.components.concat(catalog.components),
			hooks: profile.hooks,
			policy: profile.policy
		};
	}

	private static function validateComponents(components:Array<BrowserHxxComponentProfile>, existing:Array<BrowserHxxComponentProfile>):Void {
		final seen = new Map<String, Bool>();
		for (component in existing) {
			seen[component.tag] = true;
		}
		for (component in components) {
			if (!TAG.match(component.tag) || seen.exists(component.tag)) {
				Context.error('WPX3202: invalid or duplicate browser HXX component ${component.tag}.', Context.currentPos());
			}
			if (component.request.charAt(0) != "@" || component.export != component.tag) {
				Context.error('WPX3202: invalid import identity for browser HXX component ${component.tag}.', Context.currentPos());
			}
			if (component.children != "required" && component.children != "optional" && component.children != "forbidden") {
				Context.error('WPX3202: invalid children contract for browser HXX component ${component.tag}.', Context.currentPos());
			}
			seen[component.tag] = true;
		}
	}
}
#end
