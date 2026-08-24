package wordpress.hx.i18n;

/** Immutable, single-domain catalog with unique typed keys. */
class MessageCatalog {
	public final textDomain:TextDomain;

	final messageValues:Array<CatalogMessage>;

	public var messages(get, never):Array<CatalogMessage>;

	public function new(domain:String, messages:Array<CatalogMessage>) {
		if (messages == null || messages.length == 0) {
			throw "message catalog requires at least one message";
		}
		this.textDomain = TextDomain.parse(domain);
		final values = messages.copy();
		values.sort((left, right) -> compareText(left.key().toString(), right.key().toString()));
		final keys:Map<String, Bool> = [];
		for (message in values) {
			if (message == null || message.domain().toString() != textDomain.toString()) {
				throw "every catalog message must use its catalog text domain";
			}
			final key = message.key().toString();
			if (keys.exists(key)) {
				throw "duplicate message key: " + key;
			}
			keys.set(key, true);
		}
		this.messageValues = values;
	}

	public function message(key:MessageKey):CatalogMessage {
		for (message in messageValues) {
			if (message.key().toString() == key.toString()) {
				return message;
			}
		}
		throw "unknown catalog message: " + key.toString();
	}

	function get_messages():Array<CatalogMessage> {
		return messageValues.copy();
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
