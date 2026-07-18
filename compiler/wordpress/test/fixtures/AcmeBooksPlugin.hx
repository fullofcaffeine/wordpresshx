package fixtures;

import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;

/** Haxe-only application input for the SDK-022 generated plugin fixture. **/
class AcmeBooksPlugin {
	public static function plan():PluginBootstrapPlan {
		return new PluginBootstrapPlan("acme-books", header(), PhpQualifiedName.relative("Acme\\Books"),
			PhpSourceRange.at("compiler/wordpress/test/fixtures/AcmeBooksPlugin.hx", 10, 2, 13, 3));
	}

	public static function header(?textDomain:String, requiresWordPress:String = "7.0", requiresPhp:String = "7.4"):PluginHeader {
		return new PluginHeader("Acme Books", "Typed SDK-022 native bootstrap fixture.", "0.0.0", requiresWordPress, requiresPhp, "WordPressHx SDK fixture",
			"LicenseRef-WordPressHx-Review-Pending", textDomain == null ? "acme-books" : textDomain);
	}
}
