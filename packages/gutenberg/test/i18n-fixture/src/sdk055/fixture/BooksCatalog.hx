package sdk055.fixture;

import wordpress.hx.i18n.MessageCatalog;
import wordpress.hx.i18n.Messages;

/** One catalog shared by browser, PHP, and extraction proofs. */
class BooksCatalog {
	public static final ready = Messages.text({
		key: "books.ready",
		defaultText: "Library ready.",
		comment: "Shown when the books interface has finished loading.",
		domain: "wordpresshx-sdk055"
	});

	public static final openAction = Messages.context({
		key: "books.open-action",
		defaultText: "Open",
		context: "verb",
		comment: "Button label that opens one book.",
		domain: "wordpresshx-sdk055"
	});

	public static final openTitle = Messages.string({
		key: "books.open-title",
		defaultText: "Open %1$s",
		comment: "Button label. The placeholder is a book title.",
		domain: "wordpresshx-sdk055"
	});

	public static final bookCount = Messages.plural({
		key: "books.count",
		singular: "%1$d book",
		plural: "%1$d books",
		comment: "Number of books in the current result.",
		domain: "wordpresshx-sdk055"
	});

	public static final shelfCount = Messages.pluralContext({
		key: "books.shelf-count",
		singular: "%1$d shelf item",
		plural: "%1$d shelf items",
		context: "inventory noun",
		comment: "Number of books stored on one shelf.",
		domain: "wordpresshx-sdk055"
	});

	public static function catalog():MessageCatalog {
		return new MessageCatalog("wordpresshx-sdk055", [ready, openAction, openTitle, bookCount, shelfCount]);
	}
}
