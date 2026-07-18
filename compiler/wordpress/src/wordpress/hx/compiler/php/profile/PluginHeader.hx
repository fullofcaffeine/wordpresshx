package wordpress.hx.compiler.php.profile;

/** Typed, ordered WordPress plugin header metadata. **/
class PluginHeader {
	static final VERSION_REQUIREMENT = ~/^[0-9]+\.[0-9]+$/;

	public final name:String;
	public final description:String;
	public final version:String;
	public final requiresWordPress:String;
	public final requiresPhp:String;
	public final author:String;
	public final license:String;
	public final textDomain:String;
	public final domainPath:String;
	public final networkOnly:Bool;
	public final pluginUri:Null<String>;
	public final authorUri:Null<String>;
	public final licenseUri:Null<String>;
	public final updateUri:Null<String>;

	public function new(name:String, description:String, version:String, requiresWordPress:String, requiresPhp:String, author:String, license:String,
			textDomain:String, domainPath:String = "/languages", networkOnly:Bool = false, ?pluginUri:String, ?authorUri:String, ?licenseUri:String,
			?updateUri:String) {
		this.name = headerValue("Plugin Name", name);
		this.description = headerValue("Description", description);
		this.version = headerValue("Version", version);
		this.requiresWordPress = versionRequirement("Requires at least", requiresWordPress);
		this.requiresPhp = versionRequirement("Requires PHP", requiresPhp);
		this.author = headerValue("Author", author);
		this.license = headerValue("License", license);
		this.textDomain = slugValue("Text Domain", textDomain);
		this.domainPath = domainPathValue(domainPath);
		this.networkOnly = networkOnly;
		this.pluginUri = optionalUri("Plugin URI", pluginUri);
		this.authorUri = optionalUri("Author URI", authorUri);
		this.licenseUri = optionalUri("License URI", licenseUri);
		this.updateUri = optionalUri("Update URI", updateUri);
	}

	public function orderedEntries():Array<PluginHeaderEntry> {
		final entries:Array<PluginHeaderEntry> = [
			entry("Plugin Name", name),
			entry("Description", description),
			entry("Version", version),
			entry("Requires at least", requiresWordPress),
			entry("Requires PHP", requiresPhp),
			entry("Author", author),
			entry("License", license),
			entry("Text Domain", textDomain),
			entry("Domain Path", domainPath)
		];
		if (pluginUri != null) {
			entries.insert(1, entry("Plugin URI", pluginUri));
		}
		if (authorUri != null) {
			entries.insert(indexAfter(entries, "Author"), entry("Author URI", authorUri));
		}
		if (licenseUri != null) {
			entries.insert(indexAfter(entries, "License"), entry("License URI", licenseUri));
		}
		if (updateUri != null) {
			entries.push(entry("Update URI", updateUri));
		}
		if (networkOnly) {
			entries.push(entry("Network", "true"));
		}
		return entries;
	}

	static function indexAfter(entries:Array<PluginHeaderEntry>, label:String):Int {
		for (index in 0...entries.length) {
			if (entries[index].label == label) {
				return index + 1;
			}
		}
		throw "Missing plugin header ordering anchor: " + label;
	}

	static function entry(label:String, value:String):PluginHeaderEntry {
		return {label: label, value: value};
	}

	static function versionRequirement(label:String, value:String):String {
		final normalized = headerValue(label, value);
		if (!VERSION_REQUIREMENT.match(normalized)) {
			throw label + " must use an exact major.minor requirement";
		}
		return normalized;
	}

	static function slugValue(label:String, value:String):String {
		final normalized = headerValue(label, value);
		if (!~/^[a-z0-9]+(?:-[a-z0-9]+)*$/.match(normalized)) {
			throw label + " must be a lowercase WordPress slug";
		}
		return normalized;
	}

	static function domainPathValue(value:String):String {
		final normalized = headerValue("Domain Path", value);
		if (!StringTools.startsWith(normalized, "/")
			|| StringTools.endsWith(normalized, "/")
			|| normalized.indexOf("..") != -1
			|| !~/^\/[A-Za-z0-9._\/-]+$/.match(normalized)) {
			throw "Domain Path must be a safe plugin-relative absolute path";
		}
		return normalized;
	}

	static function optionalUri(label:String, value:Null<String>):Null<String> {
		if (value == null) {
			return null;
		}
		final normalized = headerValue(label, value);
		if (!StringTools.startsWith(normalized, "https://")) {
			throw label + " must use https";
		}
		return normalized;
	}

	static function headerValue(label:String, value:String):String {
		if (value == null) {
			throw label + " cannot be null";
		}
		final normalized = StringTools.trim(value);
		if (normalized.length == 0 || normalized.indexOf("\x00") != -1 || normalized.indexOf("\r") != -1 || normalized.indexOf("\n") != -1
			|| normalized.indexOf("*/") != -1) {
			throw "Unsafe or empty plugin header value: " + label;
		}
		return normalized;
	}
}

typedef PluginHeaderEntry = {
	final label:String;
	final value:String;
}
