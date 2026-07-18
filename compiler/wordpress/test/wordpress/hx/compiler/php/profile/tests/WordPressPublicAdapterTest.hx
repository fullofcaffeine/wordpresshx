package wordpress.hx.compiler.php.profile.tests;

import fixtures.AcmeBooksAdapters;
import haxe.Json;
import reflaxe.php.ir.PhpMethod;
import reflaxe.php.ir.PhpProperty;
import reflaxe.php.ir.PhpType;
import reflaxe.php.ir.PhpVisibility;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.compiler.php.profile.WordPressBlockRegistration;
import wordpress.hx.compiler.php.profile.WordPressHookRegistration;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterArtifact;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterFile;
import wordpress.hx.compiler.php.profile.WordPressPublicAdapterPlan;
import wordpress.hx.compiler.php.profile.WordPressPublicExport;
import wordpress.hx.compiler.php.profile.WordPressRestRouteRegistration;
import wordpress.hx.compiler.php.profile.Wp70PublicAdapterProfile;

class WordPressPublicAdapterTest {
	static final EXPECTED_ROOT = "test/expected/acme-books-adapters";
	static final BUILD_ROOT = "build/acme-books-adapters";

	public static function run():Void {
		final profile = new Wp70PublicAdapterProfile();
		final first = profile.emitPlugin(AcmeBooksAdapters.plan());
		final second = profile.emitPlugin(AcmeBooksAdapters.plan());
		assertArtifactsEqual(first, second);
		writeArtifact(first);
		assertSnapshots(first);
		assertPublicShapes(first);
		assertManifest(first);
		assertNegativePlans(profile);
	}

	static function assertArtifactsEqual(first:WordPressPublicAdapterArtifact, second:WordPressPublicAdapterArtifact):Void {
		assertEquals(first.manifestSource(), second.manifestSource(), "deterministic adapter manifest");
		assertEquals(Std.string(first.files.length), Std.string(second.files.length), "deterministic adapter file count");
		for (index in 0...first.files.length) {
			assertEquals(first.files[index].path, second.files[index].path, "deterministic adapter file path");
			assertEquals(first.files[index].source, second.files[index].source, "deterministic adapter PHP bytes");
		}
	}

	static function writeArtifact(artifact:WordPressPublicAdapterArtifact):Void {
		ensureDirectory(BUILD_ROOT);
		for (file in artifact.files) {
			final destination = BUILD_ROOT + "/" + file.path;
			ensureParent(destination);
			File.saveContent(destination, file.source);
		}
		File.saveContent(BUILD_ROOT + "/wordpresshx-public-php-adapters.v1.json", artifact.manifestSource());
	}

	static function assertSnapshots(artifact:WordPressPublicAdapterArtifact):Void {
		for (file in artifact.files) {
			assertEquals(File.getContent(EXPECTED_ROOT + "/" + file.path + ".txt"), file.source, "adapter snapshot " + file.path);
		}
		assertEquals(File.getContent(EXPECTED_ROOT + "/wordpresshx-public-php-adapters.v1.json"), artifact.manifestSource(), "adapter manifest snapshot");
	}

	static function assertPublicShapes(artifact:WordPressPublicAdapterArtifact):Void {
		final adapter = artifact.file("includes/PublicAdapters.php").source;
		final registrations = artifact.file("includes/register-adapters.php").source;
		for (required in [
			"public static function filterTitle(string $title, int $postId): string",
			"public static function restBook(\\WP_REST_Request $request)",
			"public static function renderSummary(array $attributes, string $content, \\WP_Block $block): string",
			"public static function appendLabel(array &$labels, string $label): void",
			"private static function bookPayload(int $id)",
			"return new \\WP_REST_Response( $payload, 200 );",
			"return new \\WP_Error( 'acme_books_invalid_id'"
		]) {
			if (adapter.indexOf(required) == -1) {
				throw "adapter class is missing native ABI shape: " + required;
			}
		}
		for (required in [
			"\\add_action( 'init', array( \\Acme\\BooksAdapters\\PublicAdapters::class, 'onInit' ), 9, 0 );",
			"\\add_filter( 'the_title', array( \\Acme\\BooksAdapters\\PublicAdapters::class, 'filterTitle' ), 12, 2 );",
			"\\add_action( 'rest_api_init', array( \\Acme\\BooksAdapters\\PublicAdapters::class, 'registerRestRoutes' ), 10, 0 );",
			"\\add_action( 'init', array( \\Acme\\BooksAdapters\\PublicAdapters::class, 'registerBlocks' ), 10, 0 );"
		]) {
			if (registrations.indexOf(required) == -1) {
				throw "registration file is missing native WordPress shape: " + required;
			}
		}
		for (forbidden in ["RawPhp", "PhpSegment", "HaxeBoot", "haxe.root", "wordpresshx-port", "ServerHxx"]) {
			for (file in artifact.files) {
				if (file.source.indexOf(forbidden) != -1) {
					throw "adapter artifact leaked forbidden public shape: " + forbidden;
				}
			}
		}
	}

