package semantics;

class Main {
	static function invalidRemainder(value:Int):Int {
		return 17 % 0;
	}

	static function main():Void {
		Sys.println("zero-int-remainder:stock-pass");
	}
}
