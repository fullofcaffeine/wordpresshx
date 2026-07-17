import wordpress.hx.hxx.prototype.ServerHxx;

class Main {
	public static function main():Void {
		final defaults:{count:Int, highlighted:Bool} = {
			count: 1,
			highlighted: true
		};
		ServerHxx.render(<Panel title="known" {...defaults} count={2}>
        <header />
        <body />
      </Panel>);
	}
}
