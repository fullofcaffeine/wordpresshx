package semantics;

class Main {
	public static function main():Void {}

	public static function choose(left:Null<String>, right:Null<String>):Null<String> {
		return left == null ? right : left;
	}
}
