package wordpress.hx.gutenberg.block;

/**
 * Serializable values WordPress supplies to a static block's pure `save` view.
 *
 * There is deliberately no editor setter, client ID, selection state, or
 * server service on this boundary.
 */
@:ts.type("{ readonly attributes: $0; readonly className?: string }")
extern class SaveProps<Attributes> {
	public final attributes:Attributes;
	public final className:Null<String>;
}
