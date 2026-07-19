package wordpresshx.cli.project;

import js.lib.Error;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.ChildProcess.ChildProcessSpawnSyncResult;
import js.node.Fs;
import js.node.Os;
import js.node.Path;
import reflaxe.php.ir.PhpArrayEntry;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.print.PhpPrinter;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.Content;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.scaffold.ScaffoldJson;

private typedef PluginStockPhpFile = {
	final relativePath:String;
	final source:String;
	final sha256:String;
	final sizeBytes:Int;
}

/** Compile and audit one stock-Haxe closure behind its native adapter edge. */
class PluginPrivateRuntimeCompiler {
	static inline final TEMPORARY_PREFIX = "wordpresshx-private-php-";
	static inline final ENTRY_CLASS = "wordpresshx.privateentry.Entry";
	static inline final ENTRY_PATH = "wordpresshx/privateentry/Entry.hx";
	static inline final API_PATH = "wordpresshx/WordPress.hx";
	static inline final POLYFILL_SHA256 = "80f6c2172d93b501328e2c4fa131b81a186ff850e6a437e9068f9e842a6b3237";
	static inline final POLYFILL_CONSTANT = "WORDPRESSHX_PRIVATE_POLYFILLS_V1_SHA256";
	static inline final PRIVATE_REVIEW_MAX_BYTES = 163840;
	static final PHP_CLASS = ~/^[A-Za-z_][A-Za-z0-9_]*(?:\\[A-Za-z_][A-Za-z0-9_]*)*$/;
	static final EXPECTED_POLYFILLS = ["mb_chr", "mb_ord", "mb_scrub", "str_starts_with"];

	public static function compile(context:ProjectContext, plan:PluginPlan, callback:PluginPrivateTitleFilter):PluginPrivateRuntime {
		assertNoEntryShadow(context);
		final identity = PluginPrivateRuntimeIdentity.derive(plan);
		final temporaryRoot = Fs.mkdtempSync(Path.join(Os.tmpdir(), TEMPORARY_PREFIX));
		try {
			final sourceRoot = Path.join(temporaryRoot, "source");
			writeNew(sourceRoot, API_PATH, PluginMacroRuntime.projectApiSource());
			writeNew(sourceRoot, ENTRY_PATH, entrySource(callback));
			final outputRoot = Path.join(temporaryRoot, "output");
			compileStock(context, plan, identity, sourceRoot, outputRoot, temporaryRoot);
			final runtime = packageOutput(context, plan, callback, identity, outputRoot);
			removeTemporary(temporaryRoot);
			return runtime;
		} catch (failure:haxe.Exception) {
			removeTemporary(temporaryRoot);
			throw failure;
		} catch (failure:Error) {
			removeTemporary(temporaryRoot);
			throw failure;
		}
	}

	static function compileStock(context:ProjectContext, plan:PluginPlan, identity:PluginPrivateRuntimeIdentity, sourceRoot:String, outputRoot:String,
			temporaryRoot:String):Void {
		final version = CompilerRunner.version("haxe");
		if (version != "4.3.7") {
			invalid("private PHP compilation requires the authenticated Haxe 4.3.7 compiler");
		}
		final arguments = ["-cp", sourceRoot];
		for (root in context.bootstrap.sourceRoots) {
			arguments.push("-cp");
			arguments.push(root);
		}
		arguments.push("-main");
		arguments.push(ENTRY_CLASS);
		arguments.push("-php");
		arguments.push(outputRoot);
		for (define in [
			"wordpress-hx-project-id=" + plan.slug,
			"wordpress-hx-profile=" + plan.profile,
			"wordpress-hx-plan-output=" + Path.join(temporaryRoot, "private-plugin-plan.json"),
			"php-prefix=" + identity.prefix,
			"php-front=stock-front.php",
			"php-lib=runtime",
			"real-position"
		]) {
			arguments.push("-D");
			arguments.push(define);
		}
		arguments.push("-dce");
		arguments.push("full");
		final result:ChildProcessSpawnSyncResult = ChildProcess.spawnSync("haxe", arguments, {
			cwd: context.bootstrap.root,
			encoding: "utf8",
			timeout: 120000,
			stdio: ["ignore", "pipe", "pipe"]
		});
		if (result.error != null) {
			invalid("could not start the exact Haxe compiler for the private PHP closure");
		}
		if (result.status != 0) {
			final transcript = StringTools.trim(Std.string(result.stdout) + Std.string(result.stderr));
			final redacted = StringTools.replace(transcript, context.bootstrap.root + "/", "");
			invalid(redacted.length == 0 ? "private PHP typing failed" : redacted);
		}
	}

