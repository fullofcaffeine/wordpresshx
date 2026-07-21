package wordpress.hx.compiler.php.profile.tests;

import fixtures.AcmeBooksPlugin;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressPluginArtifact;
import wordpress.hx.compiler.php.profile.WordPressPluginFile;
import wordpress.hx.compiler.php.profile.Wp70PhpProfile;

class WordPressPhpProfileTest {
	static final EXPECTED_ROOT = "test/expected/acme-books";
	static final BUILD_ROOT = "build/acme-books";

	static function main():Void {
		final profile = new Wp70PhpProfile();
		final first = profile.emitPlugin(fixturePlan());
		final second = profile.emitPlugin(fixturePlan());
		assertArtifactsEqual(first, second);
		writeArtifact(first);
		assertSnapshots(first);
		assertPublicShapes(first);
		assertNegativePlans(profile);
		WordPressPublicAdapterTest.run();
		WordPressSourceCorrelationTest.run();
		Sys.println("WordPress PHP profile tests passed");
	}

	static function fixturePlan():PluginBootstrapPlan {
		return AcmeBooksPlugin.plan();
	}

	static function fixtureHeader(?textDomain:String, requiresWordPress:String = "7.0", requiresPhp:String = "7.4"):PluginHeader {
		return AcmeBooksPlugin.header(textDomain, requiresWordPress, requiresPhp);
	}

	static function assertArtifactsEqual(first:WordPressPluginArtifact, second:WordPressPluginArtifact):Void {
		assertEquals(first.manifestSource(), second.manifestSource(), "deterministic artifact manifest");
		assertEquals(Std.string(first.files.length), Std.string(second.files.length), "deterministic file count");
		for (index in 0...first.files.length) {
			assertEquals(first.files[index].path, second.files[index].path, "deterministic file path");
			assertEquals(first.files[index].source, second.files[index].source, "deterministic PHP bytes");
		}
	}

	static function writeArtifact(artifact:WordPressPluginArtifact):Void {
		ensureDirectory(BUILD_ROOT);
		for (file in artifact.files) {
			final destination = BUILD_ROOT + "/" + file.path;
			ensureParent(destination);
			File.saveContent(destination, file.source);
		}
		File.saveContent(BUILD_ROOT + "/wordpresshx-public-php-artifact.v1.json", artifact.manifestSource());
	}

	static function assertSnapshots(artifact:WordPressPluginArtifact):Void {
		for (file in artifact.files) {
			final snapshot = EXPECTED_ROOT + "/" + file.path + ".txt";
			assertEquals(File.getContent(snapshot), file.source, "snapshot " + file.path);
		}
		assertEquals(File.getContent(EXPECTED_ROOT + "/wordpresshx-public-php-artifact.v1.json"), artifact.manifestSource(), "manifest snapshot");
	}

	static function assertPublicShapes(artifact:WordPressPluginArtifact):Void {
		final root = artifact.file("acme-books.php").source;
		for (required in [
			"Plugin Name: Acme Books",
			"Requires at least: 7.0",
			"Requires PHP: 7.4",
			"if ( ! defined( 'ABSPATH' ) )",
			"require_once __DIR__ . '/includes/autoload.php';",
			"\\Acme\\Books\\Bootstrap::boot();"
		]) {
			if (root.indexOf(required) == -1) {
				throw "plugin root is missing native shape: " + required;
			}
		}
		for (forbidden in ["RawPhp", "PhpSegment", "HaxeBoot", "haxe.root", "wordpresshx-port"]) {
			for (file in artifact.files) {
				if (file.source.indexOf(forbidden) != -1) {
					throw "plugin artifact leaked forbidden public shape: " + forbidden;
				}
			}
		}
		if (artifact.file("includes/Bootstrap.php").rendered.declarationCount != 1) {
			throw "bootstrap class declaration was not source-correlated";
		}
	}

	static function assertNegativePlans(profile:Wp70PhpProfile):Void {
		final valid = profile.emitPlugin(fixturePlan());
		assertThrows(() -> new PluginHeader("Bad\nName", "Description", "1.0.0", "7.0", "7.4", "Author", "Pending", "bad"), "multiline plugin name");
		assertThrows(() -> new PluginHeader("Bad */ Name", "Description", "1.0.0", "7.0", "7.4", "Author", "Pending", "bad"), "comment terminator");
		assertThrows(() -> new PluginBootstrapPlan("acme-books", fixtureHeader("different-domain"), PhpQualifiedName.relative("Acme\\Books"),
			PhpSourceRange.at("fixtures/Plugin.hx", 1, 1, 1, 2)),
			"text-domain mismatch");
		assertThrows(() -> new PluginBootstrapPlan("acme-books", fixtureHeader(null, "6.9"), PhpQualifiedName.relative("Acme\\Books"),
			PhpSourceRange.at("fixtures/Plugin.hx", 1, 1, 1, 2)),
			"WordPress profile mismatch");
		assertThrows(() -> new PluginBootstrapPlan("acme-books", fixtureHeader(null, "7.0", "8.0"), PhpQualifiedName.relative("Acme\\Books"),
			PhpSourceRange.at("fixtures/Plugin.hx", 1, 1, 1, 2)),
			"PHP profile mismatch");
		assertThrows(() -> new PluginBootstrapPlan("../unsafe", fixtureHeader(), PhpQualifiedName.relative("Acme\\Books"),
			PhpSourceRange.at("fixtures/Plugin.hx", 1, 1, 1, 2)),
			"unsafe plugin slug");
		assertThrows(() -> profile.emitPlugin(null), "missing profile plan");
		assertThrows(() -> profile.emitPlugin(new PluginBootstrapPlan("acme-books",
			new PluginHeader(StringTools.rpad("", "x", 9000), "Description", "1.0.0", "7.0", "7.4", "Author", "Pending", "acme-books"),
			PhpQualifiedName.relative("Acme\\Books"), PhpSourceRange.at("fixtures/Plugin.hx", 1, 1, 1, 2))),
			"oversized plugin header");
		assertThrows(() -> new WordPressPluginArtifact(valid.plan, [
			new WordPressPluginFile("autoload", valid.file(valid.plan.rootPath).rendered),
			new WordPressPluginFile("plugin-root", valid.file(valid.plan.autoloadPath).rendered),
			valid.file(valid.plan.bootstrapPath)
		]), "artifact role/path swap");
		final callerFiles = valid.files;
		callerFiles.pop();
		if (valid.files.length != 3) {
			throw "artifact file inventory was mutable through its getter";
		}
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

	static function assertThrows<T>(run:() -> T, label:String):Void {
		var threw = false;
		try {
			run();
		} catch (_:haxe.Exception) {
			threw = true;
		}
		if (!threw) {
			throw label + " did not fail closed";
		}
	}
}
