import sdk061.fixture.CalloutAttributes;
import sdk061.fixture.CalloutBlock;
import sdk061.fixture.LegacyCalloutAttributes;
import wordpress.hx.gutenberg.block.StaticBlock;

class FakeStaticBlock {
	public static function deprecated(attributeShape:Class<LegacyCalloutAttributes>, options:{}):{} {
		return options;
	}
}

class Main {
	static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/spoof-deprecation",
			edit: CalloutBlock.edit,
			save: CalloutBlock.save,
			deprecations: [
				FakeStaticBlock.deprecated(LegacyCalloutAttributes, {
					version: "0.9.0",
					save: CalloutBlock.legacySave,
					migrate: CalloutBlock.migrate
				})
			]
		});
	}
}
