package sdk055.fixture;

import haxe.io.Bytes;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressI18nBrowserAsset;
import wordpress.hx.compiler.php.profile.WordPressI18nPlan;
import wordpress.hx.compiler.php.profile.WordPressI18nSourceInput;
import wordpress.hx.i18n.LocaleCatalog;
import wordpress.hx.i18n.Translations;

/** Exact Spanish locale and wp70-release package plan for the SDK-055 tracer. */
class I18nFixture {
	public static inline final SOURCE_PATH = "test/i18n-fixture/src/sdk055/fixture/BooksCatalog.hx";

	public static function locale():LocaleCatalog {
		final catalog = BooksCatalog.catalog();
		return new LocaleCatalog("es_MX", "nplurals=2; plural=(n != 1);", catalog, [
			Translations.text(BooksCatalog.ready, "Biblioteca lista."),
			Translations.text(BooksCatalog.openAction, "Abrir"),
			Translations.string(BooksCatalog.openTitle, "Abrir %1$s"),
			Translations.plural(BooksCatalog.bookCount, "%1$d libro", "%1$d libros"),
			Translations.plural(BooksCatalog.shelfCount, "%1$d elemento de estante", "%1$d elementos de estante")
		]);
	}

	public static function plan(bundle:Bytes, metadata:Bytes, source:Bytes):WordPressI18nPlan {
		return new WordPressI18nPlan("wordpresshx-sdk055", "wordpresshx-sdk055-messages",
			new PluginHeader("WordPressHx SDK-055 i18n", "Typed cross-layer internationalization tracer.", "0.0.0", "7.0", "7.4", "WordPressHx",
				"LicenseRef-WordPressHx-Review-Pending", "wordpresshx-sdk055"),
			locale(), new WordPressI18nBrowserAsset("messages.js", bundle, "messages.asset.php", metadata),
			[new WordPressI18nSourceInput(SOURCE_PATH, source)]);
	}
}
