package wordpress.hx.i18n;

/** Exhaustive message shapes supported by SDK-055. */
enum MessageDefinition {
	Text(message:TextMessage);
	StringPlaceholder(message:StringMessage);
	PluralCount(message:PluralMessage);
}
