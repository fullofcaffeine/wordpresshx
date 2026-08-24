import sdk055.fixture.BooksCatalog;
import wordpress.hx.gutenberg.i18n.TypedI18n;

class Main {
	static function main():Void {
		TypedI18n.plural(BooksCatalog.bookCount, "3");
	}
}
