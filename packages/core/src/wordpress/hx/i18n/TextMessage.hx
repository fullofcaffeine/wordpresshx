package wordpress.hx.i18n;

import wordpress.hx.i18n._internal.MessageRuntime;

/** A message with no substitution arguments and optional gettext context. */
@:allow(wordpress.hx.i18n._internal.MessageBuilder)
class TextMessage implements CatalogMessage {
	public final messageKey:MessageKey;
	public final defaultText:String;
	public final translatorComment:String;
	public final textDomain:TextDomain;
	public final messageContext:Null<String>;
	public final messageOrigin:MessageOrigin;

	private function new(messageKey:MessageKey, defaultText:String, translatorComment:String, textDomain:TextDomain, messageContext:Null<String>,
			messageOrigin:MessageOrigin) {
		this.messageKey = messageKey;
		this.defaultText = MessageRuntime.noPlaceholders(defaultText, "message default text");
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
		return Text(this);
	}
}