	static function packageOutput(context:ProjectContext, plan:PluginPlan, callback:PluginPrivateTitleFilter, identity:PluginPrivateRuntimeIdentity,
			outputRoot:String):PluginPrivateRuntime {
		requireDirectory(outputRoot, "stock Haxe output");
		final topLevel = Fs.readdirSync(outputRoot);
		topLevel.sort(compareText);
		if (topLevel.join("\n") != "runtime\nstock-front.php") {
			invalid("stock Haxe output inventory changed outside its front/runtime split");
		}
		final frontPath = Path.join(outputRoot, "stock-front.php");
		final front = readTextFile(frontPath, "stock Haxe front controller");
		for (hazard in ["set_include_path", "stream_resolve_include_path", "spl_autoload_register"]) {
			if (front.source.indexOf(hazard) < 0) {
				invalid("stock Haxe front controller no longer exposes the audited ownership hazard " + hazard);
			}
		}
		final runtimeRoot = Path.join(outputRoot, "runtime");
		requireDirectory(runtimeRoot, "stock Haxe runtime");
		final stockFiles = readTree(runtimeRoot);
		final entryRelative = identity.prefixPath + "/" + ENTRY_CLASS.split(".").join("/") + ".php";
		final callbackRelative = identity.prefixPath + "/" + callback.className.split(".").join("/") + ".php";
		var entryObserved = false;
		var callbackObserved = false;
		var polyfillRelative:Null<String> = null;
		var polyfillSha256:Null<String> = null;
		final packaged:Array<PluginStockPhpFile> = [];
		final classmap = new Map<String, String>();
		for (file in stockFiles) {
			validateNoLocalPath(context, file);
			if (file.relativePath == entryRelative) {
				entryObserved = true;
				continue;
			}
			if (file.relativePath == callbackRelative) {
				callbackObserved = true;
				if (file.source.indexOf("function " + callback.methodName + " (") < 0) {
					invalid("stock Haxe omitted the compiler-resolved private callback method");
				}
			}
			if (StringTools.endsWith(file.relativePath, "/_polyfills.php")) {
				if (polyfillRelative != null) {
					invalid("stock Haxe emitted more than one global polyfill file");
				}
				polyfillRelative = file.relativePath;
				polyfillSha256 = validatePolyfills(file);
				packaged.push(file);
				continue;
			}
			if (!StringTools.startsWith(file.relativePath, identity.prefixPath + "/")) {
				invalid("stock Haxe runtime file escaped the derived private prefix: " + file.relativePath);
			}
			final className = file.relativePath.substr(0, file.relativePath.length - 4).split("/").join("\\");
			if (!PHP_CLASS.match(className) || classmap.exists(className)) {
				invalid("stock Haxe emitted an invalid or duplicate private class identity: " + className);
			}
			validateDeclaration(file, className);
			classmap.set(className, file.relativePath);
			packaged.push(file);
		}
		if (!entryObserved || !callbackObserved || polyfillRelative == null || polyfillSha256 == null || classmap.keys().hasNext() == false) {
			invalid("private PHP closure omitted its derived entry, callback, class map, or admitted polyfill");
		}
		for (file in packaged) {
			validateReferences(file, identity, classmap);
		}
		final privateClass = identity.phpClass(callback.className);
		if (!classmap.exists(privateClass)) {
			invalid("compiler-resolved private callback is absent from the authoritative class map");
		}
		final classmapSource = classmapSource(classmap);
		final runtimeFiles = [
			for (file in packaged)
				new PluginEmittedFile(PrivateRuntime, "private-runtime/" + file.relativePath, "private/wordpresshx/runtime/" + file.relativePath, file.source)
		];
		final classmapFile = new PluginEmittedFile(PrivateClassmap, "private-classmap", "private/wordpresshx/classmap.php", classmapSource);
		var privatePhpBytes = classmapFile.bytes.length;
		for (file in runtimeFiles) {
			privatePhpBytes += file.bytes.length;
		}
		final privatePhpFileCount = runtimeFiles.length + 1;
		if (privatePhpBytes > PRIVATE_REVIEW_MAX_BYTES) {
			invalid("private PHP closure exceeds the ADR-018 160 KiB review threshold: " + privatePhpBytes + " bytes");
		}
		final manifestSource = manifest(plan, callback, identity, privateClass, front.sha256, polyfillRelative, polyfillSha256, packaged, classmapFile,
			classmap, privatePhpFileCount, privatePhpBytes);
		final files = runtimeFiles.concat([
			classmapFile,
			new PluginEmittedFile(PrivateManifest, "private-runtime-manifest", "private/wordpresshx/runtime-manifest.v1.json", manifestSource)
		]);
		return new PluginPrivateRuntime(identity, privateClass, polyfillSha256, front.sha256, countKeys(classmap), privatePhpFileCount, privatePhpBytes, files);
	}

