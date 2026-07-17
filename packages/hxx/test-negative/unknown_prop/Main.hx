import wordpress.hx.hxx.prototype.ServerHxx;

class Main {
	public static function main():Void {
		ServerHxx.render(<Panel title="known" mystery={true}>
        <header />
        <body />
      </Panel>);
	}
}
