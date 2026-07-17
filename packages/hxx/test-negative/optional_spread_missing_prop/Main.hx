import wordpress.hx.hxx.prototype.ServerHxx;

typedef OptionalTitle = {
	final ?title:String;
}

class Main {
	public static function main():Void {
		final optional:OptionalTitle = {};
		ServerHxx.render(<Panel {...optional}>
        <header />
        <body />
      </Panel>);
	}
}
