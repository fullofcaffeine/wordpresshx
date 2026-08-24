package wordpress.hx.compiler.php.profile;

import wordpress.hx.i18n.LocaleCatalog;
import wordpress.hx.i18n.MessageOrigin;

/** Closed wp70-release i18n package input. */
class WordPressI18nPlan {
	public final profileId:String;
	public final slug:String;
	public final scriptHandle:String;
	public final header:PluginHeader;
	public final locale:LocaleCatalog;
	public final browser:WordPressI18nBrowserAsset;

	final sourceValues:Array<WordPressI18nSourceInput>;

	public var sources(get, never):Array<WordPressI18nSourceInput>;
	public var rootPath(get, never):String;
	public var messagesPath(get, never):String;
	public var bundlePath(get, never):String;
	public var metadataPath(get, never):String;
	public var potPath(get, never):String;
	public var moPath(get, never):String;
	public var jedPath(get, never):String;
	public var extractionPath(get, never):String;
	public var manifestPath(get, never):String;
	public var renderFunction(get, never):String;

	public function new(slug:String, scriptHandle:String, header:PluginHeader, locale:LocaleCatalog, browser:WordPressI18nBrowserAsset,
			sources:Array<WordPressI18nSourceInput>) {
		if (!~/^[a-z0-9]+(?:-[a-z0-9]+)*$/.match(slug) || !~/^[a-z0-9]+(?:-[a-z0-9]+)*$/.match(scriptHandle)) {
			throw "SDK-055 slug and script handle must be lowercase WordPress identities";
		}
		if (header == null || locale == null || browser == null || sources == null || sources.length == 0) {
			throw "SDK-055 plan requires header, catalog, locale, browser asset, and source inputs";
		}
		if (header.textDomain != slug || locale.catalog.textDomain.toString() != slug) {
			throw "SDK-055 plugin, header, and catalog text domains must match";
		}
		if (header.requiresWordPress != "7.0" || header.requiresPhp != "7.4") {
			throw "SDK-055 requires the exact wp70-release floor profile";
		}
		final sourceByPath:Map<String, Bool> = [];
		final sourceCopies = sources.copy();
		sourceCopies.sort((left, right) -> compareText(left.path, right.path));
		for (source in sourceCopies) {
			if (source == null || sourceByPath.exists(source.path)) {
				throw "SDK-055 source inputs must have unique paths";
			}
			sourceByPath.set(source.path, true);
		}
		for (message in locale.catalog.messages) {
			switch (message.origin()) {
				case Authored(source):
					if (!sourceByPath.exists(source.file)) {
						throw "SDK-055 message source bytes are absent: " + source.file;
					}
				case External(boundary):
					throw "SDK-055 extractable package rejects external message boundary: " + boundary;
			}
		}
		this.profileId = "wp70-release";
		this.slug = slug;
		this.scriptHandle = scriptHandle;
		this.header = header;
		this.locale = locale;
		this.browser = browser;
		this.sourceValues = sourceCopies;
	}

	function get_sources():Array<WordPressI18nSourceInput> {
		return sourceValues.copy();
	}

	function get_rootPath():String {
		return slug + ".php";
	}

	function get_messagesPath():String {
		return "includes/messages.php";
	}

	function get_bundlePath():String {
		return "build/" + browser.bundleFilename;
	}

	function get_metadataPath():String {
		return "build/" + browser.metadataFilename;
	}

	function get_potPath():String {
		return "languages/" + slug + ".pot";
	}

	function get_moPath():String {
		return "languages/" + slug + "-" + locale.locale.toString() + ".mo";
	}

	function get_jedPath():String {
		return "languages/" + slug + "-" + locale.locale.toString() + "-" + scriptHandle + ".json";
	}

	function get_extractionPath():String {
		return "languages/" + slug + ".extraction.js";
	}

	function get_manifestPath():String {
		return "wordpresshx-i18n-artifact.v1.json";
	}

	function get_renderFunction():String {
		return slug.split("-").join("_") + "_render_messages";
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
