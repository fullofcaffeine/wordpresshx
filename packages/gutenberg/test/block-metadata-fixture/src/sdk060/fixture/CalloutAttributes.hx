package sdk060.fixture;

import wordpress.hx.gutenberg.block.AttributeRole;
import wordpress.hx.gutenberg.block.AttributeSource;

extern class CalloutAttributes {
	@:wpSource(AttributeSource.RichText)
	@:wpSelector("p")
	@:wpRole(AttributeRole.Content)
	@:wpDefault("")
	public var message:String;

	@:wpDefault(sdk060.fixture.CalloutTone.Info)
	public var tone:sdk060.fixture.CalloutTone;
}
