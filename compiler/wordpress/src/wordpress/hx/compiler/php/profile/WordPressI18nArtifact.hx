package wordpress.hx.compiler.php.profile;

import haxe.Json;
import wordpress.hx.i18n.MessageOrigin;

typedef WordPressI18nManifestFile = {
	final path:String;
	final role:String;
	final classification:String;
	final bytes:Int;
	final sha256:String;
}

typedef WordPressI18nManifestSource = {
	final path:String;
	final bytes:Int;
	final sha256:String;
}

typedef WordPressI18nManifestMessage = {
	final key:String;
	final kind:String;
	final context:Null<String>;
	final domain:String;
	final comment:String;
	final source:{final file:String; final line:Int;};
}

typedef WordPressI18nManifest = {
	final schemaVersion:Int;
	final manifestId:String;
	final profileId:String;
	final plugin:{final slug:String; final textDomain:String; final rootPath:String;};
	final browser:{
		final handle:String;
		final bundleSha256:String;
		final version:String;
		final dependencies:Array<String>;
		final hooks:Array<String>;
	};
	final locale:{final id:String; final pluralForms:String;};
	final messages:Array<WordPressI18nManifestMessage>;
	final sources:Array<WordPressI18nManifestSource>;
	final files:Array<WordPressI18nManifestFile>;
	final provenance:{final extraction:String; final sourceBytesRequired:Bool; final externalMessagesAllowed:Bool;};
	final claims:{
		final generation:String;
		final phpRuntime:String;
		final editorRuntime:String;
		final frontendRuntime:String;
		final publicationAuthorized:Bool;
	};
}

/** Deterministic complete SDK-055 plugin package and evidence manifest. */
class WordPressI18nArtifact {
	public final plan:WordPressI18nPlan;

	final fileValues:Array<WordPressI18nFile>;

	public var files(get, never):Array<WordPressI18nFile>;

	public function new(plan:WordPressI18nPlan, files:Array<WordPressI18nFile>) {
		if (plan == null || files == null) {
			throw "SDK-055 artifact requires a plan and files";
		}
		final values = files.copy();
		values.sort((left, right) -> compareText(left.path, right.path));
		final paths:Map<String, Bool> = [];
		final roles:Map<String, Bool> = [];
		for (file in values) {
			if (file == null || paths.exists(file.path) || roles.exists(file.role)) {
				throw "SDK-055 artifact paths and roles must be unique";
			}
			paths.set(file.path, true);
			roles.set(file.role, true);
		}
		final expected = [
			"plugin-root" => plan.rootPath,
			"server-messages" => plan.messagesPath,
			"browser-bundle" => plan.bundlePath,
			"asset-metadata" => plan.metadataPath,
			"pot" => plan.potPath,
			"mo" => plan.moPath,
			"jed" => plan.jedPath,
			"extraction-surrogate" => plan.extractionPath
		];
		if (values.length != Lambda.count(expected)) {
			throw "SDK-055 artifact file count drifted";
		}
		for (file in values) {
			if (expected.get(file.role) != file.path) {
				throw "SDK-055 artifact role/path mismatch: " + file.role;
			}
		}
		this.plan = plan;
		this.fileValues = values;
	}

	public function file(path:String):WordPressI18nFile {
		for (file in fileValues) {
			if (file.path == path) {
				return file;
			}
		}
		throw "unknown SDK-055 artifact path: " + path;
	}

	public function manifestSource():String {
		return Json.stringify(manifest(), null, "  ") + "\n";
	}

	public function manifest():WordPressI18nManifest {
		final files:Array<WordPressI18nManifestFile> = [];
		for (file in fileValues) {
			files.push({
				path: file.path,
				role: file.role,
				classification: file.classification,
				bytes: file.byteLength,
				sha256: file.sha256
			});
		}
		final sources:Array<WordPressI18nManifestSource> = [];
		for (source in plan.sources) {
			sources.push({path: source.path, bytes: source.byteLength, sha256: source.sha256});
		}
		final messages:Array<WordPressI18nManifestMessage> = [];
		for (catalogMessage in plan.locale.catalog.messages) {
			final source = switch (catalogMessage.origin()) {
				case Authored(value): value;
				case External(boundary): throw "manifest cannot admit external message: " + boundary;
			};
			final data = switch (catalogMessage.definition()) {
				case Text(message): {kind: "text", context: message.messageContext, comment: message.translatorComment};
				case StringPlaceholder(message): {kind: "string-placeholder", context: message.messageContext, comment: message.translatorComment};
				case PluralCount(message): {kind: "plural-count", context: message.messageContext, comment: message.translatorComment};
			};
			messages.push({
				key: catalogMessage.key().toString(),
				kind: data.kind,
				context: data.context,
				domain: catalogMessage.domain().toString(),
				comment: data.comment,
				source: {
					file: source.file,
					line: source.line
				}
			});
		}
		return {
			schemaVersion: 1,
			manifestId: "wordpresshx-i18n-artifact-v1",
			profileId: plan.profileId,
			plugin: {slug: plan.slug, textDomain: plan.header.textDomain, rootPath: plan.rootPath},
			browser: {
				handle: plan.scriptHandle,
				bundleSha256: plan.browser.bundleSha256,
				version: plan.browser.version,
				dependencies: plan.browser.dependencies,
				hooks: ["enqueue_block_editor_assets", "wp_enqueue_scripts"]
			},
			locale: {id: plan.locale.locale.toString(), pluralForms: plan.locale.pluralForms},
			messages: messages,
			sources: sources,
			files: files,
			provenance: {extraction: "byte-linked-deterministic-surrogate", sourceBytesRequired: true, externalMessagesAllowed: false},
			claims: {
				generation: "generated",
				phpRuntime: "not-tested",
				editorRuntime: "not-tested",
				frontendRuntime: "not-tested",
				publicationAuthorized: false
			}
		};
	}

	function get_files():Array<WordPressI18nFile> {
		return fileValues.copy();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