	static function assertManifest(artifact:WordPressPublicAdapterArtifact):Void {
		final manifest:Dynamic = Json.parse(artifact.manifestSource());
		assertEquals("wordpresshx-public-php-adapters-v1", manifest.manifestId, "adapter manifest identity");
		assertEquals("5", Std.string((cast manifest.files : Array<Dynamic>).length), "adapter manifest file count");
		assertEquals("2", Std.string((cast manifest.hooks : Array<Dynamic>).length), "adapter manifest hook count");
		assertEquals("1", Std.string((cast manifest.restRoutes : Array<Dynamic>).length), "adapter manifest REST route count");
		assertEquals("1", Std.string((cast manifest.blocks : Array<Dynamic>).length), "adapter manifest block count");
		assertEquals("3", Std.string((cast manifest.publicExports : Array<Dynamic>).length), "adapter manifest export count");
		assertEquals("2", Std.string(manifest.boundary.privateImplementationMethods), "private implementation method count");
	}

	static function assertNegativePlans(profile:Wp70PublicAdapterProfile):Void {
		final valid = AcmeBooksAdapters.plan();
		assertThrows(() -> profile.emitPlugin(null), "missing adapter plan");
		assertThrows(() -> new WordPressPublicAdapterPlan(valid.plugin, AcmeBooksAdapters.id("bootstrap"), valid.source, valid.properties, valid.methods,
			valid.hooks, valid.restRoutes, valid.blocks, valid.exports),
			"case-insensitive bootstrap collision");
		assertThrows(() -> new WordPressPublicAdapterPlan(valid.plugin, AcmeBooksAdapters.id("Autoload"), valid.source, valid.properties, valid.methods,
			valid.hooks, valid.restRoutes, valid.blocks, valid.exports),
			"case-insensitive autoload collision");
		assertThrows(() -> new WordPressHookRegistration(Action, "bad hook", AcmeBooksAdapters.id("onInit"), 10, 0), "unsafe hook name");
		assertThrows(() -> new WordPressHookRegistration(Action, "init", AcmeBooksAdapters.id("onInit"), 10, -1), "negative accepted args");
		assertThrows(() -> new WordPressRestRouteRegistration("Bad/v1", "/books", Readable, AcmeBooksAdapters.id("restBook"),
			AcmeBooksAdapters.id("restPermission")),
			"unsafe REST namespace");
		assertThrows(() -> new WordPressRestRouteRegistration("acme-books/v1", "/bad route", Readable, AcmeBooksAdapters.id("restBook"),
			AcmeBooksAdapters.id("restPermission")),
			"unsafe REST route");
		assertThrows(() -> new WordPressBlockRegistration("Bad/summary", AcmeBooksAdapters.id("renderSummary")), "unsafe block name");

		assertThrows(() -> rebuild(valid, null, null, [
			new WordPressHookRegistration(Action, "init", AcmeBooksAdapters.id("onInit"), 9, 1)
		]), "hook accepted args mismatch");
		assertThrows(() -> rebuild(valid, null, null, null, [
			new WordPressRestRouteRegistration("acme-books/v1", "/books/(?P<id>[\\d]+)", Readable, AcmeBooksAdapters.id("restBook"),
				AcmeBooksAdapters.id("missingPermission"))
		]), "missing REST permission callback");
		assertThrows(() -> rebuild(valid, null, null, null, [
			valid.restRoutes[0],
			new WordPressRestRouteRegistration("acme-books/v1", "/books/(?P<id>[\\d]+)", Readable, AcmeBooksAdapters.id("restBook"),
				AcmeBooksAdapters.id("restPermission"))
		]), "duplicate REST route");
		assertThrows(() -> rebuild(valid, null, null, null, null, null, [valid.exports[0], new WordPressPublicExport(AcmeBooksAdapters.id("appendLabel"))]),
			"duplicate public export");

		final duplicateMethods = valid.methods;
		duplicateMethods.push(method("NORMALIZETITLE", PhpPublic, true, [], PhpStringType));
		assertThrows(() -> rebuild(valid, null, duplicateMethods), "case-insensitive duplicate method");
		final reservedMethods = valid.methods;
		reservedMethods.push(method("registerRestRoutes", PhpPublic, true, [], PhpVoidType));
		assertThrows(() -> rebuild(valid, null, reservedMethods), "reserved registration method");
		assertThrows(() -> rebuild(valid, [new PhpProperty(PhpPublic, true, AcmeBooksAdapters.id("leaked"))]), "public adapter property");

		final badActionMethods = replaceMethod(valid.methods, "onInit", method("onInit", PhpPublic, true, [], PhpBoolType));
		assertThrows(() -> rebuild(valid, null, badActionMethods), "non-void action callback");
		final badFilterMethods = replaceMethod(valid.methods, "filterTitle", method("filterTitle", PhpPublic, true, [
			AcmeBooksAdapters.parameter("title", PhpStringType),
			AcmeBooksAdapters.parameter("postId", PhpIntType)
		], PhpVoidType));
		assertThrows(() -> rebuild(valid, null, badFilterMethods), "void filter callback");
		final badRestMethods = replaceMethod(valid.methods, "restBook",
			method("restBook", PhpPublic, true, [AcmeBooksAdapters.parameter("request", PhpStringType)], PhpStringType));
		assertThrows(() -> rebuild(valid, null, badRestMethods), "wrong REST callback request type");
		final badPermissionMethods = replaceMethod(valid.methods, "restPermission", method("restPermission", PhpPublic, true, [
			AcmeBooksAdapters.parameter("request", AcmeBooksAdapters.namedType("\\WP_REST_Request"))
		], PhpStringType));
		assertThrows(() -> rebuild(valid, null, badPermissionMethods), "wrong REST permission return type");
		final badBlockMethods = replaceMethod(valid.methods, "renderSummary", method("renderSummary", PhpPublic, true, [
			AcmeBooksAdapters.parameter("attributes", PhpArrayType),
			AcmeBooksAdapters.parameter("content", PhpStringType),
			AcmeBooksAdapters.parameter("block", PhpObjectType)
		], PhpStringType));
		assertThrows(() -> rebuild(valid, null, badBlockMethods), "wrong block callback type");
		final nonStaticMethods = replaceMethod(valid.methods, "normalizeTitle",
			method("normalizeTitle", PhpPublic, false, [AcmeBooksAdapters.parameter("title", PhpStringType)], PhpStringType));
		assertThrows(() -> rebuild(valid, null, nonStaticMethods), "non-static public export");

		final emitted = profile.emitPlugin(valid);
		assertThrows(() -> new WordPressPublicAdapterArtifact(valid, [
			new WordPressPublicAdapterFile("autoload", emitted.file(valid.plugin.rootPath).rendered),
			new WordPressPublicAdapterFile("plugin-root", emitted.file(valid.plugin.autoloadPath).rendered),
			emitted.file(valid.plugin.bootstrapPath),
			emitted.file(valid.adapterPath),
			emitted.file(valid.registrationPath)
		]), "adapter artifact role/path swap");
		final callerFiles = emitted.files;
		callerFiles.pop();
		if (emitted.files.length != 5) {
			throw "adapter artifact file inventory was mutable through its getter";
		}
		final callerMethods = valid.methods;
		callerMethods.pop();
		if (valid.methods.length != 10) {
			throw "adapter method inventory was mutable through its getter";
		}
	}

