package wordpress.hx.i18n;

import wordpress.hx.i18n._internal.MessageRuntime;

/** Complete locale projection for one exact source catalog. */
class LocaleCatalog {
	public final locale:LocaleId;
	public final pluralForms:String;
	public final catalog:MessageCatalog;

	final translationValues:Array<MessageTranslation>;

	public var translations(get, never):Array<MessageTranslation>;

	public function new(locale:String, pluralForms:String, catalog:MessageCatalog, translations:Array<MessageTranslation>) {
		if (catalog == null || translations == null) {
			throw "locale catalog requires source messages and translations";
		}
		this.locale = LocaleId.parse(locale);
		this.pluralForms = MessageRuntime.text(pluralForms, "plural forms");
		this.catalog = catalog;
		final known:Map<String, CatalogMessage> = [];
		for (message in catalog.messages) {
			known.set(message.key().toString(), message);
		}
		final values = translations.copy();
		values.sort((left, right) -> compareText(key(left), key(right)));
		final translated:Map<String, Bool> = [];
		for (translation in values) {
			final identity = key(translation);
			if (!known.exists(identity) || known.get(identity) != message(translation) || translated.exists(identity)) {
				throw "locale translation is unknown, duplicated, or not bound to its exact source message: " + identity;
			}
			translated.set(identity, true);
		}
		if (Lambda.count(known) != Lambda.count(translated)) {
			throw "locale catalog must translate every source message exactly once";
		}
		this.translationValues = values;
	}

	public static function message(translation:MessageTranslation):CatalogMessage {
		return switch (translation) {
			case TextTranslation(message, _): message;
			case StringTranslation(message, _): message;
			case PluralTranslation(message, _, _): message;
		};
	}

	function get_translations():Array<MessageTranslation> {
		return translationValues.copy();
	}

	static function key(translation:MessageTranslation):String {
		return message(translation).key().toString();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
