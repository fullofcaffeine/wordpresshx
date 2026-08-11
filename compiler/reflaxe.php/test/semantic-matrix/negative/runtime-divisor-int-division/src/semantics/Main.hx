package semantics;

class Main {
	static function divide(value:Int, divisor:Int):Int {
		return Std.int(value / divisor);
	}

	static function main():Void {
		Sys.println("runtime-divisor-int-division:stock-pass");
	}
}
