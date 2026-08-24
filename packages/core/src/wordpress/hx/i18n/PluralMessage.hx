package wordpress.hx.i18n;

import wordpress.hx.i18n._internal.MessageRuntime;

/** Singular/plural message whose exact formatter accepts one Int count. */
@:allow(wordpress.hx.i18n._internal.MessageBuilder)
class PluralMessage implements CatalogMessage {
	public final messageKey:MessageKey;
	public final singular:String;
	public final plural:String;
	public final translatorComment:String;
	public final textDomain:TextDomain;
	public final messageContext:Null<String>;
	public final messageOrigin:MessageOrigin;

	private function new(messageKey:MessageKey, singular:String, plural:String, translatorComment:String, textDomain:TextDomain, messageContext:Null<String>,
			messageOrigin:MessageOrigin) {
		this.messageKey = messageKey;
		this.singular = MessageRuntime.countPlaceholder(singular, "message singular text");
		this.plural = MessageRuntime.countPlaceholder(plural, "message plural text");
		this.translatorComment = MessageRuntime.comment(translatorComment);
		this.textDomain = textDomain;
		this.messageContext = messageContext == null ? null : MessageRuntime.context(messageContext);
		this.messageOrigin = messageOrigin;
	}

	public function key():MessageKey {
		return messageKey;
	}

	public function domain():TextDomain {
		return textDomain;
	}

	public function origin():MessageOrigin {
		return messageOrigin;
	}

	public function definition():MessageDefinition {
		return PluralCount(this);
	}
}
