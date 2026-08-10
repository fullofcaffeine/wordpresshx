package semantics;

class Main {
	static function divide(value:Int):Int {
		return Std.int((-2147483647 - 1) / -1);
	}

	static function main():Void {
		Sys.println("overflow-int-division:stock-pass");
	}
}
