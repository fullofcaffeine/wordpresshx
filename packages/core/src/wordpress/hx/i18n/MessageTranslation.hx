package wordpress.hx.i18n;

/** Locale values bound to one exact source message shape. */
enum MessageTranslation {
	TextTranslation(message:TextMessage, value:String);
	StringTranslation(message:StringMessage, value:String);
	PluralTranslation(message:PluralMessage, singular:String, plural:String);
}
