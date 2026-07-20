package sdk061.fixture;

final class CalloutAttributes {
	@:wpSource(wordpress.hx.gutenberg.block.AttributeSource.Text)
	@:wpSelector(".wphx-callout__label")
	@:wpRole(wordpress.hx.gutenberg.block.AttributeRole.Content)
	@:wpDefault("NOTE")
	public final label:String;

	@:wpSource(wordpress.hx.gutenberg.block.AttributeSource.Text)
	@:wpSelector(".wphx-callout__message")
	@:wpRole(wordpress.hx.gutenberg.block.AttributeRole.Content)
	@:wpDefault("")
	public final message:String;

	private function new(label:String, message:String) {
		this.label = label;
		this.message = message;
	}

	public static function migrated(label:String, message:String):CalloutAttributes {
		return new CalloutAttributes(label, message);
	}
}
