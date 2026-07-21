import wordpress.hx.hxx.prototype.ServerHxx;

class Main {
	public static function main():Void {
		spread({highlighted: true});
	}

	private static function spread<Props>(openProps:Props):Void {
		ServerHxx.render(<Panel title="known" {...openProps}>
        <header />
        <body />
      </Panel>);
	}
}
