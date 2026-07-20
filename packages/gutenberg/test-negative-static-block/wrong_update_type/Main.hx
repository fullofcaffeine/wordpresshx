import sdk061.fixture.CalloutAttributes;
import sdk061.fixture.CalloutBlock;
import sdk061.fixture.LegacyCalloutAttributes;
import wordpress.hx.gutenberg.block.EditAttributes;
import wordpress.hx.gutenberg.block.EditProps;
import wordpress.hx.gutenberg.block.StaticBlock;
import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	static function edit(props:EditProps<CalloutAttributes>):BrowserNode {
		EditAttributes.set(props, attributes -> attributes.message, 42);
		return <div/>;
	}

	static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/wrong-update-type",
			edit: edit,
			save: CalloutBlock.save,
			deprecations: [
				StaticBlock.deprecated(LegacyCalloutAttributes, {
					version: "0.9.0",
					save: CalloutBlock.legacySave,
					migrate: CalloutBlock.migrate
				})
			]
		});
	}
}
