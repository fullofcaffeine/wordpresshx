package sdk060.fixture;

extern class CalloutAttributes {
	@:wpSource(wordpress.hx.gutenberg.block.AttributeSource.RichText)
	@:wpSelector("p")
	@:wpRole(wordpress.hx.gutenberg.block.AttributeRole.Content)
	@:wpDefault("")
	public var message:String;

	@:wpDefault(sdk060.fixture.CalloutTone.Info)
	public var tone:sdk060.fixture.CalloutTone;
}
