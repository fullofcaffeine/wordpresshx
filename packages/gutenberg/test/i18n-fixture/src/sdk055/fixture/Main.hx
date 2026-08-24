package sdk055.fixture;

import wordpress.hx.gutenberg.i18n.TypedI18n;

typedef BrowserTranslationProbe = {
	final ready:String;
	final openAction:String;
	final openTitle:String;
	final oneBook:String;
	final manyBooks:String;
	final manyShelfItems:String;
}

@:native("window")
extern class BrowserWindow {
	static var wordpressHxSdk055:BrowserTranslationProbe;
}

/** Publishes translated output from the normal @wordpress/i18n browser boundary. */
class Main {
	public static function main():Void {
		BrowserWindow.wordpressHxSdk055 = {
			ready: TypedI18n.text(BooksCatalog.ready),
			openAction: TypedI18n.text(BooksCatalog.openAction),
			openTitle: TypedI18n.string(BooksCatalog.openTitle, "Atlas"),
			oneBook: TypedI18n.plural(BooksCatalog.bookCount, 1),
			manyBooks: TypedI18n.plural(BooksCatalog.bookCount, 3),
			manyShelfItems: TypedI18n.plural(BooksCatalog.shelfCount, 3)
		};
	}
}
