import wordpress.hx.gutenberg.block.StaticBlock;

class MissingDefaultAttributes {
	public final message:String;

	private function new(message:String) {
		this.message = message;
	}
}

class Main {
	static function main():Void {
		StaticBlock.register(MissingDefaultAttributes, {
			name: "wordpresshx/missing-default",
			edit: sdk061.fixture.CalloutBlock.edit,
			save: sdk061.fixture.CalloutBlock.save,
			deprecations: []
		});
	}
}
