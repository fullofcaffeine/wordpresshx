package wordpresshx.cli.project;

import haxe.Exception;
import haxe.Resource;
import js.lib.Error;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.ChildProcess.ChildProcessSpawnSyncResult;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;
import wordpresshx.cli.scaffold.ScaffoldJson;

/** Run the pinned generated-PHP gate without project-authored PHP configuration. */
class PluginPhpQuality {
	static inline final TEMPORARY_PREFIX = "wordpresshx-plugin-quality-";
	static inline final TOOL_DIRECTORY = "php-quality";
	static inline final POLICY_ID = "wp70-release-generated-php-v1";
	static inline final RECEIPT_SCHEMA = "wordpress-hx.php-quality-run.v1";
	static inline final REPORT_SCHEMA = "wordpress-hx.php-quality-report.v1";
	static inline final WORDPRESS_STUBS_SHA256 = "1fa69deee70f8a1be7e3a0498327ca16e36ee2b5c243a5b2ab1926bec456fd44";

	public static function validate(context:ProjectContext, emission:PluginEmission):PluginPhpQualityResult {
		final policy = loadPolicy();
		final toolRoot = resolveToolRoot();
		verifyPolicy(toolRoot, policy);
		final expectedPolicySha256 = policyDigest(policy);
		final expectedComposerLockSha256 = policyFile(policy, "composer.lock").sha256;
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), TEMPORARY_PREFIX));
		final pluginRoot = Path.join(temporaryRoot, "plugin");
		try {
			ensureDirectory(pluginRoot);
			for (file in emission.files) {
				write(pluginRoot, file.relativePath, file.bytes);
			}
			final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync("php", [Path.join(toolRoot, "run.php"), pluginRoot], {
				cwd: toolRoot,
				encoding: "utf8",
				timeout: 120000,
				stdio: ["ignore", "pipe", "pipe"]
			});
			if (result.error != null || result.status != 0) {
				final transcript = StringTools.trim(Std.string(result.stderr) + "\n" + Std.string(result.stdout));
				throw qualityFailure(transcript.length == 0 ? "the pinned PHP quality process failed" : transcript, context, toolRoot, temporaryRoot);
			}
			if (StringTools.trim(Std.string(result.stderr)).length != 0) {
				throw qualityFailure("the pinned PHP quality process wrote an unexpected error transcript", context, toolRoot, temporaryRoot);
			}
			final receipt = decodeReceipt(Std.string(result.stdout), emission, expectedPolicySha256, expectedComposerLockSha256);
			final reportBytes = renderReport(emission, receipt);
			removeTemporary(temporaryRoot);
			return new PluginPhpQualityResult(receipt.policyId, receipt.policySha256, receipt.composerLockSha256, receipt.wordpressStubsSha256,
				receipt.phpFileCount, receipt.publicPhpFileCount, receipt.privatePhpFileCount, receipt.classmapEntries, reportBytes);
		} catch (failure:CliFailure) {
			removeTemporary(temporaryRoot);
			throw failure;
		} catch (failure:Exception) {
			removeTemporary(temporaryRoot);
			throw qualityFailure(failure.message, context, toolRoot, temporaryRoot);
		} catch (failure:Error) {
			removeTemporary(temporaryRoot);
			throw qualityFailure(failure.message, context, toolRoot, temporaryRoot);
		}
	}

	static function loadPolicy():Array<PluginPhpQualityPolicyFile> {
		final declarations = [
			new PluginPhpQualityResource("composer.json", "wordpresshx-php-quality-composer-json"),
			new PluginPhpQualityResource("composer.lock", "wordpresshx-php-quality-composer-lock"),
			new PluginPhpQualityResource("phpcs-compat-private.xml", "wordpresshx-php-quality-phpcs-compat-private"),
			new PluginPhpQualityResource("phpcs-compat.xml", "wordpresshx-php-quality-phpcs-compat"),
			new PluginPhpQualityResource("phpcs-public.xml", "wordpresshx-php-quality-phpcs-public"),
			new PluginPhpQualityResource("phpstan-private.neon", "wordpresshx-php-quality-phpstan-private"),
			new PluginPhpQualityResource("phpstan-public.neon", "wordpresshx-php-quality-phpstan-public"),
			new PluginPhpQualityResource("run.php", "wordpresshx-php-quality-runner"),
			new PluginPhpQualityResource("toolchain.json", "wordpresshx-php-quality-toolchain")
		];
		final result:Array<PluginPhpQualityPolicyFile> = [];
		for (declaration in declarations) {
			final source = Resource.getString(declaration.resourceId);
			if (source == null || source.length == 0) {
				throw new CliFailure("WPHX3400", "the CLI is missing its embedded PHP quality policy", 70, "format-and-static-check");
			}
			final bytes = Buffer.from(source, "utf8");
			result.push(new PluginPhpQualityPolicyFile(declaration.relativePath, bytes, OwnershipJson.digest(bytes)));
		}
		return result;
	}

	static function resolveToolRoot():String {
		final arguments = NodeGlobals.process().argv;
		if (arguments.length < 2 || !Fs.existsSync(arguments[1])) {
			throw missingToolBundle();
		}
		final entry = Fs.realpathSync(Path.resolve(arguments[1]));
		final candidate = Path.join(Path.dirname(entry), TOOL_DIRECTORY);
		if (!Fs.existsSync(candidate)) {
			throw missingToolBundle();
		}
		final root = Fs.realpathSync(candidate);
		final stats = Fs.lstatSync(root);
		if (!stats.isDirectory() || stats.isSymbolicLink()) {
			throw missingToolBundle();
		}
		return root;
	}

	static function verifyPolicy(toolRoot:String, policy:Array<PluginPhpQualityPolicyFile>):Void {
		for (file in policy) {
			final absolute = Path.join(toolRoot, file.relativePath);
			if (!Fs.existsSync(absolute)) {
				throw policyMismatch(file.relativePath);
			}
			final stats = Fs.lstatSync(absolute);
			if (!stats.isFile() || stats.isSymbolicLink()) {
				throw policyMismatch(file.relativePath);
			}
			final bytes = Fs.readFileSync(absolute);
			if (bytes.length != file.bytes.length || OwnershipJson.digest(bytes) != file.sha256) {
				throw policyMismatch(file.relativePath);
			}
		}
		final vendorAutoload = Path.join(toolRoot, "vendor/autoload.php");
		if (!Fs.existsSync(vendorAutoload) || !Fs.lstatSync(vendorAutoload).isFile()) {
			throw missingToolBundle();
		}
	}

	static function decodeReceipt(source:String, emission:PluginEmission, expectedPolicySha256:String,
			expectedComposerLockSha256:String):PluginPhpQualityReceipt {
		if (!StringTools.endsWith(source, "\n")) {
			throw invalidReceipt("the PHP quality receipt is not newline terminated");
		}
		final fields = new Map<String, String>();
		final lines = source.substr(0, source.length - 1).split("\n");
		for (line in lines) {
			final separator = line.indexOf("=");
			if (separator <= 0 || separator == line.length - 1) {
				throw invalidReceipt("the PHP quality receipt contains a malformed field");
			}
			final name = line.substr(0, separator);
			if (fields.exists(name)) {
				throw invalidReceipt("the PHP quality receipt repeats field " + name);
			}
			fields.set(name, line.substr(separator + 1));
		}
		final expectedFields = [
			"autoloadMode",
			"classmapEntries",
			"composerLockSha256",
			"formatChangedFiles",
			"phpFileCount",
			"phpStanPrivateLevel",
			"phpStanPublicLevel",
			"policyId",
			"policySha256",
			"privatePhpFileCount",
			"publicPhpFileCount",
			"schema",
			"status",
			"wordpressStubsSha256"
		];
		if (fieldCount(fields) != expectedFields.length) {
			throw invalidReceipt("the PHP quality receipt has the wrong field count");
		}
		for (name in expectedFields) {
			if (!fields.exists(name)) {
				throw invalidReceipt("the PHP quality receipt omitted field " + name);
			}
		}
		final receipt = new PluginPhpQualityReceipt(requireField(fields, "autoloadMode"), parseInteger(fields, "classmapEntries"),
			requireSha256(fields, "composerLockSha256"), parseInteger(fields, "formatChangedFiles"), parseInteger(fields, "phpFileCount"),
			parseInteger(fields, "phpStanPrivateLevel"), parseInteger(fields, "phpStanPublicLevel"), requireField(fields, "policyId"),
			requireSha256(fields, "policySha256"), parseInteger(fields, "privatePhpFileCount"), parseInteger(fields, "publicPhpFileCount"),
			requireField(fields, "schema"), requireField(fields, "status"), requireSha256(fields, "wordpressStubsSha256"));
		validateReceipt(receipt, emission, expectedPolicySha256, expectedComposerLockSha256);
		return receipt;
	}

	static function validateReceipt(receipt:PluginPhpQualityReceipt, emission:PluginEmission, expectedPolicySha256:String,
			expectedComposerLockSha256:String):Void {
		var expectedPublic = 0;
		var expectedPrivate = 0;
		for (file in emission.files) {
			if (!StringTools.endsWith(file.relativePath, ".php")) {
				continue;
			}
			if (StringTools.startsWith(file.relativePath, "private/wordpresshx/")) {
				expectedPrivate++;
			} else {
				expectedPublic++;
			}
		}
		final hasPrivate = expectedPrivate > 0;
		final expectedAutoload = hasPrivate ? "authoritative-private-classmap" : "native-require-closure";
		if (receipt.schema != RECEIPT_SCHEMA
			|| receipt.status != "passed"
			|| receipt.policyId != POLICY_ID
			|| receipt.policySha256 != expectedPolicySha256
			|| receipt.composerLockSha256 != expectedComposerLockSha256
			|| receipt.wordpressStubsSha256 != WORDPRESS_STUBS_SHA256
			|| receipt.formatChangedFiles != 0
			|| receipt.phpStanPublicLevel != 6
			|| receipt.phpStanPrivateLevel != (hasPrivate ? 0 : -1)
			|| receipt.autoloadMode != expectedAutoload
			|| receipt.publicPhpFileCount != expectedPublic
			|| receipt.privatePhpFileCount != expectedPrivate
			|| receipt.phpFileCount != expectedPublic + expectedPrivate
			|| (hasPrivate ? receipt.classmapEntries <= 0 : receipt.classmapEntries != 0)) {
			throw invalidReceipt("the PHP quality receipt contradicts the exact emitted plugin or policy");
		}
	}

	static function renderReport(emission:PluginEmission, receipt:PluginPhpQualityReceipt):Buffer {
		final files:Array<JsonValue> = [
			for (file in emission.files)
				ScaffoldJson.object([
					ScaffoldJson.field("lane", ScaffoldJson.text(file.lane.label())),
					ScaffoldJson.field("path", ScaffoldJson.text(file.relativePath)),
					ScaffoldJson.field("role", ScaffoldJson.text(file.role)),
					ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256)),
					ScaffoldJson.field("sizeBytes", ScaffoldJson.number(file.bytes.length))
				])
		];
		final tools:Array<JsonValue> = [
			tool("composer", "2.10.2"),
			tool("php-stubs/wordpress-stubs", "7.0.0"),
			tool("phpcompatibility/phpcompatibility-wp", "2.1.8"),
			tool("phpstan/phpstan", "2.2.5"),
			tool("squizlabs/php_codesniffer", "3.13.5"),
			tool("wp-coding-standards/wpcs", "3.4.0")
		];
		return Buffer.from(ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("schema", ScaffoldJson.text(REPORT_SCHEMA)),
			ScaffoldJson.field("status", ScaffoldJson.text(receipt.status)),
			ScaffoldJson.field("policy", ScaffoldJson.object([
				ScaffoldJson.field("id", ScaffoldJson.text(receipt.policyId)),
				ScaffoldJson.field("sha256", ScaffoldJson.text(receipt.policySha256)),
				ScaffoldJson.field("composerLockSha256", ScaffoldJson.text(receipt.composerLockSha256)),
				ScaffoldJson.field("wordpressStubsSha256", ScaffoldJson.text(receipt.wordpressStubsSha256))
			])),
			ScaffoldJson.field("checks", ScaffoldJson.object([
				ScaffoldJson.field("autoload", ScaffoldJson.text(receipt.autoloadMode)),
				ScaffoldJson.field("classmapEntries", ScaffoldJson.number(receipt.classmapEntries)),
				ScaffoldJson.field("duplicateSymbols", ScaffoldJson.text("none")),
				ScaffoldJson.field("formatChangedFiles", ScaffoldJson.number(receipt.formatChangedFiles)),
				ScaffoldJson.field("phpFileCount", ScaffoldJson.number(receipt.phpFileCount)),
				ScaffoldJson.field("phpStanPrivateLevel", ScaffoldJson.number(receipt.phpStanPrivateLevel)),
				ScaffoldJson.field("phpStanPublicLevel", ScaffoldJson.number(receipt.phpStanPublicLevel)),
				ScaffoldJson.field("privatePhpFileCount", ScaffoldJson.number(receipt.privatePhpFileCount)),
				ScaffoldJson.field("publicPhpFileCount", ScaffoldJson.number(receipt.publicPhpFileCount)),
				ScaffoldJson.field("syntaxFloor", ScaffoldJson.text("7.4.33")),
				ScaffoldJson.field("wordpressCodingStandards", ScaffoldJson.text("passed"))
			])),
			ScaffoldJson.field("tools", ScaffoldJson.array(tools)),
			ScaffoldJson.field("files", ScaffoldJson.array(files))
		]), false), "utf8");
	}

	static function tool(id:String, version:String):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("id", ScaffoldJson.text(id)),
			ScaffoldJson.field("version", ScaffoldJson.text(version))
		]);
	}

	static function policyDigest(policy:Array<PluginPhpQualityPolicyFile>):String {
		var source = "";
		for (file in policy) {
			source += file.relativePath + "\x00" + file.sha256 + "\x00";
		}
		return OwnershipJson.digest(Buffer.from(source, "utf8"));
	}

	static function policyFile(policy:Array<PluginPhpQualityPolicyFile>, relativePath:String):PluginPhpQualityPolicyFile {
		for (file in policy) {
			if (file.relativePath == relativePath) {
				return file;
			}
		}
		throw policyMismatch(relativePath);
	}

	static function requireField(fields:Map<String, String>, name:String):String {
		final value = fields.get(name);
		if (value == null) {
			throw invalidReceipt("the PHP quality receipt omitted field " + name);
		}
		return value;
	}

	static function fieldCount(fields:Map<String, String>):Int {
		var count = 0;
		for (_name in fields.keys()) {
			count++;
		}
		return count;
	}

	static function requireSha256(fields:Map<String, String>, name:String):String {
		final value = requireField(fields, name);
		if (!~/^[0-9a-f]{64}$/.match(value)) {
			throw invalidReceipt("the PHP quality receipt field " + name + " is not a lowercase SHA-256");
		}
		return value;
	}

	static function parseInteger(fields:Map<String, String>, name:String):Int {
		final source = requireField(fields, name);
		if (!~/^(?:0|-?[1-9][0-9]*)$/.match(source)) {
			throw invalidReceipt("the PHP quality receipt field " + name + " is not an integer");
		}
		final value = Std.parseInt(source);
		if (value == null || Std.string(value) != source) {
			throw invalidReceipt("the PHP quality receipt field " + name + " is outside the supported integer range");
		}
		return value;
	}

	static function write(root:String, relativePath:String, bytes:Buffer):Void {
		Content.safeRelativePath(relativePath, "emitted plugin path");
		final absolute = Path.resolve(root, relativePath);
		ensureDirectory(Path.dirname(absolute));
		Fs.writeFileSync(absolute, bytes, {flag: "wx", mode: 0x180});
	}

	static function ensureDirectory(path:String):Void {
		if (Fs.existsSync(path)) {
			return;
		}
		final parent = Path.dirname(path);
		if (parent != path) {
			ensureDirectory(parent);
		}
		Fs.mkdirSync(path, 0x1c0);
	}

	static function removeTemporary(root:String):Void {
		final prefix = Path.join(Os.tmpdir(), TEMPORARY_PREFIX);
		if (!StringTools.startsWith(root, prefix) || !Fs.existsSync(root)) {
			return;
		}
		removeTree(root);
	}

	static function removeTree(path:String):Void {
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || stats.isFile()) {
			Fs.unlinkSync(path);
			return;
		}
		if (!stats.isDirectory()) {
			throw new CliFailure("WPHX3400", "the private PHP quality stage changed to a special file", 70, "format-and-static-check");
		}
		final names = Fs.readdirSync(path);
		names.sort(compareText);
		for (name in names) {
			removeTree(Path.join(path, name));
		}
		Fs.rmdirSync(path);
	}

	static function missingToolBundle():CliFailure {
		return new CliFailure("WPHX3400", "the exact PHP quality bundle is absent beside the wphx executable", 6, "format-and-static-check", null,
			["Restore the complete @wordpress-hx/cli installation and rerun the command."]);
	}

	static function policyMismatch(relativePath:String):CliFailure {
		return new CliFailure("WPHX3400", "the installed PHP quality policy differs from the policy embedded in the CLI", 6, "format-and-static-check",
			TOOL_DIRECTORY + "/" + relativePath, ["Restore the complete @wordpress-hx/cli installation and rerun the command."]);
	}

	static function invalidReceipt(message:String):CliFailure {
		return new CliFailure("WPHX3400", message, 70, "format-and-static-check", null,
			["Restore the exact PHP quality bundle; publication was not attempted."]);
	}

	static function qualityFailure(message:String, context:ProjectContext, toolRoot:String, temporaryRoot:String):CliFailure {
		var redacted = StringTools.replace(message, context.bootstrap.root, "<project-root>");
		redacted = StringTools.replace(redacted, toolRoot, "<php-quality-root>");
		redacted = StringTools.replace(redacted, temporaryRoot, "<private-stage>");
		redacted = StringTools.replace(redacted, "\r", " ");
		redacted = StringTools.replace(redacted, "\n", " | ");
		return new CliFailure("WPHX3400", StringTools.trim(redacted), 6, "format-and-static-check", null, [
			"Fix the reported generated-PHP violation and rerun; no failing generation was published."
		]);
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

private class PluginPhpQualityResource {
	public final relativePath:String;
	public final resourceId:String;

	public function new(relativePath:String, resourceId:String) {
		this.relativePath = relativePath;
		this.resourceId = resourceId;
	}
}

private class PluginPhpQualityPolicyFile {
	public final relativePath:String;
	public final bytes:Buffer;
	public final sha256:String;

	public function new(relativePath:String, bytes:Buffer, sha256:String) {
		this.relativePath = relativePath;
		this.bytes = bytes;
		this.sha256 = sha256;
	}
}

private class PluginPhpQualityReceipt {
	public final autoloadMode:String;
	public final classmapEntries:Int;
	public final composerLockSha256:String;
	public final formatChangedFiles:Int;
	public final phpFileCount:Int;
	public final phpStanPrivateLevel:Int;
	public final phpStanPublicLevel:Int;
	public final policyId:String;
	public final policySha256:String;
	public final privatePhpFileCount:Int;
	public final publicPhpFileCount:Int;
	public final schema:String;
	public final status:String;
	public final wordpressStubsSha256:String;

	public function new(autoloadMode:String, classmapEntries:Int, composerLockSha256:String, formatChangedFiles:Int, phpFileCount:Int,
			phpStanPrivateLevel:Int, phpStanPublicLevel:Int, policyId:String, policySha256:String, privatePhpFileCount:Int, publicPhpFileCount:Int,
			schema:String, status:String, wordpressStubsSha256:String) {
		this.autoloadMode = autoloadMode;
		this.classmapEntries = classmapEntries;
		this.composerLockSha256 = composerLockSha256;
		this.formatChangedFiles = formatChangedFiles;
		this.phpFileCount = phpFileCount;
		this.phpStanPrivateLevel = phpStanPrivateLevel;
		this.phpStanPublicLevel = phpStanPublicLevel;
		this.policyId = policyId;
		this.policySha256 = policySha256;
		this.privatePhpFileCount = privatePhpFileCount;
		this.publicPhpFileCount = publicPhpFileCount;
		this.schema = schema;
		this.status = status;
		this.wordpressStubsSha256 = wordpressStubsSha256;
	}
}