	static function classmapSource(classmap:Map<String, String>):String {
		final names = [for (name in classmap.keys()) name];
		names.sort(compareText);
		final entries:Array<PhpArrayEntry> = [
			for (name in names)
				{
					key: PhpString(name),
					value: PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/runtime/" + requiredMapValue(classmap, name)))
				}
		];
		return new PhpPrinter().printFile(new PhpFile("private/wordpresshx/classmap.php", null, true, [], [PhpReturn(PhpLongArray(entries))])).source;
	}

	static function manifest(plan:PluginPlan, callback:PluginPrivateTitleFilter, identity:PluginPrivateRuntimeIdentity, privateClass:String,
			frontSha256:String, polyfillRelative:String, polyfillSha256:String, runtimeFiles:Array<PluginStockPhpFile>, classmapFile:PluginEmittedFile,
			classmap:Map<String, String>, privatePhpFileCount:Int, privatePhpBytes:Int):String {
		final inventory:Array<JsonValue> = [];
		for (file in runtimeFiles) {
			final isCallback = file.relativePath == identity.prefixPath + "/" + callback.className.split(".").join("/") + ".php";
			final isPolyfill = file.relativePath == polyfillRelative;
			inventory.push(ScaffoldJson.object([
				ScaffoldJson.field("bytes", ScaffoldJson.number(file.sizeBytes)),
				ScaffoldJson.field("componentIds",
					ScaffoldJson.array(isCallback ? [
						ScaffoldJson.text("project-private-haxe"),
						ScaffoldJson.text("haxe-4.3.7-stdlib")
					] : [ScaffoldJson.text("haxe-4.3.7-stdlib")])),
				ScaffoldJson.field("licenseExpression", ScaffoldJson.text(isCallback ? plan.license : "MIT")),
				ScaffoldJson.field("path", ScaffoldJson.text("private/wordpresshx/runtime/" + file.relativePath)),
				ScaffoldJson.field("reason",
					ScaffoldJson.text(isCallback ? "typed-private-callback-root" : isPolyfill ? "guarded-global-polyfill" : "stock-haxe-private-dependency-closure")),
				ScaffoldJson.field("sha256", ScaffoldJson.text(file.sha256))
			]));
		}
		return ScaffoldJson.document(ScaffoldJson.object([
			ScaffoldJson.field("autoload", ScaffoldJson.object([
				ScaffoldJson.field("classCount", ScaffoldJson.number(countKeys(classmap))),
				ScaffoldJson.field("classmapPath", ScaffoldJson.text(classmapFile.relativePath)),
				ScaffoldJson.field("classmapSha256", ScaffoldJson.text(classmapFile.sha256)),
				ScaffoldJson.field("mechanism", ScaffoldJson.text("package-local-authoritative-classmap")),
				ScaffoldJson.field("processIncludePathMutation", ScaffoldJson.boolean(false)),
				ScaffoldJson.field("rootPath", ScaffoldJson.text("includes/autoload.php"))
			])),
			ScaffoldJson.field("compiler", ScaffoldJson.object([
				ScaffoldJson.field("dce", ScaffoldJson.text("full-derived-single-callback-entry")),
				ScaffoldJson.field("haxeVersion", ScaffoldJson.text("4.3.7")),
				ScaffoldJson.field("positionMode", ScaffoldJson.text("real-position-no-local-paths")),
				ScaffoldJson.field("target", ScaffoldJson.text("php"))
			])),
			ScaffoldJson.field("composer", ScaffoldJson.object([
				ScaffoldJson.field("lockPath", NullValue),
				ScaffoldJson.field("manifestPath", NullValue),
				ScaffoldJson.field("runtimePackages", ScaffoldJson.array([])),
				ScaffoldJson.field("status", ScaffoldJson.text("absent-no-runtime-dependencies")),
				ScaffoldJson.field("vendorPath", NullValue)
			])),
			ScaffoldJson.field("evidence", ScaffoldJson.object([
				ScaffoldJson.field("architectureReceipt", ScaffoldJson.text("ADR-018-RUNTIME-SUPPORT-PACKAGING")),
				ScaffoldJson.field("productionIntegration", ScaffoldJson.text("sdk-024-production-path"))
			])),
			ScaffoldJson.field("globalPolyfill",
				ScaffoldJson.object([
					ScaffoldJson.field("compatibilityConstant", ScaffoldJson.text(POLYFILL_CONSTANT)),
					ScaffoldJson.field("differentHashDisposition", ScaffoldJson.text("reject-private-boot-WPHX5201")),
					ScaffoldJson.field("functions", ScaffoldJson.array([for (name in EXPECTED_POLYFILLS) ScaffoldJson.text(name)])),
					ScaffoldJson.field("path", ScaffoldJson.text("private/wordpresshx/runtime/" + polyfillRelative)),
					ScaffoldJson.field("sha256", ScaffoldJson.text(polyfillSha256))
				])),
			ScaffoldJson.field("moduleId", ScaffoldJson.text(identity.moduleId)),
			ScaffoldJson.field("packageVersion", ScaffoldJson.text(plan.version)),
			ScaffoldJson.field("privateClosure", ScaffoldJson.object([
				ScaffoldJson.field("entryClass", ScaffoldJson.text(privateClass)),
				ScaffoldJson.field("files", ScaffoldJson.array(inventory)),
				ScaffoldJson.field("privatePhpBytes", ScaffoldJson.number(privatePhpBytes)),
				ScaffoldJson.field("privatePhpFileCount", ScaffoldJson.number(privatePhpFileCount))
			])),
			ScaffoldJson.field("privateNamespace", ScaffoldJson.object([
				ScaffoldJson.field("canonicalSchema", ScaffoldJson.text(PluginPrivateRuntimeIdentity.SCHEMA)),
				ScaffoldJson.field("derivationSha256", ScaffoldJson.text(identity.derivationSha256)),
				ScaffoldJson.field("digestBitsRetained", ScaffoldJson.number(96)),
				ScaffoldJson.field("haxeDefine", ScaffoldJson.text("php-prefix")),
				ScaffoldJson.field("value", ScaffoldJson.text(identity.prefix))
			])),
			ScaffoldJson.field("projectId", ScaffoldJson.text(identity.projectId)),
			ScaffoldJson.field("publicBoundary", ScaffoldJson.object([
				ScaffoldJson.field("adapterClass", ScaffoldJson.text(plan.namespace + "\\PrivateBridge")),
				ScaffoldJson.field("adapterMethod", ScaffoldJson.text("filterTitle(string,int):string")),
				ScaffoldJson.field("privateNamesAllowedInPublicAbi", ScaffoldJson.boolean(false)),
				ScaffoldJson.field("wordPressCallback", ScaffoldJson.text(plan.namespace + "\\PrivateBridge::filterTitle"))
			])),
			ScaffoldJson.field("sbom",
				ScaffoldJson.object([
					ScaffoldJson.field("components",
						ScaffoldJson.array([
							component("haxe-4.3.7-stdlib", "MIT", "pending-qualified-review"),
							component("project-private-haxe", plan.license, "project-declared"),
							component("repository-original-work", "LicenseRef-No-License-Grant", "pending-qualified-review")
						])),
					ScaffoldJson.field("publicationBlocked", ScaffoldJson.boolean(true)),
					ScaffoldJson.field("status", ScaffoldJson.text("artifact-inventoried-qualified-review-required"))
				])),
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.private-runtime-manifest.v1")),
			ScaffoldJson.field("stockFrontController", ScaffoldJson.object([
				ScaffoldJson.field("packaged", ScaffoldJson.boolean(false)),
				ScaffoldJson.field("reason", ScaffoldJson.text("process-global-include-path-and-unbounded-resolver")),
				ScaffoldJson.field("sha256", ScaffoldJson.text(frontSha256))
			]))
		]), true);
	}

