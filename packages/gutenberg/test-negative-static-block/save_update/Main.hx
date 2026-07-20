import sdk061.fixture.CalloutAttributes;
import sdk061.fixture.CalloutBlock;
import sdk061.fixture.LegacyCalloutAttributes;
import wordpress.hx.gutenberg.block.EditAttributes;
import wordpress.hx.gutenberg.block.SaveProps;
import wordpress.hx.gutenberg.block.StaticBlock;
import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	static function save(props:SaveProps<CalloutAttributes>):BrowserNode {
		EditAttributes.set(props, attributes -> attributes.message, "leaked");
		return <div/>;
	}

	static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/save-update",
			edit: CalloutBlock.edit,
			save: save,
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
