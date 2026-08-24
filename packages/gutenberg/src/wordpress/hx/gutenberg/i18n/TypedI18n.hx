package wordpress.hx.gutenberg.i18n;

import wordpress.hx.gutenberg.i18n.I18n.__;
import wordpress.hx.gutenberg.i18n.I18n._n;
import wordpress.hx.gutenberg.i18n.I18n._nx;
import wordpress.hx.gutenberg.i18n.I18n._x;
import wordpress.hx.gutenberg.i18n.I18n.sprintf;
import wordpress.hx.i18n.PluralMessage;
import wordpress.hx.i18n.StringMessage;
import wordpress.hx.i18n.TextMessage;

/** Typed browser projection of closed message shapes onto @wordpress/i18n. */
class TypedI18n {
	public static function text(message:TextMessage):String {
		final context = message.messageContext;
		return context == null ? __(message.defaultText, message.textDomain.toString()) : _x(message.defaultText, context, message.textDomain.toString());
	}

	public static function string(message:StringMessage, value:String):String {
		final context = message.messageContext;
		final translated = context == null ? __(message.defaultText,
			message.textDomain.toString()) : _x(message.defaultText, context, message.textDomain.toString());
		return sprintf(translated, value);
	}

	public static function plural(message:PluralMessage, count:Int):String {
		final context = message.messageContext;
		final translated = context == null ? _n(message.singular, message.plural, count,
			message.textDomain.toString()) : _nx(message.singular, message.plural, count, context, message.textDomain.toString());
		return sprintf(translated, count);
	}
}
