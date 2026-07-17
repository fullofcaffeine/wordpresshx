import wordpress.hx.hxx.prototype.ServerHxx;

class Main {
	public static function main():Void {
		final flags:Array<Bool> = [true];
		ServerHxx.render(<Inline label="known">{...flags}</Inline>);
	}
}
