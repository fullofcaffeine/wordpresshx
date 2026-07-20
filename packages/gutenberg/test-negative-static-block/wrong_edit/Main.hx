import sdk061.fixture.CalloutAttributes;
import sdk061.fixture.CalloutBlock;
import sdk061.fixture.LegacyCalloutAttributes;
import wordpress.hx.gutenberg.block.SaveProps;
import wordpress.hx.gutenberg.block.StaticBlock;
import wordpress.hx.gutenberg.browser.BrowserNode;

class Main {
	static function wrongEdit(props:SaveProps<CalloutAttributes>):BrowserNode {
		return <div>{props.attributes.message}</div>;
	}

	static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/wrong-edit",
			edit: wrongEdit,
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
