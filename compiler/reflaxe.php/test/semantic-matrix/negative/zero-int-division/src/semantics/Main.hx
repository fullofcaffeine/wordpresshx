package semantics;

class Main {
	static function divide(value:Int):Int {
		return Std.int(17 / 0);
	}

	static function main():Void {
		Sys.println("zero-int-division:stock-pass");
	}
}
