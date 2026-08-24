package sdk055.fixture;

import haxe.io.Bytes;
import sys.io.File;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressI18nBrowserAsset;
import wordpress.hx.compiler.php.profile.WordPressI18nPlan;
import wordpress.hx.compiler.php.profile.WordPressI18nSourceInput;
import wordpress.hx.i18n.ExternalMessages;
import wordpress.hx.i18n.LocaleCatalog;
import wordpress.hx.i18n.MessageCatalog;
import wordpress.hx.i18n.Translations;

/** Focused runtime contract checks for closed catalog and package membership. */
class ContractMain {
	public static function main():Void {
		final arguments = Sys.args();
		if (arguments.length != 2) {
			throw "usage: ContractMain <messages.js> <messages.asset.php>";
		}
		final browser = new WordPressI18nBrowserAsset("messages.js", File.getBytes(arguments[0]), "messages.asset.php", File.getBytes(arguments[1]));
		final external = ExternalMessages.text("fixture.runtime-input", "books.ready", "External ready.",
			"Runtime input that must not impersonate the authored catalog.", "wordpresshx-sdk055");

		expectFailure("exact catalog membership", "exact source message",
			() -> new LocaleCatalog("es_MX", "nplurals=2; plural=(n != 1);", BooksCatalog.catalog(), [
				Translations.text(external, "Lista externa."),
				Translations.text(BooksCatalog.openAction, "Abrir"),
				Translations.string(BooksCatalog.openTitle, "Abrir %1$s"),
				Translations.plural(BooksCatalog.bookCount, "%1$d libro", "%1$d libros"),
				Translations.plural(BooksCatalog.shelfCount, "%1$d elemento de estante", "%1$d elementos de estante")
			]));

		final externalCatalog = new MessageCatalog("wordpresshx-sdk055", [external]);
		final externalLocale = new LocaleCatalog("es_MX", "nplurals=2; plural=(n != 1);", externalCatalog, [Translations.text(external, "Lista externa.")]);
		expectFailure("external package stop", "rejects external message boundary",
			() -> new WordPressI18nPlan("wordpresshx-sdk055", "wordpresshx-sdk055-messages",
				new PluginHeader("WordPressHx SDK-055 i18n", "Typed cross-layer internationalization tracer.", "0.0.0", "7.0", "7.4", "WordPressHx",
					"LicenseRef-WordPressHx-Review-Pending", "wordpresshx-sdk055"),
				externalLocale, browser, [
					new WordPressI18nSourceInput(I18nFixture.SOURCE_PATH, File.getBytes(I18nFixture.SOURCE_PATH))
				]));

		expectFailure("final dependency", "depend exactly on wp-i18n",
			() -> new WordPressI18nBrowserAsset("messages.js", File.getBytes(arguments[0]), "messages.asset.php",
				Bytes.ofString("<?php return array('dependencies' => array('wp-hooks'), 'version' => '0123456789abcdef0123');\n")));
		Sys.println("SDK-055 closed catalog and package contract checks passed");
	}

	static function expectFailure(label:String, expected:String, run:() -> Void):Void {
		try {
			run();
		} catch (failure:haxe.Exception) {
			if (failure.message.indexOf(expected) != -1) {
				return;
			}
			throw label + " failed for the wrong reason: " + failure.message;
		}
		throw label + " unexpectedly passed";
	}
}
