package wordpress.hx.contracts;

enum DecodeResult<T> {
	Decoded(value:T);
	Rejected(issues:Array<DecodeIssue>);
}

class DecodeIssue {
	public final code:String;
	public final path:String;
	public final expected:String;
	public final actual:String;

	public function new(code:String, path:String, expected:String, actual:String) {
		this.code = code;
		this.path = path;
		this.expected = expected;
		this.actual = actual;
	}
}
