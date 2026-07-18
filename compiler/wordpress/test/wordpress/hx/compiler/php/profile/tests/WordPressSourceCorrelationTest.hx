package wordpress.hx.compiler.php.profile.tests;

import fixtures.SourceCorrelationFixture;
import haxe.Json;
import haxe.crypto.Sha256;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.compiler.php.profile.WordPressPhpRangeMapWriter;
import wordpress.hx.compiler.php.profile.WordPressPhpSourceIndexWriter;
import wordpress.hx.compiler.php.profile.Wp70PublicAdapterProfile;

/** SDK projection of exact compiler mappings onto a representative native adapter. **/
class WordPressSourceCorrelationTest {
	public static inline final BUILD_ROOT = "build/source-correlation/development";
	public static inline final PACKAGED_ROOT = "build/source-correlation/packaged-evidence";
	public static inline final PRODUCTION_ROOT = "build/source-correlation/production-plugin";

	public static function run():Void {
		final profile = new Wp70PublicAdapterProfile();
		final first = profile.emitPlugin(SourceCorrelationFixture.plan());
		final second = profile.emitPlugin(SourceCorrelationFixture.plan());
		final adapter = first.file("includes/FailureCallbacks.php").rendered;
		assertEquals(adapter.source, second.file("includes/FailureCallbacks.php").source, "correlated PHP determinism");
		assertEquals("13", Std.string(adapter.mappingCount), "correlated mapping count");

		final generatorSourceSha256 = hashFiles([
			"../reflaxe.php/src/reflaxe/php/print/PhpPrinter.hx",
			"../reflaxe.php/src/reflaxe/php/map/PhpRangeMapWriter.hx",
			"src/wordpress/hx/compiler/php/profile/Wp70PublicAdapterProfile.hx"
		]);
		final buildInputsSha256 = Sha256.encode(SourceCorrelationFixture.sourceFile().sha256 + "\nwp70-release\nsource-correlation-v1\n").toLowerCase();
		final writer = new WordPressPhpRangeMapWriter("0.0.0+sdk025", generatorSourceSha256, buildInputsSha256);
		final map = writer.write(adapter);
		assertEquals(map, writer.write(adapter), "correlated map determinism");
		final document:Dynamic = Json.parse(map);
		assertEquals("wordpresshx.php-haxe-range-map.v1", document.format, "SDK PHP map identity");
		assertEquals("4", Std.string((cast document.traceAnchors : Array<Dynamic>).length), "public/private trace anchor count");
		assertEquals("compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx", document.sources[0].path, "logical source path");
		final developmentIndex = new WordPressPhpSourceIndexWriter("0.0.0+sdk025", "source-correlation-fixture", "0.0.0", "wp70-release", buildInputsSha256,
			"development", "local-only", "debug-companion-relative", "debug-companion",
			"source/project").write("failure-callbacks", adapter, map, SourceCorrelationFixture.sourceFile(), ["SDK-025-PHP-SOURCE-CORRELATION"]);
		assertEquals(developmentIndex,
			new WordPressPhpSourceIndexWriter("0.0.0+sdk025", "source-correlation-fixture", "0.0.0", "wp70-release", buildInputsSha256, "development",
				"local-only", "debug-companion-relative", "debug-companion",
				"source/project").write("failure-callbacks", adapter, map, SourceCorrelationFixture.sourceFile(), ["SDK-025-PHP-SOURCE-CORRELATION"]),
			"source index determinism");
		final packagedIndex = new WordPressPhpSourceIndexWriter("0.0.0+sdk025", "source-correlation-fixture", "0.0.0", "wp70-release", buildInputsSha256,
			"production-evidence", "debug-companion", "cli-root-argument",
			"external").write("failure-callbacks", adapter, map, SourceCorrelationFixture.sourceFile(), ["SDK-025-PHP-SOURCE-CORRELATION"]);

		write(BUILD_ROOT + "/includes/FailureCallbacks.php", adapter.source);
		write(BUILD_ROOT + "/includes/FailureCallbacks.php.haxe-map.json", map);
		write(BUILD_ROOT + "/source-index.json", developmentIndex);
		write(BUILD_ROOT + "/source/project/compiler/wordpress/test/fixtures/SourceCorrelationCallbacks.hx", SourceCorrelationFixture.sourceFile().content);
		write(PACKAGED_ROOT + "/includes/FailureCallbacks.php", adapter.source);
		write(PACKAGED_ROOT + "/includes/FailureCallbacks.php.haxe-map.json", map);
		write(PACKAGED_ROOT + "/source-index.json", packagedIndex);
		for (file in first.files) {
			write(PRODUCTION_ROOT + "/" + file.path, file.source);
		}
	}

	static function hashFiles(paths:Array<String>):String {
		final buffer = new StringBuf();
		for (path in paths) {
			buffer.add(path);
			buffer.add("\x00");
			buffer.add(File.getContent(path));
			buffer.add("\x00");
		}
		return Sha256.encode(buffer.toString()).toLowerCase();
	}

	static function write(path:String, content:String):Void {
		ensureDirectory(path.substr(0, path.lastIndexOf("/")));
		File.saveContent(path, content);
	}

	static function ensureDirectory(path:String):Void {
		if (FileSystem.exists(path)) {
			return;
		}
		final parent = path.substr(0, path.lastIndexOf("/"));
		if (parent.length > 0) {
			ensureDirectory(parent);
		}
		FileSystem.createDirectory(path);
	}

	static function assertEquals(expected:String, actual:String, label:String):Void {
		if (expected != actual) {
			throw label + " mismatch\nexpected:\n" + expected + "\nactual:\n" + actual;
		}
	}
}
