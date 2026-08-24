package wordpress.hx.compiler.php.profile;

import haxe.crypto.Sha256;
import haxe.io.Bytes;

/** Final official WordPress bundle and dependency metadata admitted by SDK-055. */
class WordPressI18nBrowserAsset {
	public final bundleFilename:String;
	public final metadataFilename:String;
	public final bundleSha256:String;
	public final version:String;

	final bundleValue:Bytes;
	final metadataValue:Bytes;
	final dependencyValues:Array<String>;

	public var bundle(get, never):Bytes;
	public var metadata(get, never):Bytes;
	public var dependencies(get, never):Array<String>;

	public function new(bundleFilename:String, bundle:Bytes, metadataFilename:String, metadata:Bytes) {
		if (bundle == null || metadata == null || bundle.length == 0 || metadata.length == 0) {
			throw "i18n browser asset requires bundle and metadata bytes";
		}
		if (bundleFilename != "messages.js" || metadataFilename != "messages.asset.php") {
			throw "SDK-055 browser asset requires messages.js and messages.asset.php";
		}
		this.bundleFilename = bundleFilename;
		this.metadataFilename = metadataFilename;
		this.bundleValue = bundle.sub(0, bundle.length);
		this.metadataValue = metadata.sub(0, metadata.length);
		this.bundleSha256 = Sha256.make(bundleValue).toHex();
		final parsed = parseMetadata(metadataValue.toString());
		if (parsed.dependencies.length != 1 || parsed.dependencies[0] != "wp-i18n") {
			throw "SDK-055 final bundle must depend exactly on wp-i18n";
		}
		this.dependencyValues = parsed.dependencies;
		this.version = parsed.version;
	}

	function get_bundle():Bytes {
		return bundleValue.sub(0, bundleValue.length);
	}

	function get_metadata():Bytes {
		return metadataValue.sub(0, metadataValue.length);
	}

	function get_dependencies():Array<String> {
		return dependencyValues.copy();
	}

	static function parseMetadata(source:String):{dependencies:Array<String>, version:String} {
		final matcher = ~/^<\?php return array\('dependencies' => array\((.*)\), 'version' => '([0-9a-f]{20})'\);\n?$/;
		if (!matcher.match(source)) {
			throw "official SDK-055 asset metadata shape drifted";
		}
		final body = matcher.matched(1);
		final dependencies:Array<String> = [];
		if (body.length > 0) {
			for (entry in body.split(", ")) {
				final dependency = ~/^'([a-z0-9-]+)'$/;
				if (!dependency.match(entry)) {
					throw "invalid official SDK-055 dependency entry: " + entry;
				}
				dependencies.push(dependency.matched(1));
			}
		}
		final sorted = dependencies.copy();
		sorted.sort(compareText);
		if (sorted.join("|") != dependencies.join("|") || Lambda.count(dependencies) != Lambda.count(unique(dependencies))) {
			throw "official SDK-055 dependencies must be sorted and unique";
		}
		return {dependencies: dependencies, version: matcher.matched(2)};
	}

	static function unique(values:Array<String>):Map<String, Bool> {
		final result:Map<String, Bool> = [];
		for (value in values) {
			result.set(value, true);
		}
		return result;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