	static function rebuild(valid:WordPressPublicAdapterPlan, ?properties:Array<PhpProperty>, ?methods:Array<PhpMethod>,
			?hooks:Array<WordPressHookRegistration>, ?restRoutes:Array<WordPressRestRouteRegistration>, ?blocks:Array<WordPressBlockRegistration>,
			?exports:Array<WordPressPublicExport>):WordPressPublicAdapterPlan {
		return new WordPressPublicAdapterPlan(valid.plugin, valid.className, valid.source, properties == null ? valid.properties : properties,
			methods == null ? valid.methods : methods, hooks == null ? valid.hooks : hooks, restRoutes == null ? valid.restRoutes : restRoutes,
			blocks == null ? valid.blocks : blocks, exports == null ? valid.exports : exports);
	}

	static function replaceMethod(methods:Array<PhpMethod>, name:String, replacement:PhpMethod):Array<PhpMethod> {
		return methods.map(method -> method.name.value == name ? replacement : method);
	}

	static function method(name:String, visibility:PhpVisibility, isStatic:Bool, parameters:Array<reflaxe.php.ir.PhpParameter>, returnType:PhpType):PhpMethod {
		return new PhpMethod(visibility, isStatic, false, AcmeBooksAdapters.id(name), parameters, AcmeBooksAdapters.source(), returnType, []);
	}

	static function ensureParent(path:String):Void {
		final separator = path.lastIndexOf("/");
		if (separator > 0) {
			ensureDirectory(path.substr(0, separator));
		}
	}

	static function ensureDirectory(path:String):Void {
		if (FileSystem.exists(path)) {
			return;
		}
		final separator = path.lastIndexOf("/");
		if (separator > 0) {
			ensureDirectory(path.substr(0, separator));
		}
		FileSystem.createDirectory(path);
	}

	static function assertEquals(expected:String, actual:String, label:String):Void {
		if (expected != actual) {
			throw label + " mismatch\nexpected:\n" + expected + "\nactual:\n" + actual;
		}
	}

	static function assertThrows(run:() -> Dynamic, label:String):Void {
		var threw = false;
		try {
			run();
		} catch (_:Dynamic) {
			threw = true;
		}
		if (!threw) {
			throw label + " did not fail closed";
		}
	}
}
