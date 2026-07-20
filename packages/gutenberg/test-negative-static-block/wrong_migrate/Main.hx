import sdk061.fixture.CalloutAttributes;
import sdk061.fixture.CalloutBlock;
import sdk061.fixture.LegacyCalloutAttributes;
import wordpress.hx.gutenberg.block.StaticBlock;

class Main {
	static function wrongMigrate(attributes:LegacyCalloutAttributes):LegacyCalloutAttributes {
		return attributes;
	}

	static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/wrong-migrate",
			edit: CalloutBlock.edit,
			save: CalloutBlock.save,
			deprecations: [
				StaticBlock.deprecated(LegacyCalloutAttributes, {
					version: "0.9.0",
					save: CalloutBlock.legacySave,
					migrate: wrongMigrate
				})
			]
		});
	}
}
