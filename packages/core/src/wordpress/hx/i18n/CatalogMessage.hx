package wordpress.hx.i18n;

/** Closed metadata surface shared by catalog consumers. */
interface CatalogMessage {
	public function key():MessageKey;
	public function domain():TextDomain;
	public function origin():MessageOrigin;
	public function definition():MessageDefinition;
}
