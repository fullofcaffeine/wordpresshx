package wordpress.hx.compiler.php.profile.tests;

import fixtures.AcmeLifecyclePlugin;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import sys.FileSystem;
import sys.io.File;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressLifecycleArtifact;
import wordpress.hx.compiler.php.profile.WordPressPluginLifecyclePlan;
import wordpress.hx.compiler.php.profile.WordPressPluginUpgradeStep;
import wordpress.hx.compiler.php.profile.Wp70LifecycleProfile;

class WordPressLifecycleTest {
	static final BUILD_ROOT = "build/lifecycle";

	public static function run():Void {
		final profile = new Wp70LifecycleProfile();
		final standardV1 = profile.emitPlugin(AcmeLifecyclePlugin.standardV1());
		final standardV3 = profile.emitPlugin(AcmeLifecyclePlugin.standardV3());
		final mustUseV3 = profile.emitPlugin(AcmeLifecyclePlugin.mustUseV3());
		assertDeterministic(standardV3, profile.emitPlugin(AcmeLifecyclePlugin.standardV3()));
		assertStandardContract(standardV1, 1);
		assertStandardContract(standardV3, 3);
		assertMustUseContract(mustUseV3);
		assertNegativePlans(profile);
		writeArtifact("standard-v1", standardV1);
		writeArtifact("standard-v3", standardV3);
		writeArtifact("must-use-v3", mustUseV3);
	}

	static function assertStandardContract(artifact:WordPressLifecycleArtifact, target:Int):Void {
		final root = artifact.file("acme-lifecycle.php").source;
		final lifecycle = artifact.file("includes/Lifecycle.php").source;
		final uninstall = artifact.file("uninstall.php").source;
		for (required in [
			"\\register_activation_hook( __FILE__, array( \\Acme\\Lifecycle\\Lifecycle::class, 'activate' ) );",
			"\\register_deactivation_hook( __FILE__, array( \\Acme\\Lifecycle\\Lifecycle::class, 'deactivate' ) );",
			"\\add_action( 'plugins_loaded', array( \\Acme\\Lifecycle\\Lifecycle::class, 'maybeUpgrade' ), 10, 0 );"
		]) {
			assertContains(root, required, "standard plugin root");
		}
		assertContains(lifecycle, "$schemaVersion = (int) \\get_option( 'acme_lifecycle_schema_version', 0 );", "schema checkpoint read");
		assertContains(lifecycle, "if ( $schemaVersion > " + target + " )", "future-schema downgrade guard");
		assertContains(lifecycle, "\\update_option( 'acme_lifecycle_schema_version', " + target + ", false );", "target checkpoint write");
		assertContains(uninstall, "if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) )", "uninstall guard");
		assertContains(uninstall, "\\Acme\\Lifecycle\\Lifecycle::uninstall();", "uninstall callback");
		final manifest = artifact.manifest();
		assertEquals("standard-plugin", manifest.packageKind, "standard package kind");
		assertEquals(Std.string(target), Std.string(manifest.lifecycle.targetSchemaVersion), "standard target version");
		if (!manifest.lifecycle.activationHook || !manifest.lifecycle.deactivationHook) {
			throw "standard lifecycle manifest omitted native activation/deactivation hooks";
		}
		assertEquals("delete-declared-options", manifest.lifecycle.uninstallPolicy, "standard uninstall policy");
	}

	static function assertMustUseContract(artifact:WordPressLifecycleArtifact):Void {
		final root = artifact.file("acme-lifecycle-mu.php").source;
		assertContains(root, "require_once __DIR__ . '/acme-lifecycle-mu/includes/autoload.php';", "mu-plugin loader");
		assertContains(root, "\\add_action( 'plugins_loaded', array( \\Acme\\LifecycleMu\\Lifecycle::class, 'maybeUpgrade' ), 10, 0 );",
			"mu-plugin upgrade hook");
		for (forbidden in ["register_activation_hook", "register_deactivation_hook"]) {
			if (root.indexOf(forbidden) != -1) {
				throw "mu-plugin root incorrectly emitted " + forbidden;
			}
		}
		if (artifact.files.length != 4) {
			throw "mu-plugin package must omit uninstall.php";
		}
		final manifest = artifact.manifest();
		assertEquals("must-use-plugin", manifest.packageKind, "mu package kind");
		if (manifest.lifecycle.activationHook || manifest.lifecycle.deactivationHook) {
			throw "mu lifecycle manifest claimed unavailable activation/deactivation hooks";
		}
		assertEquals("retain-declared-data", manifest.lifecycle.uninstallPolicy, "mu uninstall policy");
	}

	static function assertNegativePlans(profile:Wp70LifecycleProfile):Void {
		final plugin = fixturePlugin();
		final step = new WordPressPluginUpgradeStep(0, 1, []);
		assertThrows(() -> new WordPressPluginUpgradeStep(0, 2, []), "non-contiguous migration");
		assertThrows(() -> new WordPressPluginLifecyclePlan(plugin, StandardPlugin, "Unsafe-Option", 1, [step], RetainPluginData, []), "unsafe schema option");
		assertThrows(() -> new WordPressPluginLifecyclePlan(plugin, StandardPlugin, "safe_option", 2, [step], RetainPluginData, []), "missing migration step");
		assertThrows(() -> new WordPressPluginLifecyclePlan(plugin, StandardPlugin, "safe_option", 1, [step], RetainPluginData, ["safe_option"]),
			"retained data deletion");
		assertThrows(() -> new WordPressPluginLifecyclePlan(plugin, MustUsePlugin, "safe_option", 1, [step], DeleteDeclaredPluginData, ["safe_option"]),
			"mu-plugin uninstall policy");
		assertThrows(() -> profile.emitPlugin(null), "missing lifecycle plan");
	}

	static function fixturePlugin():PluginBootstrapPlan {
		return new PluginBootstrapPlan("safe-plugin",
			new PluginHeader("Safe Plugin", "Lifecycle negative fixture.", "1.0.0", "7.0", "7.4", "Fixture", "Pending", "safe-plugin"),
			PhpQualifiedName.relative("Safe\\Plugin"), PhpSourceRange.at("fixtures/Lifecycle.hx", 1, 1, 1, 2));
	}

	static function writeArtifact(name:String, artifact:WordPressLifecycleArtifact):Void {
		final root = BUILD_ROOT + "/" + name;
		ensureDirectory(root);
		for (file in artifact.files) {
			final destination = root + "/" + file.path;
			ensureParent(destination);
			File.saveContent(destination, file.source);
		}
		File.saveContent(root + "/wordpresshx-plugin-lifecycle.v1.json", artifact.manifestSource());
	}

	static function assertDeterministic(first:WordPressLifecycleArtifact, second:WordPressLifecycleArtifact):Void {
		assertEquals(first.manifestSource(), second.manifestSource(), "deterministic lifecycle manifest");
		assertEquals(Std.string(first.files.length), Std.string(second.files.length), "deterministic lifecycle file count");
		for (index in 0...first.files.length) {
			assertEquals(first.files[index].path, second.files[index].path, "deterministic lifecycle path");
			assertEquals(first.files[index].source, second.files[index].source, "deterministic lifecycle bytes");
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

	static function assertContains(source:String, expected:String, label:String):Void {
		if (source.indexOf(expected) == -1) {
			throw label + " is missing: " + expected;
		}
	}

	static function assertEquals(expected:String, actual:String, label:String):Void {
		if (expected != actual) {
			throw label + " mismatch: expected " + expected + ", found " + actual;
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
