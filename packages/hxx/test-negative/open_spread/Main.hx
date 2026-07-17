import wordpress.hx.hxx.prototype.ServerHxx;

class Main {
	public static function main():Void {
		final dynamicProps:Dynamic = {highlighted: true};
		ServerHxx.render(<Panel title="known" {...dynamicProps}>
        <header />
        <body />
      </Panel>);
	}
}
