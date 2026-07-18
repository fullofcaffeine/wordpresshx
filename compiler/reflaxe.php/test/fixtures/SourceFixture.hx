package fixtures;

class SourceFixture {
	public static function fail(label:String):Void {
		throw new haxe.Exception("mapped café failure: " + label);
	}
}
