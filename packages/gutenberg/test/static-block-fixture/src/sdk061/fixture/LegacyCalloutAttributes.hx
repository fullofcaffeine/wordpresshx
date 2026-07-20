package sdk061.fixture;

@:ts.type("{ readonly text: string }")
extern class LegacyCalloutAttributes {
	@:wpSource(wordpress.hx.gutenberg.block.AttributeSource.Text)
	@:wpSelector(".wphx-callout__message")
	@:wpRole(wordpress.hx.gutenberg.block.AttributeRole.Content)
	@:wpDefault("")
	public final text:String;
}
