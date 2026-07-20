package wordpress.hx.gutenberg.block;

/**
 * Values WordPress supplies while a block is being edited.
 *
 * Attribute writes go through `EditAttributes.set`, which checks the selected
 * field and replacement value before emitting WordPress' native partial update.
 */
@:ts.type("{ readonly attributes: $0; readonly clientId: string; readonly isSelected: boolean; readonly className?: string; readonly setAttributes: (next: Partial<$0>) => void }")
extern class EditProps<Attributes> {
	public final attributes:Attributes;
	public final clientId:String;
	public final isSelected:Bool;
	public final className:Null<String>;

	private function setAttributes(update:{}):Void;
}
