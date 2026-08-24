package wordpress.hx.i18n;

import wordpress.hx.i18n._internal.MessageBuilder;

/** Explicit runtime boundary for external message IDs that cannot be extracted. */
class ExternalMessages {
	public static function text(boundary:String, key:String, defaultText:String, comment:String, domain:String, ?context:String):TextMessage {
		return MessageBuilder.createExternalText(key, defaultText, comment, domain, context, boundary);
	}
}
