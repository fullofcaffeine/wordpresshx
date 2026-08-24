package wordpress.hx.i18n;

/** Whether a message is statically authored or admitted at an explicit external boundary. */
enum MessageOrigin {
	Authored(source:MessageSource);
	External(boundary:String);
}
