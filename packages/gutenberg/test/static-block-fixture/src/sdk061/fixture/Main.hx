package sdk061.fixture;

import wordpress.hx.gutenberg.block.StaticBlock;

final class Main {
	public static function main():Void {
		StaticBlock.register(CalloutAttributes, {
			name: "wordpresshx/callout",
			edit: CalloutBlock.edit,
			save: CalloutBlock.save,
			deprecations: [
				StaticBlock.deprecated(LegacyCalloutAttributes, {
					version: "0.9.0",
					save: CalloutBlock.legacySave,
					migrate: CalloutBlock.migrate,
					isEligible: CalloutBlock.legacyIsEligible
				})
			]
		});
	}
}