	static function component(id:String, licenseExpression:String, review:String):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("id", ScaffoldJson.text(id)),
			ScaffoldJson.field("licenseExpression", ScaffoldJson.text(licenseExpression)),
			ScaffoldJson.field("review", ScaffoldJson.text(review))
		]);
	}

	static function validatePolyfills(file:PluginStockPhpFile):String {
		if (file.sha256 != POLYFILL_SHA256) {
			invalid("stock Haxe global polyfill digest is not admitted: " + file.sha256);
		}
		final functions:Array<String> = [];
		final pattern = ~/\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
		var offset = 0;
		while (pattern.matchSub(file.source, offset)) {
			functions.push(pattern.matched(1));
			final position = pattern.matchedPos();
			offset = position.pos + position.len;
		}
		if (functions.join("\n") != EXPECTED_POLYFILLS.join("\n")) {
			invalid("stock Haxe global polyfill function inventory changed");
		}
		return file.sha256;
	}

	static function validateDeclaration(file:PluginStockPhpFile, className:String):Void {
		final parts = className.split("\\");
		final name = parts.pop();
		final namespace = parts.join("\\");
		if (name == null
			|| file.source.indexOf("namespace " + namespace + ";") < 0
			|| !new EReg("\\b(?:class|interface|trait)\\s+" + name + "\\b", "").match(file.source)) {
			invalid("stock Haxe file does not declare its path-derived private class: " + file.relativePath);
		}
	}

	static function validateReferences(file:PluginStockPhpFile, identity:PluginPrivateRuntimeIdentity, classmap:Map<String, String>):Void {
		final privatePrefix = identity.prefix.split(".").join("\\") + "\\";
		final absoluteNeedle = "\\" + privatePrefix;
		var offset = 0;
		while (true) {
			final start = file.source.indexOf(absoluteNeedle, offset);
			if (start < 0) {
				break;
			}
			var end = start + 1;
			while (end < file.source.length && isClassCharacter(file.source.charCodeAt(end))) {
				end++;
			}
			final reference = file.source.substr(start + 1, end - start - 1);
			if (!classmap.exists(reference)) {
				invalid("private PHP closure references a class outside its authoritative map: " + reference);
			}
			offset = end;
		}
	}

	static function isClassCharacter(code:Int):Bool {
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 92 || code == 95;
	}

	static function validateNoLocalPath(context:ProjectContext, file:PluginStockPhpFile):Void {
		if (file.source.indexOf(context.bootstrap.root) >= 0) {
			invalid("private PHP output leaked the local checkout path: " + file.relativePath);
		}
		for (hazard in ["set_include_path", "stream_resolve_include_path"]) {
			if (file.source.indexOf(hazard) >= 0) {
				invalid("private PHP runtime retained a process-global loader hazard: " + hazard);
			}
		}
	}

	static function readTree(root:String):Array<PluginStockPhpFile> {
		final paths:Array<String> = [];
		collectFiles(root, "", paths);
		paths.sort(compareText);
		final result:Array<PluginStockPhpFile> = [];
		for (relative in paths) {
			if (!StringTools.endsWith(relative, ".php")) {
				invalid("stock Haxe runtime emitted a non-PHP file: " + relative);
			}
			final file = readTextFile(Path.join(root, relative), "stock Haxe runtime file");
			result.push({
				relativePath: relative,
				source: file.source,
				sha256: file.sha256,
				sizeBytes: file.sizeBytes
			});
		}
		return result;
	}

	static function collectFiles(root:String, relative:String, paths:Array<String>):Void {
		final absolute = relative.length == 0 ? root : Path.join(root, relative);
		final stats = Fs.lstatSync(absolute);
		if (stats.isSymbolicLink()) {
			invalid("stock Haxe output contains a symbolic link");
		}
		if (stats.isFile()) {
			paths.push(relative);
			return;
		}
		if (!stats.isDirectory()) {
			invalid("stock Haxe output contains a special filesystem entry");
		}
		final names = Fs.readdirSync(absolute);
		names.sort(compareText);
		for (name in names) {
			collectFiles(root, relative.length == 0 ? name : relative + "/" + name, paths);
		}
	}

	static function readTextFile(path:String, label:String):{source:String, sha256:String, sizeBytes:Int} {
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || !stats.isFile()) {
			invalid(label + " is not a regular file");
		}
		final bytes = Fs.readFileSync(path);
		final source = bytes.toString("utf8");
		if (Buffer.compareBuffers(bytes, Buffer.from(source, "utf8")) != 0) {
			invalid(label + " is not canonical UTF-8");
		}
		return {source: source, sha256: wordpresshx.cli.ownership.OwnershipJson.digest(bytes), sizeBytes: bytes.length};
	}

	static function entrySource(callback:PluginPrivateTitleFilter):String {
		return "package wordpresshx.privateentry;\n\n"
			+ "/** Compiler-owned reachability root; the generated PHP file is discarded. */\n"
			+ "final class Entry {\n"
			+ "\tpublic static function main():Void {\n"
			+ "\t\t"
			+ callback.className
			+ "."
			+ callback.methodName
			+ "(\"\", 0);\n"
			+ "\t}\n"
			+ "}\n";
	}

	static function assertNoEntryShadow(context:ProjectContext):Void {
		for (root in context.bootstrap.sourceRoots) {
			final relative = root + "/" + ENTRY_PATH;
			if (Fs.existsSync(Path.resolve(context.bootstrap.root, relative))) {
				invalid("project source collides with the compiler-owned private entry: " + relative);
			}
		}
	}

	static function writeNew(root:String, relative:String, source:String):Void {
		final absolute = Path.join(root, relative);
		ensureDirectory(Path.dirname(absolute));
		Fs.writeFileSync(absolute, source, {flag: "wx", mode: 0x1a4});
	}

	static function requireDirectory(path:String, label:String):Void {
		if (!Fs.existsSync(path)) {
			invalid(label + " is missing");
		}
		final stats = Fs.lstatSync(path);
		if (stats.isSymbolicLink() || !stats.isDirectory()) {
			invalid(label + " is not a regular directory");
		}
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
		final expectedPrefix = Path.join(Os.tmpdir(), TEMPORARY_PREFIX);
		if (!StringTools.startsWith(root, expectedPrefix) || !Fs.existsSync(root)) {
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
			invalid("private compiler directory changed to a special file");
		}
		final names = Fs.readdirSync(path);
		names.sort(compareText);
		for (name in names) {
			removeTree(Path.join(path, name));
		}
		Fs.rmdirSync(path);
	}

	static function countKeys<T>(values:Map<String, T>):Int {
		var count = 0;
		for (_ in values.keys()) {
			count++;
		}
		return count;
	}

	static function requiredMapValue(values:Map<String, String>, key:String):String {
		final value = values.get(key);
		if (value == null) {
			return invalid("private class map lost a compiler-produced entry");
		}
		return value;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX5200", message, 6, "private-php-emission", null, [
			"Keep the callback as a public static Haxe method with native String/Int inputs and String output, then rebuild.",
			"If the bounded stock closure changed, migrate the behavior to the native compiler instead of weakening isolation."
		]);
	}
}
